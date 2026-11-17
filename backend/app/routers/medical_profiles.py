import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.crypto import decrypt_list, encrypt_list
from app.deps import get_db
from app.models import EmergencyContact, MedicalProfile, User
from app.models.medical import BloodType
from app.schemas.medical_profile import EmergencyContactSchema, MedicalProfileIn, MedicalProfileOut

# Solo el usuario que inició sesión ve y cambia su propio perfil
router = APIRouter(prefix="/me", tags=["Medical profile"])


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


# GET: regresa el perfil médico del usuario que inició sesión
@router.get("/medical-profile", response_model=MedicalProfileOut)
def read_profile(me: User = Depends(get_current_user), db: Session = Depends(get_db)) -> MedicalProfileOut:
    user_id = me.id
    profile = db.get(MedicalProfile, user_id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="El usuario aún no tiene perfil médico")
    return to_out(profile, contacts_of(db, user_id))


# PUT: guarda el perfil médico del usuario que inició sesión
@router.put("/medical-profile", response_model=MedicalProfileOut)
def save_profile(
    data: MedicalProfileIn, me: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> MedicalProfileOut:
    user_id = me.id
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

    for contact in contacts_of(db, user_id):
        db.delete(contact)
    db.add_all(
        EmergencyContact(user_id=user_id, position=i, **c.model_dump())
        for i, c in enumerate(data.contacts)
    )

    db.commit()
    db.refresh(profile)
    return to_out(profile, contacts_of(db, user_id))
