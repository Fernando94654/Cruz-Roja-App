"""Official alerts and neighbor reports.

GET  /alerts/official                    Official alerts in effect (SMN, Protección Civil); read-only
GET  /alerts/reports                     Neighbor reports that haven't expired or been flagged as false
POST /alerts/reports                     Publish a report (201); it expires after REPORT_HOURS
POST   /alerts/reports/{report_id}/confirm Confirm someone else's report
DELETE /alerts/reports/{report_id}/confirm Take the confirmation back
POST   /alerts/reports/{report_id}/flag    Mark a report as false
DELETE /alerts/reports/{report_id}/flag    Take the flag back

Each user has one vote per report: confirming removes their flag and flagging removes their confirmation.
Official alerts are loaded by the system, never by users. Reports never say who published them.
"""

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.deps import get_db
from app.models import CommunityReport, CommunityReportConfirmation, OfficialAlert, User
from app.models.alerts import CommunityReportFlag, CommunityReportType
from app.schemas.alerts import CommunityReportIn, CommunityReportOut, OfficialAlertOut

router = APIRouter(prefix="/alerts", tags=["Alerts"])

REPORT_HOURS = 4
FLAG_LIMIT = 3


def now() -> datetime:
    return datetime.now(timezone.utc)


def count_of(db: Session, model, report_id: uuid.UUID) -> int:
    return db.scalar(select(func.count()).where(model.report_id == report_id))


def done_by(db: Session, model, report_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    return db.get(model, (report_id, user_id)) is not None


def remove_vote(db: Session, model, report_id: uuid.UUID, user_id: uuid.UUID) -> None:
    db.execute(delete(model).where(model.report_id == report_id, model.user_id == user_id))


def to_out(db: Session, report: CommunityReport, me: User) -> CommunityReportOut:
    return CommunityReportOut(
        id=report.id,
        type=report.type.value,
        title=report.details or "",
        confirmations=count_of(db, CommunityReportConfirmation, report.id),
        confirmed_by_me=done_by(db, CommunityReportConfirmation, report.id, me.id),
        flags=count_of(db, CommunityReportFlag, report.id),
        flagged_by_me=done_by(db, CommunityReportFlag, report.id, me.id),
        is_mine=report.user_id == me.id,
        expires_at=report.expires_at,
    )


def get_active_report(db: Session, report_id: uuid.UUID) -> CommunityReport:
    report = db.get(CommunityReport, report_id)
    if report is None or report.expires_at <= now() or count_of(db, CommunityReportFlag, report.id) >= FLAG_LIMIT:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="El reporte ya no está vigente")
    return report


@router.get("/official", response_model=list[OfficialAlertOut])
def list_official_alerts(db: Session = Depends(get_db)) -> list[OfficialAlertOut]:
    query = (
        select(OfficialAlert)
        .where(OfficialAlert.starts_at <= now(), or_(OfficialAlert.expires_at.is_(None), OfficialAlert.expires_at > now()))
        .order_by(OfficialAlert.starts_at.desc())
    )
    return [
        OfficialAlertOut(
            id=a.id,
            source=a.source,
            title=a.title,
            description=a.description,
            area_name=a.area_name,
            severity=a.severity.value,
            starts_at=a.starts_at,
        )
        for a in db.scalars(query)
    ]


@router.get("/reports", response_model=list[CommunityReportOut])
def list_reports(me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[CommunityReportOut]:
    query = (
        select(CommunityReport)
        .where(CommunityReport.expires_at > now())
        .order_by(CommunityReport.created_at.desc())
    )
    reports = [to_out(db, r, me) for r in db.scalars(query)]
    return [r for r in reports if r.flags < FLAG_LIMIT]


@router.post("/reports", response_model=CommunityReportOut, status_code=status.HTTP_201_CREATED)
def create_report(
    data: CommunityReportIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommunityReportOut:
    report = CommunityReport(
        user_id=me.id,
        type=CommunityReportType(data.type),
        details=data.title,
        location=f"SRID=4326;POINT({data.longitude} {data.latitude})",
        expires_at=now() + timedelta(hours=REPORT_HOURS),
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return to_out(db, report, me)


@router.post("/reports/{report_id}/confirm", response_model=CommunityReportOut)
def confirm_report(
    report_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommunityReportOut:
    report = get_active_report(db, report_id)
    if report.user_id == me.id:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="No puedes confirmar tu propio reporte")
    remove_vote(db, CommunityReportFlag, report.id, me.id)
    # Confirming twice is ignored, so a retry after a network error is safe
    if not done_by(db, CommunityReportConfirmation, report.id, me.id):
        db.add(CommunityReportConfirmation(report_id=report.id, user_id=me.id))
    db.commit()
    return to_out(db, report, me)


@router.delete("/reports/{report_id}/confirm", response_model=CommunityReportOut)
def unconfirm_report(
    report_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommunityReportOut:
    report = get_active_report(db, report_id)
    remove_vote(db, CommunityReportConfirmation, report.id, me.id)
    db.commit()
    return to_out(db, report, me)


@router.post("/reports/{report_id}/flag", response_model=CommunityReportOut)
def flag_report(
    report_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommunityReportOut:
    report = get_active_report(db, report_id)
    remove_vote(db, CommunityReportConfirmation, report.id, me.id)
    if not done_by(db, CommunityReportFlag, report.id, me.id):
        db.add(CommunityReportFlag(report_id=report.id, user_id=me.id))
    db.commit()
    return to_out(db, report, me)


@router.delete("/reports/{report_id}/flag", response_model=CommunityReportOut)
def unflag_report(
    report_id: uuid.UUID, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> CommunityReportOut:
    report = get_active_report(db, report_id)
    remove_vote(db, CommunityReportFlag, report.id, me.id)
    db.commit()
    return to_out(db, report, me)
