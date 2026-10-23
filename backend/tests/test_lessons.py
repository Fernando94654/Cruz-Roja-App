import uuid
from unittest.mock import Mock

from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.deps import get_db
from app.main import app
from app.models.learning import Lesson


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
