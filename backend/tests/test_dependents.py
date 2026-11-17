import uuid

import pytest
from sqlalchemy import select

from app.auth import create_token
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


def auth(user_id):
    return {"Authorization": f"Bearer {create_token(user_id)}"}


def url(dependent_id=None):
    return f"/me/dependents/{dependent_id}" if dependent_id else "/me/dependents"


@pytest.fixture()
def api(client, user_id):
    """Client that always sends the sign-in token of user_id."""

    class SignedIn:
        def get(self, dependent_id=None):
            return client.get(url(dependent_id), headers=auth(user_id))

        def post(self, json):
            return client.post(url(), json=json, headers=auth(user_id))

        def put(self, dependent_id, json):
            return client.put(url(dependent_id), json=json, headers=auth(user_id))

        def delete(self, dependent_id):
            return client.delete(url(dependent_id), headers=auth(user_id))

    return SignedIn()


def test_list_is_empty_at_first(api):
    r = api.get()
    assert r.status_code == 200
    assert r.json() == []


def test_requires_sign_in(client):
    assert client.get(url()).status_code == 401
    assert client.post(url(), json=GRANDMA).status_code == 401
    assert client.get(url(), headers=auth(uuid.uuid4())).status_code == 401


def test_create_then_list_and_read(api):
    r = api.post(GRANDMA)
    assert r.status_code == 201
    created = r.json()
    assert created["relationship"] == "Abuela"
    assert created["blood_type"] == "A+"
    assert created["contacts"][0]["phone"] == "8123456789"
    assert created["updated_at"].endswith("Z")

    listed = api.get().json()
    assert [d["full_name"] for d in listed] == ["Rosa Martínez"]

    read = api.get(created["id"]).json()
    assert read["medications"] == ["Metformina", "Losartán"]


def test_update_replaces_the_profile(api):
    dependent_id = api.post(GRANDMA).json()["id"]
    change = {**GRANDMA, "blood_type": "unknown", "allergies": [], "contacts": []}
    data = api.put(dependent_id, change).json()
    assert data["blood_type"] == "unknown"
    assert data["allergies"] == []
    assert data["contacts"] == []
    assert data["conditions"] == ["Diabetes tipo 2", "Hipertensión"]


def test_delete_removes_profile_and_contacts(api, db):
    dependent_id = api.post(GRANDMA).json()["id"]
    assert api.delete(dependent_id).status_code == 204
    assert api.get(dependent_id).status_code == 404
    assert db.scalars(select(DependentContact)).all() == []


def test_cannot_touch_another_users_dependent(client, db, api):
    other = make_user(db, "other@example.com")
    dependent_id = client.post(url(), json=GRANDMA, headers=auth(other)).json()["id"]
    assert api.get(dependent_id).status_code == 404
    assert api.put(dependent_id, GRANDMA).status_code == 404
    assert api.delete(dependent_id).status_code == 404
    assert api.get().json() == []


def test_medical_lists_are_encrypted_at_rest(api, db, user_id):
    api.post(GRANDMA)
    stored = db.scalar(select(DependentProfile).where(DependentProfile.owner_id == user_id))
    assert b"Metformina" not in stored.medications


def test_limit_of_dependents(api):
    for _ in range(MAX_DEPENDENTS):
        assert api.post(GRANDMA).status_code == 201
    r = api.post(GRANDMA)
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
def test_rejects_invalid_data(api, field, value):
    assert api.post({**GRANDMA, field: value}).status_code == 422
