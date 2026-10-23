import os
import re

import pytest
from cryptography.fernet import Fernet
from sqlalchemy.engine import make_url

os.environ.setdefault("JWT_SECRET", "test-secret-that-is-long-enough-for-hs256")

# Never load .env or derive a test target from the application's database.
_raw_url = os.environ.get("TEST_DATABASE_URL")
if not _raw_url:
    raise pytest.UsageError("Set TEST_DATABASE_URL explicitly to a separate local PostgreSQL database ending in _test.")
_test_url = make_url(_raw_url)
if (
    _test_url.get_backend_name() != "postgresql"
    or _test_url.host not in {"localhost", "127.0.0.1", "::1"}
    or not re.fullmatch(r"[a-zA-Z0-9_]+_test", _test_url.database or "")
    or _test_url.query  # reject host/service overrides that could redirect to a remote server
):
    raise pytest.UsageError("TEST_DATABASE_URL must use local PostgreSQL, a name ending in _test, and no query overrides.")
os.environ["DATABASE_URL"] = _test_url.render_as_string(hide_password=False)
os.environ["MEDICAL_DATA_KEY"] = Fernet.generate_key().decode()

from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.db import engine  # noqa: E402
from app.deps import get_db  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(scope="session")
def test_database():
    admin = create_engine(_test_url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    # Do not drop an existing database: a typo must not destroy another test suite's data.
    with admin.connect() as conn:
        conn.execute(text(f'CREATE DATABASE "{_test_url.database}"'))
    try:
        command.upgrade(Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini")), "head")
        yield
    finally:
        engine.dispose()
        with admin.connect() as conn:
            conn.execute(text(f'DROP DATABASE "{_test_url.database}" WITH (FORCE)'))
        admin.dispose()


@pytest.fixture()
def db(test_database):
    with engine.connect() as connection:
        transaction = connection.begin()
        session = Session(bind=connection, join_transaction_mode="create_savepoint")
        yield session
        session.close()
        transaction.rollback()


@pytest.fixture()
def client(db):
    app.dependency_overrides[get_db] = lambda: db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
