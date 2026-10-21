import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.crypto import decrypt_list, encrypt_list
from app.deps import get_db
from app.models import EmergencyContact, MedicalProfile, User
from app.models.medical import BloodType
from app.schemas.medical_profile import EmergencyContactSchema, MedicalProfileIn, MedicalProfileOut

router = APIRouter(prefix="/users", tags=["Medical profile"])


def get_user(db: Session, user_id: uuid.UUID) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    return user


def contacts_of(db: Session, user_id: uuid.UUID) -> list[EmergencyContact]:
    query = select(EmergencyContact).where(EmergencyContact.user_id == user_id).order_by(EmergencyContact.position)
    return list(db.scalars(query))


def to_out(profile: MedicalProfile, contacts: list[EmergencyContact]) -> MedicalProfileOut:
    return MedicalProfileOut(
        user_id=profile.user_id,
        full_name=profile.full_name,
        date_of_birth=profile.date_of_birth,
        blood_type=profile.blood_type.value if profile.blood_type else "unknown",
        allergies=decrypt_list(profile.allergies),
        conditions=decrypt_list(profile.conditions),
        medications=decrypt_list(profile.medications),
        contacts=[EmergencyContactSchema.model_validate(c) for c in contacts],
        updated_at=profile.updated_at,
    )


@router.get("/{user_id}/medical-profile", response_model=MedicalProfileOut)
def read_profile(user_id: uuid.UUID, db: Session = Depends(get_db)) -> MedicalProfileOut:
    get_user(db, user_id)
    profile = db.get(MedicalProfile, user_id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="El usuario aún no tiene perfil médico")
    return to_out(profile, contacts_of(db, user_id))


@router.put("/{user_id}/medical-profile", response_model=MedicalProfileOut)
def save_profile(user_id: uuid.UUID, data: MedicalProfileIn, db: Session = Depends(get_db)) -> MedicalProfileOut:
    get_user(db, user_id)
    profile = db.get(MedicalProfile, user_id)
    if profile is None:
        profile = MedicalProfile(user_id=user_id)
        db.add(profile)

    profile.full_name = data.full_name
    profile.date_of_birth = data.date_of_birth
    profile.blood_type = None if data.blood_type == "unknown" else BloodType(data.blood_type)
    profile.allergies = encrypt_list(data.allergies)
    profile.conditions = encrypt_list(data.conditions)
    profile.medications = encrypt_list(data.medications)
    profile.updated_at = func.now()

    # Contacts are replaced as a whole, simpler than diffing
    for contact in contacts_of(db, user_id):
        db.delete(contact)
    db.add_all(
        EmergencyContact(user_id=user_id, position=i, **c.model_dump())
        for i, c in enumerate(data.contacts)
    )

    db.commit()
    db.refresh(profile)
    return to_out(profile, contacts_of(db, user_id))
