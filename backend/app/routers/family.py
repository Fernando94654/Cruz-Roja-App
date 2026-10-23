import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from geoalchemy2 import Geometry
from sqlalchemy import cast, func, select
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.deps import get_db
from app.models import Circle, CircleInvitation, CircleMember, OfficialAlert, User, UserLocation, WellbeingCheck
from app.models.circles import CircleRole, InvitationStatus, WellbeingStatus
from app.schemas.family import (
    AnswerIn,
    CoordinateOut,
    FamilyOut,
    InvitationIn,
    InvitationOut,
    MemberOut,
    SharingIn,
    WellbeingRequestOut,
)

# The user always comes from the sign-in token, so nobody can act as someone else
router = APIRouter(prefix="/family", tags=["Family"])

INVITATION_DAYS = 7

MEMBER_STATUS = {
    WellbeingStatus.ok: "ok",
    WellbeingStatus.need_help: "need_help",
    WellbeingStatus.no_response: "waiting",
}


def now() -> datetime:
    return datetime.now(timezone.utc)


def digits(phone: str | None) -> str | None:
    return re.sub(r"\D", "", phone) if phone else None


def contacts_of(user: User) -> set[str]:
    return {c for c in (user.email.lower(), digits(user.phone)) if c}


def memberships_of(db: Session, user_id: uuid.UUID) -> list[CircleMember]:
    return list(db.scalars(select(CircleMember).where(CircleMember.user_id == user_id)))


def own_circle(db: Session, me: User) -> Circle:
    """The circle my invitations go to. Created the first time I need one."""
    memberships = memberships_of(db, me.id)
    admin = next((m for m in memberships if m.role == CircleRole.admin), None)
    if chosen := admin or next(iter(memberships), None):
        return db.get(Circle, chosen.circle_id)

    circle = Circle(name="Familia", created_by=me.id)
    db.add(circle)
    db.flush()
    db.add(CircleMember(circle_id=circle.id, user_id=me.id, role=CircleRole.admin))
    db.flush()
    return circle


def received_query(me: User):
    return select(CircleInvitation).where(
        CircleInvitation.status == InvitationStatus.pending,
        CircleInvitation.expires_at > now(),
        CircleInvitation.contact.in_(contacts_of(me)),
    )


def pending_checks_for(db: Session, user_id: uuid.UUID) -> list[WellbeingCheck]:
    query = (
        select(WellbeingCheck)
        .where(WellbeingCheck.user_id == user_id, WellbeingCheck.status == WellbeingStatus.no_response)
        .order_by(WellbeingCheck.created_at.desc())
    )
    return list(db.scalars(query))


def family_people(db: Session, me: User) -> dict[uuid.UUID, tuple[CircleMember, User]]:
    """Everyone who shares a circle with me. Someone in two of my circles shows up once."""
    circle_ids = [m.circle_id for m in memberships_of(db, me.id)]
    rows = db.execute(
        select(CircleMember, User)
        .join(User, User.id == CircleMember.user_id)
        .where(CircleMember.circle_id.in_(circle_ids), CircleMember.user_id != me.id)
        .order_by(CircleMember.joined_at, User.name)
    ).all()
    people: dict[uuid.UUID, tuple[CircleMember, User]] = {}
    for membership, user in rows:
        people.setdefault(user.id, (membership, user))
    return people


def build_family(db: Session, me: User) -> FamilyOut:
    memberships = memberships_of(db, me.id)
    people = family_people(db, me)
    ids = list(people)

    point = cast(UserLocation.location, Geometry)
    locations = {
        user_id: CoordinateOut(latitude=lat, longitude=lng)
        for user_id, lat, lng in db.execute(
            select(UserLocation.user_id, func.ST_Y(point), func.ST_X(point)).where(UserLocation.user_id.in_(ids))
        )
    }

    latest: dict[uuid.UUID, WellbeingCheck] = {}
    for check in db.scalars(
        select(WellbeingCheck).where(WellbeingCheck.user_id.in_(ids)).order_by(WellbeingCheck.created_at.desc())
    ):
        latest.setdefault(check.user_id, check)

    members = []
    for user_id, (membership, user) in people.items():
        check = latest.get(user_id)
        members.append(MemberOut(
            id=user_id,
            name=user.name,
            relationship=membership.relationship,
            phone=user.phone,
            status=MEMBER_STATUS[check.status] if check else "unknown",
            updated_at=(check.answered_at or check.created_at) if check else membership.joined_at,
            shares_location=membership.shares_location,
            coordinate=locations.get(user_id) if membership.shares_location else None,
        ))

    sent = db.scalars(
        select(CircleInvitation)
        .where(
            CircleInvitation.invited_by == me.id,
            CircleInvitation.status == InvitationStatus.pending,
            CircleInvitation.expires_at > now(),
        )
        .order_by(CircleInvitation.created_at.desc())
    )
    received = db.execute(
        received_query(me)
        .where(CircleInvitation.circle_id.not_in([m.circle_id for m in memberships]))
        .add_columns(User.name)
        .outerjoin(User, User.id == CircleInvitation.invited_by)
        .order_by(CircleInvitation.created_at.desc())
    ).all()

    request = None
    if pending := pending_checks_for(db, me.id):
        check = pending[0]
        asker = db.get(User, check.requested_by) if check.requested_by else None
        alert = db.get(OfficialAlert, check.alert_id) if check.alert_id else None
        request = WellbeingRequestOut(
            id=check.id,
            from_name=asker.name if asker else "Enlace Vital",
            reason=alert.title if alert else None,
            sent_at=check.created_at,
        )

    return FamilyOut(
        members=members,
        sent_invitations=[invitation_out(i) for i in sent],
        received_invitations=[invitation_out(i, from_name) for i, from_name in received],
        wellbeing_request=request,
        shares_location=all(m.shares_location for m in memberships),
    )


def invitation_out(invitation: CircleInvitation, from_name: str | None = None) -> InvitationOut:
    return InvitationOut(
        id=invitation.id,
        name=invitation.name,
        contact=invitation.contact,
        relationship=invitation.relationship,
        from_name=from_name,
        sent_at=invitation.created_at,
        expires_at=invitation.expires_at,
    )


def member_rows(db: Session, me: User, member_id: uuid.UUID) -> list[CircleMember]:
    """The member's rows in the circles we share, 404 if we share none."""
    circle_ids = [m.circle_id for m in memberships_of(db, me.id)]
    rows = list(db.scalars(
        select(CircleMember).where(CircleMember.user_id == member_id, CircleMember.circle_id.in_(circle_ids))
    ))
    if member_id == me.id or not rows:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Esa persona no está en tu familia")
    return rows


@router.get("", response_model=FamilyOut)
def read_family(me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> FamilyOut:
    return build_family(db, me)


@router.post("/invitations", response_model=FamilyOut, status_code=status.HTTP_201_CREATED)
def invite(data: InvitationIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> FamilyOut:
    if data.contact in contacts_of(me):
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Ese contacto es el tuyo")
    if any(data.contact in contacts_of(user) for _, user in family_people(db, me).values()):
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Esa persona ya está en tu familia")

    duplicate = db.scalar(select(CircleInvitation.id).where(
        CircleInvitation.invited_by == me.id,
        CircleInvitation.contact == data.contact,
        CircleInvitation.status == InvitationStatus.pending,
        CircleInvitation.expires_at > now(),
    ))
    if duplicate:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Ya invitaste a ese contacto")

    sent_at = now()
    db.add(CircleInvitation(
        circle_id=own_circle(db, me).id,
        invited_by=me.id,
        name=data.name,
        contact=data.contact,
        relationship=data.relationship,
        token=secrets.token_urlsafe(32),
        created_at=sent_at,
        expires_at=sent_at + timedelta(days=INVITATION_DAYS),
    ))
    db.commit()
    return build_family(db, me)


@router.delete("/invitations/{invitation_id}", response_model=FamilyOut)
def cancel_invitation(
    invitation_id: uuid.UUID,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FamilyOut:
    invitation = db.get(CircleInvitation, invitation_id)
    if invitation is None or invitation.invited_by != me.id or invitation.status != InvitationStatus.pending:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Esa invitación ya no existe")
    db.delete(invitation)
    db.commit()
    return build_family(db, me)


@router.post("/invitations/{invitation_id}/{answer}", response_model=FamilyOut)
def answer_invitation(
    invitation_id: uuid.UUID,
    answer: Literal["accept", "decline"],
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FamilyOut:
    invitation = db.scalar(received_query(me).where(CircleInvitation.id == invitation_id))
    if invitation is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Esa invitación ya no está disponible")

    if answer == "decline":
        invitation.status = InvitationStatus.declined
    else:
        invitation.status = InvitationStatus.accepted
        if db.get(CircleMember, (invitation.circle_id, me.id)) is None:
            db.add(CircleMember(
                circle_id=invitation.circle_id,
                user_id=me.id,
                relationship=invitation.relationship,
                shares_location=all(m.shares_location for m in memberships_of(db, me.id)),
            ))
    db.commit()
    return build_family(db, me)


@router.post("/members/{member_id}/wellbeing-check", response_model=FamilyOut)
def ask_if_ok(member_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> FamilyOut:
    member_rows(db, me, member_id)
    # One pending question at a time, so nobody gets flooded
    if not pending_checks_for(db, member_id):
        db.add(WellbeingCheck(user_id=member_id, requested_by=me.id,
                              status=WellbeingStatus.no_response, created_at=now()))
        db.commit()
    return build_family(db, me)


@router.post("/wellbeing-answer", response_model=FamilyOut)
def answer_wellbeing(data: AnswerIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> FamilyOut:
    pending = pending_checks_for(db, me.id)
    if not pending:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Nadie te ha preguntado nada")
    # One answer reaches everyone who asked
    answered_at = now()
    for check in pending:
        check.status = WellbeingStatus(data.status)
        check.answered_at = answered_at
    db.commit()
    return build_family(db, me)


@router.delete("/members/{member_id}", response_model=FamilyOut)
def remove_member(
    member_id: uuid.UUID,
    me: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FamilyOut:
    rows = member_rows(db, me, member_id)
    admin_of = {m.circle_id for m in memberships_of(db, me.id) if m.role == CircleRole.admin}
    removable = [row for row in rows if row.circle_id in admin_of]
    if not removable:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Solo quien creó la familia puede quitar a alguien")
    for row in removable:
        db.delete(row)
    db.commit()
    return build_family(db, me)


@router.put("/sharing", response_model=FamilyOut)
def set_sharing(data: SharingIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> FamilyOut:
    own_circle(db, me)
    for membership in memberships_of(db, me.id):
        membership.shares_location = data.shares_location
    db.commit()
    return build_family(db, me)
