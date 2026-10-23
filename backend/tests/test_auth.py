import pytest
from argon2 import PasswordHasher

from app.models import User


@pytest.fixture()
def user(db):
    user = User(email="maria@example.com", password_hash=PasswordHasher().hash("demo1234"), name="María")
    db.add(user)
    db.flush()
    return user


def test_login_returns_a_token_that_opens_the_family(client, user):
    r = client.post("/auth/login", json={"email": "Maria@Example.com ", "password": "demo1234"})
    assert r.status_code == 200
    assert r.json()["name"] == "María"

    token = r.json()["access_token"]
    assert client.get("/family", headers={"Authorization": f"Bearer {token}"}).status_code == 200


@pytest.mark.parametrize("email, password", [("maria@example.com", "wrong"), ("nobody@example.com", "demo1234")])
def test_login_rejects_wrong_credentials_with_the_same_message(client, user, email, password):
    r = client.post("/auth/login", json={"email": email, "password": password})
    assert r.status_code == 401
    assert r.json()["detail"] == "Correo o contraseña incorrectos"
