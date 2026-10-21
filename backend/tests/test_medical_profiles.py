import uuid

import pytest
from sqlalchemy import select

from app.models import MedicalProfile, User

PROFILE = {
    "full_name": "María López",
    "date_of_birth": "1958-03-14",
    "blood_type": "O+",
    "allergies": ["Penicilina"],
    "conditions": ["Asma"],
    "medications": ["Salbutamol"],
    "contacts": [{"name": "Ana López", "relationship": "Hija", "phone": "81 1234 5678"}],
}


@pytest.fixture()
def user_id(db):
    user = User(email="demo@example.com", password_hash="x", name="Demo")
    db.add(user)
    db.flush()
    return user.id


def url(user_id):
    return f"/users/{user_id}/medical-profile"


def test_get_returns_404_without_profile(client, user_id):
    r = client.get(url(user_id))
    assert r.status_code == 404
    assert r.json()["detail"] == "El usuario aún no tiene perfil médico"


def test_get_returns_404_for_unknown_user(client):
    r = client.get(url(uuid.uuid4()))
    assert r.status_code == 404
    assert r.json()["detail"] == "Usuario no encontrado"


def test_put_creates_and_get_returns_profile(client, user_id):
    assert client.put(url(user_id), json=PROFILE).status_code == 200

    data = client.get(url(user_id)).json()
    assert data["user_id"] == str(user_id)
    assert data["blood_type"] == "O+"
    assert data["allergies"] == ["Penicilina"]
    assert data["medications"] == ["Salbutamol"]
    assert data["contacts"][0]["phone"] == "8112345678"
    assert data["updated_at"].endswith("Z")


def test_medical_lists_are_encrypted_at_rest(client, db, user_id):
    client.put(url(user_id), json=PROFILE)
    stored = db.scalar(select(MedicalProfile).where(MedicalProfile.user_id == user_id))
    assert b"Penicilina" not in stored.allergies


def test_put_replaces_lists_and_keeps_contact_order(client, user_id):
    client.put(url(user_id), json=PROFILE)
    contacts = [
        {"name": "Uno", "relationship": "Hijo", "phone": "8111111111"},
        {"name": "Dos", "relationship": "Hija", "phone": "8122222222"},
    ]
    data = client.put(url(user_id), json={**PROFILE, "allergies": ["Látex", "Nueces"], "contacts": contacts}).json()
    assert data["allergies"] == ["Látex", "Nueces"]
    assert [c["name"] for c in data["contacts"]] == ["Uno", "Dos"]
    assert data["conditions"] == ["Asma"]


def test_unknown_blood_type_round_trips(client, user_id):
    data = client.put(url(user_id), json={**PROFILE, "blood_type": "unknown"}).json()
    assert data["blood_type"] == "unknown"


def test_put_cleans_blanks_and_duplicates(client, user_id):
    data = client.put(url(user_id), json={**PROFILE, "allergies": [" Penicilina ", "", "penicilina", "Látex"]}).json()
    assert data["allergies"] == ["Penicilina", "Látex"]


@pytest.mark.parametrize(
    "field, value",
    [
        ("full_name", "   "),
        ("blood_type", "Z+"),
        ("date_of_birth", "2999-01-01"),
        ("contacts", [{"name": "Ana", "relationship": "Hija", "phone": "123"}]),
        ("contacts", [{"name": "Ana", "relationship": "Hija", "phone": "8112345678"}] * 6),
    ],
)
def test_put_rejects_invalid_data(client, user_id, field, value):
    assert client.put(url(user_id), json={**PROFILE, field: value}).status_code == 422


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}
