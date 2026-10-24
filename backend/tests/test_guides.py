from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import IntegrityError, OperationalError

from app.deps import get_db
from app.main import app
from app.models.learning import Guide, Lesson

SEEDED = ["cardiac_arrest", "choking", "bleeding", "burn", "seizure", "fainting"]


def test_seeded_guides_come_in_order_with_their_steps(client):
    response = client.get("/guides")
    assert response.status_code == 200
    rows = response.json()
    assert [r["id"] for r in rows] == SEEDED
    cpr = rows[0]
    assert cpr["title"] == "Paro cardiaco" and cpr["icon"] == "heart.slash.fill" and cpr["manual_page"] == 34
    assert "no respira" in cpr["keywords"]
    assert [s["title"] for s in cpr["steps"]][:2] == ["Revisa la escena", "Revisa si responde"]
    # Optional timer and rhythm come back as null when a step has none
    assert cpr["steps"][0]["seconds"] is None and cpr["steps"][0]["rate"] is None
    assert cpr["steps"][3]["seconds"] == 18 and cpr["steps"][3]["rate"] == 110


def test_guide_edits_come_from_database(client, db):
    db.add(Guide(id="allergy", title="Alergia", icon="allergens", position=-1,
                 steps=[{"title": "Llama", "instruction": "Pide ayuda.", "icon": "phone.fill"}]))
    db.flush()
    first = client.get("/guides").json()[0]
    assert first["id"] == "allergy" and first["keywords"] == [] and first["manual_page"] is None
    assert first["steps"] == [{"title": "Llama", "instruction": "Pide ayuda.", "icon": "phone.fill", "seconds": None, "rate": None}]


def test_lesson_cannot_point_to_unknown_guide(db):
    db.add(Lesson(title="RCP", guide_id="no_existe"))
    with pytest.raises(IntegrityError):
        db.flush()


def test_deleting_a_guide_unlinks_its_lessons(db):
    db.add(Guide(id="temporal", title="Temporal", icon="clock"))
    lesson = Lesson(title="Video", guide_id="temporal")
    db.add(lesson)
    db.flush()
    db.delete(db.get(Guide, "temporal"))
    db.flush()
    db.refresh(lesson)
    assert lesson.guide_id is None


def test_database_unavailable_returns_generic_503():
    database = Mock()
    database.scalars.side_effect = OperationalError("private connection details", {}, Exception("secret"))
    app.dependency_overrides[get_db] = lambda: database
    try:
        with TestClient(app) as client:
            response = client.get("/guides")
        assert response.status_code == 503
        assert response.json() == {"detail": "Las guías no están disponibles. Intenta de nuevo."}
    finally:
        app.dependency_overrides.clear()
