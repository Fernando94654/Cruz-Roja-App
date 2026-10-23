import os

from cryptography.fernet import Fernet
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
os.environ.setdefault("MEDICAL_DATA_KEY", Fernet.generate_key().decode())
os.environ.setdefault("JWT_SECRET", "test-secret-that-is-long-enough-for-hs256")

# Tests run against a separate database in the same Postgres container
_main_url = make_url(os.environ["DATABASE_URL"])
_test_url = _main_url.set(database=f"{_main_url.database}_test")
os.environ["DATABASE_URL"] = _test_url.render_as_string(hide_password=False)

import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.db import engine  # noqa: E402
from app.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def test_database():
    admin = create_engine(_main_url, isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        conn.execute(text(f'DROP DATABASE IF EXISTS "{_test_url.database}" WITH (FORCE)'))
        conn.execute(text(f'CREATE DATABASE "{_test_url.database}"'))
    command.upgrade(Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini")), "head")
    yield
    engine.dispose()
    with admin.connect() as conn:
        conn.execute(text(f'DROP DATABASE IF EXISTS "{_test_url.database}" WITH (FORCE)'))
    admin.dispose()


@pytest.fixture()
def db():
    # Each test runs in a transaction that is rolled back, even when the code commits
    with engine.connect() as connection:
        transaction = connection.begin()
        session = Session(bind=connection, join_transaction_mode="create_savepoint")
        yield session
        session.close()
        transaction.rollback()


@pytest.fixture()
def client(db):
    app.dependency_overrides[get_db] = lambda: db
    yield TestClient(app)
    app.dependency_overrides.clear()
