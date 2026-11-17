import uuid

import pytest
from sqlalchemy import select

from app.auth import create_token
from app.models import MedicalProfile, User

URL = "/me/medical-profile"

PROFILE = {
    "full_name": "María López",
    "date_of_birth": "1958-03-14",
    "blood_type": "O+",
    "allergies": ["Penicilina"],
    "conditions": ["Asma"],
    "medications": ["Salbutamol"],
    "contacts": [{"name": "Ana López", "relationship": "Hija", "phone": "81 1234 5678"}],
}


def make_user(db, email):
    user = User(email=email, password_hash="x", name=email)
    db.add(user)
    db.flush()
    return user.id


def auth(user_id):
    return {"Authorization": f"Bearer {create_token(user_id)}"}


@pytest.fixture()
def user_id(db):
    return make_user(db, "demo@example.com")


@pytest.fixture()
def api(client, user_id):
    """Client that always sends the sign-in token of user_id."""

    class SignedIn:
        def get(self):
            return client.get(URL, headers=auth(user_id))

        def put(self, json):
            return client.put(URL, json=json, headers=auth(user_id))

    return SignedIn()


def test_get_returns_404_without_profile(api):
    r = api.get()
    assert r.status_code == 404
    assert r.json()["detail"] == "El usuario aún no tiene perfil médico"


def test_requires_sign_in(client, user_id):
    assert client.get(URL).status_code == 401
    assert client.put(URL, json=PROFILE).status_code == 401
    assert client.get(URL, headers={"Authorization": "Bearer not-a-token"}).status_code == 401
    assert client.get(URL, headers=auth(uuid.uuid4())).status_code == 401


def test_each_user_only_sees_their_own_profile(client, db, user_id):
    other = make_user(db, "other@example.com")
    client.put(URL, json=PROFILE, headers=auth(other))
    assert client.get(URL, headers=auth(user_id)).status_code == 404
    assert client.get(URL, headers=auth(other)).json()["user_id"] == str(other)


def test_put_creates_and_get_returns_profile(api, user_id):
    assert api.put(PROFILE).status_code == 200

    data = api.get().json()
    assert data["user_id"] == str(user_id)
    assert data["blood_type"] == "O+"
    assert data["allergies"] == ["Penicilina"]
    assert data["medications"] == ["Salbutamol"]
    assert data["contacts"][0]["phone"] == "8112345678"
    assert data["updated_at"].endswith("Z")


def test_medical_lists_are_encrypted_at_rest(api, db, user_id):
    api.put(PROFILE)
    stored = db.scalar(select(MedicalProfile).where(MedicalProfile.user_id == user_id))
    assert b"Penicilina" not in stored.allergies


def test_put_replaces_lists_and_keeps_contact_order(api):
    api.put(PROFILE)
    contacts = [
        {"name": "Uno", "relationship": "Hijo", "phone": "8111111111"},
        {"name": "Dos", "relationship": "Hija", "phone": "8122222222"},
    ]
    data = api.put({**PROFILE, "allergies": ["Látex", "Nueces"], "contacts": contacts}).json()
    assert data["allergies"] == ["Látex", "Nueces"]
    assert [c["name"] for c in data["contacts"]] == ["Uno", "Dos"]
    assert data["conditions"] == ["Asma"]


def test_unknown_blood_type_round_trips(api):
    data = api.put({**PROFILE, "blood_type": "unknown"}).json()
    assert data["blood_type"] == "unknown"


def test_put_cleans_blanks_and_duplicates(api):
    data = api.put({**PROFILE, "allergies": [" Penicilina ", "", "penicilina", "Látex"]}).json()
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
def test_put_rejects_invalid_data(api, field, value):
    assert api.put({**PROFILE, field: value}).status_code == 422


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}
