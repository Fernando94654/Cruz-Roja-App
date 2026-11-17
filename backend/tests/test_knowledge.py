import json
from unittest.mock import Mock

from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.deps import get_db
from app.main import app
from scripts.knowledge_content import CHUNKS
from scripts.load_knowledge import BUNDLED, embed_missing, insert_missing


def fake_embed(texts):
    return "fake-model@1", {key: [0.5, 0.5] for key in texts}


def test_load_inserts_and_embeds_only_what_is_missing(db):
    assert insert_missing(db) == len(CHUNKS) == 32
    assert embed_missing(db, embed=fake_embed) == 32
    assert insert_missing(db) == 0
    assert embed_missing(db, embed=fake_embed) == 0


def test_knowledge_lists_the_chunks_with_their_vectors(client, db):
    insert_missing(db)
    embed_missing(db, embed=fake_embed)
    chunks = client.get("/knowledge").json()
    assert [c["id"] for c in chunks] == sorted(c["id"] for c in CHUNKS)
    bleeding = next(c for c in chunks if c["id"] == "hemorragia-grave-atender")
    assert bleeding["text"].startswith("Hemorragia grave\nQué hacer:\n1. ")
    assert bleeding["embedding"] == [0.5, 0.5] and bleeding["embedding_model"] == "fake-model@1"


# If this fails, run load_knowledge again
def test_bundled_app_knowledge_matches_content():
    bundled = json.loads(BUNDLED.read_text(encoding="utf-8"))
    assert [(c["id"], c["text"]) for c in bundled] == sorted((c["id"], c["text"]) for c in CHUNKS)
    assert all(len(c["embedding"]) == 768 for c in bundled)


def test_database_unavailable_returns_generic_503():
    database = Mock()
    database.scalars.side_effect = OperationalError("private connection details", {}, Exception("secret"))
    app.dependency_overrides[get_db] = lambda: database
    try:
        with TestClient(app) as client:
            response = client.get("/knowledge")
        assert response.status_code == 503
        assert response.json() == {"detail": "La información de primeros auxilios no está disponible. Intenta de nuevo."}
    finally:
        app.dependency_overrides.clear()
