import uuid
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.auth import create_token
from app.deps import get_db
from app.main import app
from app.models.learning import Lesson
from app.models.users import User


def test_empty_lessons(client):
    assert client.get("/lessons").json() == []


def test_ordering_nullable_fields_and_unknown_mapping(client, db):
    low, high = uuid.UUID(int=1), uuid.UUID(int=2)
    db.add_all([
        Lesson(id=high, title="RCP", position=1),  # title never determines association
        Lesson(id=low, title="Otro", position=1),
        Lesson(id=uuid.UUID(int=3), title="Primero", position=0),
    ])
    db.flush()
    response = client.get("/lessons")
    assert response.status_code == 200
    rows = response.json()
    assert [r["id"] for r in rows] == [str(uuid.UUID(int=3)), str(low), str(high)]
    assert all(r["guide_id"] is None for r in rows)
    assert all(r["description"] is None and r["duration_seconds"] is None and r["video_url"] is None for r in rows)
    assert all(r["publisher"] is None and r["steps"] == [] for r in rows)


def test_lesson_content_and_guide_come_from_database(client, db):
    lesson = Lesson(title="Nuevo video", guide_id="choking", publisher="Otro editor", steps=["Segundo texto", "Primer texto"], position=1)
    db.add(lesson)
    db.flush()
    row = client.get("/lessons").json()[0]
    assert row["publisher"] == "Otro editor"
    assert row["steps"] == ["Segundo texto", "Primer texto"]
    assert row["guide_id"] == "choking"
    lesson.guide_id = "burn"
    lesson.publisher = "Editor actualizado"
    lesson.steps = ["Contenido actualizado"]
    db.flush()
    row = client.get("/lessons").json()[0]
    assert row["guide_id"] == "burn"
    assert row["publisher"] == "Editor actualizado" and row["steps"] == ["Contenido actualizado"]


def test_all_four_associations_come_from_database(client, db):
    guides = ("cardiac_arrest", "choking", "bleeding", "burn")
    ids = [uuid.uuid4() for _ in guides]
    db.add_all(
        Lesson(id=lesson_id, title="Título modificado", guide_id=guide_id,
               video_url=f"https://www.youtube.com/watch?v={index}", position=index)
        for index, (lesson_id, guide_id) in enumerate(zip(ids, guides), start=1)
    )
    db.flush()
    rows = client.get("/lessons").json()
    assert [(r["id"], r["guide_id"]) for r in rows] == list(zip(map(str, ids), guides))
    assert [r["video_url"] for r in rows] == [f"https://www.youtube.com/watch?v={i}" for i in range(1, 5)]


def test_database_unavailable_returns_generic_503():
    database = Mock()
    database.scalars.side_effect = OperationalError("private connection details", {}, Exception("secret"))
    app.dependency_overrides[get_db] = lambda: database
    try:
        with TestClient(app) as client:
            response = client.get("/lessons")
        assert response.status_code == 503
        assert response.json() == {"detail": "Las lecciones no están disponibles. Intenta de nuevo."}
    finally:
        app.dependency_overrides.clear()


def make_user(db, email):
    user = User(email=email, password_hash="x", name=email.split("@")[0])
    db.add(user)
    db.flush()
    return user


def auth(user):
    return {"Authorization": f"Bearer {create_token(user.id)}"}


@pytest.fixture()
def lessons(db):
    rows = [Lesson(title=f"Lección {i}", position=i) for i in range(3)]
    db.add_all(rows)
    db.flush()
    return rows


def completed_ids(response):
    return [row["lesson_id"] for row in response.json()]


def test_completions_require_sign_in(client, lessons):
    assert client.get("/lessons/completions").status_code == 401
    assert client.post("/lessons/completions", json={"lesson_ids": [str(lessons[0].id)]}).status_code == 401
    assert client.delete(f"/lessons/{lessons[0].id}/completion").status_code == 401


def test_complete_is_idempotent_and_skips_deleted_lessons(client, db, lessons):
    me = make_user(db, "ana@example.com")
    first, second = str(lessons[0].id), str(lessons[1].id)
    response = client.post("/lessons/completions", json={"lesson_ids": [first]}, headers=auth(me))
    assert response.status_code == 200 and completed_ids(response) == [first]
    # Offline sync: a repeat, a new one and a lesson that no longer exists
    response = client.post("/lessons/completions", json={"lesson_ids": [first, second, str(uuid.uuid4())]}, headers=auth(me))
    assert response.status_code == 200 and sorted(completed_ids(response)) == sorted([first, second])
    assert sorted(completed_ids(client.get("/lessons/completions", headers=auth(me)))) == sorted([first, second])
    assert all(row["completed_at"] for row in response.json())


def test_empty_sync_returns_current_completions(client, db, lessons):
    me = make_user(db, "ana@example.com")
    client.post("/lessons/completions", json={"lesson_ids": [str(lessons[2].id)]}, headers=auth(me))
    response = client.post("/lessons/completions", json={"lesson_ids": []}, headers=auth(me))
    assert completed_ids(response) == [str(lessons[2].id)]


def test_users_only_see_their_own_completions(client, db, lessons):
    ana, jorge = make_user(db, "ana@example.com"), make_user(db, "jorge@example.com")
    client.post("/lessons/completions", json={"lesson_ids": [str(lessons[0].id)]}, headers=auth(ana))
    assert client.get("/lessons/completions", headers=auth(jorge)).json() == []
    client.delete(f"/lessons/{lessons[0].id}/completion", headers=auth(jorge))
    assert completed_ids(client.get("/lessons/completions", headers=auth(ana))) == [str(lessons[0].id)]


def test_uncomplete_removes_and_is_idempotent(client, db, lessons):
    me = make_user(db, "ana@example.com")
    lesson_id = str(lessons[0].id)
    client.post("/lessons/completions", json={"lesson_ids": [lesson_id]}, headers=auth(me))
    assert client.delete(f"/lessons/{lesson_id}/completion", headers=auth(me)).status_code == 204
    assert client.delete(f"/lessons/{lesson_id}/completion", headers=auth(me)).status_code == 204
    assert client.get("/lessons/completions", headers=auth(me)).json() == []


def test_deleting_a_lesson_removes_its_completions(client, db, lessons):
    me = make_user(db, "ana@example.com")
    client.post("/lessons/completions", json={"lesson_ids": [str(lessons[0].id)]}, headers=auth(me))
    db.delete(lessons[0])
    db.flush()
    db.expire_all()
    assert client.get("/lessons/completions", headers=auth(me)).json() == []
