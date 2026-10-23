"""Medical profiles of people the user looks after (parents, children) who don't use the app.

GET    /users/{user_id}/dependents                  List the user's dependents
POST   /users/{user_id}/dependents                  Add one (201)
GET    /users/{user_id}/dependents/{dependent_id}   One dependent
PUT    /users/{user_id}/dependents/{dependent_id}   Replace it
DELETE /users/{user_id}/dependents/{dependent_id}   Remove it (204)

A dependent that belongs to another user answers 404, as if it didn't exist.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.crypto import decrypt_list, encrypt_list
from app.deps import get_db
from app.models import DependentContact, DependentProfile
from app.models.medical import BloodType
from app.routers.medical_profiles import get_user
from app.schemas.medical_profile import DependentProfileIn, DependentProfileOut, EmergencyContactSchema

router = APIRouter(prefix="/users", tags=["Dependent profiles"])

MAX_DEPENDENTS = 10


def contacts_of(db: Session, dependent_id: uuid.UUID) -> list[DependentContact]:
    query = (
        select(DependentContact)
        .where(DependentContact.dependent_id == dependent_id)
        .order_by(DependentContact.position)
    )
    return list(db.scalars(query))


def to_out(db: Session, dependent: DependentProfile) -> DependentProfileOut:
    return DependentProfileOut(
        id=dependent.id,
        relationship=dependent.relationship,
        full_name=dependent.full_name,
        date_of_birth=dependent.date_of_birth,
        blood_type=dependent.blood_type.value if dependent.blood_type else "unknown",
        allergies=decrypt_list(dependent.allergies),
        conditions=decrypt_list(dependent.conditions),
        medications=decrypt_list(dependent.medications),
        contacts=[EmergencyContactSchema.model_validate(c) for c in contacts_of(db, dependent.id)],
        updated_at=dependent.updated_at,
    )


def get_dependent(db: Session, user_id: uuid.UUID, dependent_id: uuid.UUID) -> DependentProfile:
    dependent = db.get(DependentProfile, dependent_id)
    if dependent is None or dependent.owner_id != user_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Familiar no encontrado")
    return dependent


def apply(db: Session, dependent: DependentProfile, data: DependentProfileIn) -> None:
    dependent.relationship = data.relationship
    dependent.full_name = data.full_name
    dependent.date_of_birth = data.date_of_birth
    dependent.blood_type = None if data.blood_type == "unknown" else BloodType(data.blood_type)
    dependent.allergies = encrypt_list(data.allergies)
    dependent.conditions = encrypt_list(data.conditions)
    dependent.medications = encrypt_list(data.medications)
    dependent.updated_at = func.now()

    # Contacts are replaced as a whole, same as the user's own profile
    for contact in contacts_of(db, dependent.id):
        db.delete(contact)
    db.add_all(
        DependentContact(dependent_id=dependent.id, position=i, **c.model_dump())
        for i, c in enumerate(data.contacts)
    )


@router.get("/{user_id}/dependents", response_model=list[DependentProfileOut])
def list_dependents(user_id: uuid.UUID, db: Session = Depends(get_db)) -> list[DependentProfileOut]:
    get_user(db, user_id)
    query = (
        select(DependentProfile)
        .where(DependentProfile.owner_id == user_id)
        .order_by(DependentProfile.created_at, DependentProfile.id)
    )
    return [to_out(db, d) for d in db.scalars(query)]


@router.post("/{user_id}/dependents", response_model=DependentProfileOut, status_code=status.HTTP_201_CREATED)
def create_dependent(user_id: uuid.UUID, data: DependentProfileIn, db: Session = Depends(get_db)) -> DependentProfileOut:
    get_user(db, user_id)
    count = db.scalar(select(func.count()).where(DependentProfile.owner_id == user_id))
    if count >= MAX_DEPENDENTS:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=f"Puedes registrar hasta {MAX_DEPENDENTS} familiares")

    dependent = DependentProfile(owner_id=user_id, relationship=data.relationship, full_name=data.full_name)
    db.add(dependent)
    db.flush()  # assigns the id so contacts can point to it
    apply(db, dependent, data)
    db.commit()
    db.refresh(dependent)
    return to_out(db, dependent)


@router.get("/{user_id}/dependents/{dependent_id}", response_model=DependentProfileOut)
def read_dependent(user_id: uuid.UUID, dependent_id: uuid.UUID, db: Session = Depends(get_db)) -> DependentProfileOut:
    get_user(db, user_id)
    return to_out(db, get_dependent(db, user_id, dependent_id))


@router.put("/{user_id}/dependents/{dependent_id}", response_model=DependentProfileOut)
def update_dependent(
    user_id: uuid.UUID, dependent_id: uuid.UUID, data: DependentProfileIn, db: Session = Depends(get_db)
) -> DependentProfileOut:
    get_user(db, user_id)
    dependent = get_dependent(db, user_id, dependent_id)
    apply(db, dependent, data)
    db.commit()
    db.refresh(dependent)
    return to_out(db, dependent)


@router.delete("/{user_id}/dependents/{dependent_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_dependent(user_id: uuid.UUID, dependent_id: uuid.UUID, db: Session = Depends(get_db)) -> Response:
    get_user(db, user_id)
    db.delete(get_dependent(db, user_id, dependent_id))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
