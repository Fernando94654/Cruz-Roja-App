import uuid

import pytest
from sqlalchemy import select

from app.models import DependentContact, DependentProfile, User
from app.routers.dependents import MAX_DEPENDENTS

GRANDMA = {
    "relationship": "Abuela",
    "full_name": "Rosa Martínez",
    "date_of_birth": "1945-07-02",
    "blood_type": "A+",
    "allergies": ["Sulfas"],
    "conditions": ["Diabetes tipo 2", "Hipertensión"],
    "medications": ["Metformina", "Losartán"],
    "contacts": [{"name": "Luis Martínez", "relationship": "Hijo", "phone": "81 2345 6789"}],
}


def make_user(db, email):
    user = User(email=email, password_hash="x", name=email)
    db.add(user)
    db.flush()
    return user.id


@pytest.fixture()
def user_id(db):
    return make_user(db, "owner@example.com")


def url(user_id, dependent_id=None):
    base = f"/users/{user_id}/dependents"
    return f"{base}/{dependent_id}" if dependent_id else base


def test_list_is_empty_at_first(client, user_id):
    r = client.get(url(user_id))
    assert r.status_code == 200
    assert r.json() == []


def test_unknown_user_answers_404(client):
    assert client.get(url(uuid.uuid4())).status_code == 404
    assert client.post(url(uuid.uuid4()), json=GRANDMA).status_code == 404


def test_create_then_list_and_read(client, user_id):
    r = client.post(url(user_id), json=GRANDMA)
    assert r.status_code == 201
    created = r.json()
    assert created["relationship"] == "Abuela"
    assert created["blood_type"] == "A+"
    assert created["contacts"][0]["phone"] == "8123456789"
    assert created["updated_at"].endswith("Z")

    listed = client.get(url(user_id)).json()
    assert [d["full_name"] for d in listed] == ["Rosa Martínez"]

    read = client.get(url(user_id, created["id"])).json()
    assert read["medications"] == ["Metformina", "Losartán"]


def test_update_replaces_the_profile(client, user_id):
    dependent_id = client.post(url(user_id), json=GRANDMA).json()["id"]
    change = {**GRANDMA, "blood_type": "unknown", "allergies": [], "contacts": []}
    data = client.put(url(user_id, dependent_id), json=change).json()
    assert data["blood_type"] == "unknown"
    assert data["allergies"] == []
    assert data["contacts"] == []
    assert data["conditions"] == ["Diabetes tipo 2", "Hipertensión"]


def test_delete_removes_profile_and_contacts(client, db, user_id):
    dependent_id = client.post(url(user_id), json=GRANDMA).json()["id"]
    assert client.delete(url(user_id, dependent_id)).status_code == 204
    assert client.get(url(user_id, dependent_id)).status_code == 404
    assert db.scalars(select(DependentContact)).all() == []


def test_cannot_touch_another_users_dependent(client, db, user_id):
    other = make_user(db, "other@example.com")
    dependent_id = client.post(url(other), json=GRANDMA).json()["id"]
    assert client.get(url(user_id, dependent_id)).status_code == 404
    assert client.put(url(user_id, dependent_id), json=GRANDMA).status_code == 404
    assert client.delete(url(user_id, dependent_id)).status_code == 404
    assert client.get(url(user_id)).json() == []


def test_medical_lists_are_encrypted_at_rest(client, db, user_id):
    client.post(url(user_id), json=GRANDMA)
    stored = db.scalar(select(DependentProfile).where(DependentProfile.owner_id == user_id))
    assert b"Metformina" not in stored.medications


def test_limit_of_dependents(client, user_id):
    for _ in range(MAX_DEPENDENTS):
        assert client.post(url(user_id), json=GRANDMA).status_code == 201
    r = client.post(url(user_id), json=GRANDMA)
    assert r.status_code == 409
    assert "familiares" in r.json()["detail"]


@pytest.mark.parametrize(
    "field, value",
    [
        ("relationship", "  "),
        ("full_name", ""),
        ("blood_type", "Z+"),
        ("contacts", [{"name": "Ana", "relationship": "Hija", "phone": "123"}]),
    ],
)
def test_rejects_invalid_data(client, user_id, field, value):
    assert client.post(url(user_id), json={**GRANDMA, field: value}).status_code == 422
