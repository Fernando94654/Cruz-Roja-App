import uuid
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.auth import create_token
from app.models import Circle, CircleInvitation, CircleMember, User, UserLocation, WellbeingCheck
from app.models.circles import CircleRole, WellbeingStatus


def make_user(db, name, email, phone=None):
    user = User(email=email, password_hash="x", name=name, phone=phone)
    db.add(user)
    db.flush()
    return user


@pytest.fixture()
def people(db):
    """María created a family with Ana (shares location) and Jorge (doesn't)."""
    maria = make_user(db, "María", "maria@example.com", "8110000001")
    ana = make_user(db, "Ana", "ana@example.com", "8110000002")
    jorge = make_user(db, "Jorge", "jorge@example.com", "8110000003")
    circle = Circle(name="Familia", created_by=maria.id)
    db.add(circle)
    db.flush()
    db.add_all([
        CircleMember(circle_id=circle.id, user_id=maria.id, role=CircleRole.admin),
        CircleMember(circle_id=circle.id, user_id=ana.id, relationship="Hija"),
        CircleMember(circle_id=circle.id, user_id=jorge.id, relationship="Pareja", shares_location=False),
        UserLocation(user_id=ana.id, location="SRID=4326;POINT(-100.3 25.66)"),
        UserLocation(user_id=jorge.id, location="SRID=4326;POINT(-100.28 25.645)"),
    ])
    db.flush()
    return maria, ana, jorge


def url(path=""):
    return f"/family{path}"


def auth(user):
    return {"Authorization": f"Bearer {create_token(user.id)}"}


def member(data, name):
    return next(m for m in data["members"] if m["name"] == name)


def test_lists_members_with_location_only_when_shared(client, people):
    maria, ana, jorge = people
    data = client.get(url(), headers=auth(maria)).json()

    assert {m["name"] for m in data["members"]} == {"Ana", "Jorge"}
    assert member(data, "Ana")["relationship"] == "Hija"
    assert member(data, "Ana")["phone"] == "8110000002"
    assert member(data, "Ana")["coordinate"] == {"latitude": 25.66, "longitude": -100.3}
    assert member(data, "Jorge")["coordinate"] is None
    assert member(data, "Ana")["status"] == "unknown"
    assert data["shares_location"] is True
    assert data["wellbeing_request"] is None


def test_user_without_family_gets_empty_screen(client, db):
    alone = make_user(db, "Solo", "solo@example.com")
    data = client.get(url(), headers=auth(alone)).json()
    assert data["members"] == [] and data["sent_invitations"] == [] and data["received_invitations"] == []


def test_requires_sign_in(client):
    r = client.get(url())
    assert r.status_code == 401
    assert r.json()["detail"] == "Inicia sesión para continuar"


@pytest.mark.parametrize("token", ["garbage", jwt.encode({"sub": str(uuid.uuid4())}, "another-secret-that-is-also-long-enough", algorithm="HS256")])
def test_rejects_bad_tokens(client, token):
    assert client.get(url(), headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_rejects_token_of_deleted_user(client):
    assert client.get(url(), headers={"Authorization": f"Bearer {create_token(uuid.uuid4())}"}).status_code == 401


def test_ask_answer_and_status_flow(client, people):
    maria, ana, _ = people

    data = client.post(url(f"/members/{ana.id}/wellbeing-check"), headers=auth(maria)).json()
    assert member(data, "Ana")["status"] == "waiting"

    request = client.get(url(), headers=auth(ana)).json()["wellbeing_request"]
    assert request["from_name"] == "María"
    assert request["sent_at"].endswith("Z")

    data = client.post(url("/wellbeing-answer"), headers=auth(ana), json={"status": "need_help"}).json()
    assert data["wellbeing_request"] is None
    assert member(client.get(url(), headers=auth(maria)).json(), "Ana")["status"] == "need_help"


def test_asking_twice_keeps_one_pending_question(client, db, people):
    maria, ana, jorge = people
    client.post(url(f"/members/{ana.id}/wellbeing-check"), headers=auth(maria))
    client.post(url(f"/members/{ana.id}/wellbeing-check"), headers=auth(jorge))
    assert db.query(WellbeingCheck).filter_by(user_id=ana.id).count() == 1


def test_one_answer_reaches_everyone_who_asked(client, db, people):
    maria, ana, jorge = people
    now = datetime.now(timezone.utc)
    db.add_all([
        WellbeingCheck(user_id=ana.id, requested_by=maria.id, status=WellbeingStatus.no_response, created_at=now),
        WellbeingCheck(user_id=ana.id, requested_by=jorge.id, status=WellbeingStatus.no_response, created_at=now),
    ])
    db.flush()
    client.post(url("/wellbeing-answer"), headers=auth(ana), json={"status": "ok"})
    assert member(client.get(url(), headers=auth(jorge)).json(), "Ana")["status"] == "ok"
    assert member(client.get(url(), headers=auth(maria)).json(), "Ana")["status"] == "ok"


def test_answer_without_question_is_404(client, people):
    assert client.post(url("/wellbeing-answer"), headers=auth(people[1]), json={"status": "ok"}).status_code == 404


def test_cannot_ask_someone_outside_the_family(client, db, people):
    stranger = make_user(db, "Extraño", "x@example.com")
    assert client.post(url(f"/members/{stranger.id}/wellbeing-check"), headers=auth(people[0])).status_code == 404


def test_invite_accept_joins_the_family(client, db, people):
    maria = people[0]
    pedro = make_user(db, "Pedro", "pedro@example.com", "8110000009")

    r = client.post(url("/invitations"), headers=auth(maria),
                    json={"name": "Pedro", "contact": "81 1000 0009", "relationship": "Nieto"})
    assert r.status_code == 201
    invitation = r.json()["sent_invitations"][0]
    assert invitation["contact"] == "8110000009"

    received = client.get(url(), headers=auth(pedro)).json()["received_invitations"]
    assert received[0]["from_name"] == "María"

    data = client.post(url(f"/invitations/{invitation['id']}/accept"), headers=auth(pedro)).json()
    assert {m["name"] for m in data["members"]} == {"María", "Ana", "Jorge"}
    assert data["received_invitations"] == []
    maria_view = client.get(url(), headers=auth(maria)).json()
    assert member(maria_view, "Pedro")["relationship"] == "Nieto"
    assert maria_view["sent_invitations"] == []


def test_invitation_by_email_matches_regardless_of_case(client, db, people):
    pedro = make_user(db, "Pedro", "pedro@example.com")
    client.post(url("/invitations"), headers=auth(people[0]), json={"name": "Pedro", "contact": "  Pedro@Example.com"})
    assert len(client.get(url(), headers=auth(pedro)).json()["received_invitations"]) == 1


def test_decline_and_cancel(client, db, people):
    maria = people[0]
    pedro = make_user(db, "Pedro", "pedro@example.com", "8110000009")
    sent = client.post(url("/invitations"), headers=auth(maria), json={"name": "Pedro", "contact": "8110000009"}).json()
    invitation_id = sent["sent_invitations"][0]["id"]

    data = client.post(url(f"/invitations/{invitation_id}/decline"), headers=auth(pedro)).json()
    assert data["members"] == [] and data["received_invitations"] == []

    sent = client.post(url("/invitations"), headers=auth(maria), json={"name": "Pedro", "contact": "8110000009"}).json()
    data = client.delete(url(f"/invitations/{sent['sent_invitations'][0]['id']}"), headers=auth(maria)).json()
    assert data["sent_invitations"] == []


@pytest.mark.parametrize(
    "contact, detail",
    [
        ("8110000002", "Esa persona ya está en tu familia"),
        ("ana@example.com", "Esa persona ya está en tu familia"),
        ("8110000001", "Ese contacto es el tuyo"),
    ],
)
def test_invite_rejects_existing_contacts(client, people, contact, detail):
    r = client.post(url("/invitations"), headers=auth(people[0]), json={"name": "X", "contact": contact})
    assert r.status_code == 409
    assert r.json()["detail"] == detail


def test_invite_twice_is_409(client, people):
    body = {"name": "Pedro", "contact": "8110000009"}
    client.post(url("/invitations"), headers=auth(people[0]), json=body)
    assert client.post(url("/invitations"), headers=auth(people[0]), json=body).status_code == 409


@pytest.mark.parametrize("body", [
    {"name": " ", "contact": "8110000009"},
    {"name": "Pedro", "contact": "123"},
    {"name": "Pedro", "contact": "pedro@"},
])
def test_invite_rejects_invalid_data(client, people, body):
    assert client.post(url("/invitations"), headers=auth(people[0]), json=body).status_code == 422


def test_expired_invitations_are_hidden(client, db, people):
    maria = people[0]
    pedro = make_user(db, "Pedro", "pedro@example.com", "8110000009")
    past = datetime.now(timezone.utc) - timedelta(days=1)
    circle_id = db.query(CircleMember).filter_by(user_id=maria.id).one().circle_id
    db.add(CircleInvitation(circle_id=circle_id, invited_by=maria.id, name="Pedro",
                            contact="8110000009", token="t", created_at=past, expires_at=past))
    db.flush()
    assert client.get(url(), headers=auth(pedro)).json()["received_invitations"] == []
    assert client.get(url(), headers=auth(maria)).json()["sent_invitations"] == []


def test_inviting_without_family_creates_one(client, db):
    alone = make_user(db, "Solo", "solo@example.com")
    friend = make_user(db, "Amiga", "amiga@example.com")
    sent = client.post(url("/invitations"), headers=auth(alone), json={"name": "Amiga", "contact": "amiga@example.com"}).json()
    client.post(url(f"/invitations/{sent['sent_invitations'][0]['id']}/accept"), headers=auth(friend))
    assert [m["name"] for m in client.get(url(), headers=auth(alone)).json()["members"]] == ["Amiga"]


def test_admin_removes_member_but_member_cannot(client, people):
    maria, ana, jorge = people
    assert client.delete(url(f"/members/{jorge.id}"), headers=auth(ana)).status_code == 403

    data = client.delete(url(f"/members/{jorge.id}"), headers=auth(maria)).json()
    assert [m["name"] for m in data["members"]] == ["Ana"]
    assert client.get(url(), headers=auth(jorge)).json()["members"] == []


def test_stop_sharing_hides_my_location(client, people):
    maria, ana, _ = people
    data = client.put(url("/sharing"), headers=auth(ana), json={"shares_location": False}).json()
    assert data["shares_location"] is False
    assert member(client.get(url(), headers=auth(maria)).json(), "Ana")["coordinate"] is None
