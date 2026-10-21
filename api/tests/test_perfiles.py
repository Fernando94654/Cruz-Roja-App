"""Pruebas del API de perfil médico.

Usan una base SQLite en memoria para no depender de PostgreSQL.
Correr con:  pytest
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.models import Usuario

PERFIL = {
    "nombre": "María López",
    "fecha_nacimiento": "1958-03-14",
    "tipo_sangre": "O+",
    "alergias": ["Penicilina"],
    "padecimientos": ["Asma"],
    "medicamentos": ["Salbutamol"],
    "contactos": [{"nombre": "Ana López", "parentesco": "Hija", "telefono": "81 1234 5678"}],
}


@pytest.fixture()
def cliente():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Sesion = sessionmaker(bind=engine, expire_on_commit=False)
    Base.metadata.create_all(engine)
    with Sesion() as db:
        db.add(Usuario(id=1, nombre="Demo", correo="demo@enlacevital.mx"))
        db.commit()

    def get_db_prueba():
        with Sesion() as db:
            yield db

    app.dependency_overrides[get_db] = get_db_prueba
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_get_regresa_404_si_no_hay_perfil(cliente):
    r = cliente.get("/usuarios/1/perfil")
    assert r.status_code == 404


def test_get_regresa_404_si_no_existe_el_usuario(cliente):
    r = cliente.get("/usuarios/99/perfil")
    assert r.status_code == 404
    assert r.json()["detail"] == "Usuario no encontrado"


def test_put_crea_y_get_regresa_el_perfil(cliente):
    r = cliente.put("/usuarios/1/perfil", json=PERFIL)
    assert r.status_code == 200

    r = cliente.get("/usuarios/1/perfil")
    assert r.status_code == 200
    datos = r.json()
    assert datos["usuario_id"] == 1
    assert datos["tipo_sangre"] == "O+"
    assert datos["alergias"] == ["Penicilina"]
    assert datos["medicamentos"] == ["Salbutamol"]
    # El teléfono se guarda solo con dígitos.
    assert datos["contactos"][0]["telefono"] == "8112345678"


def test_put_reemplaza_las_listas(cliente):
    cliente.put("/usuarios/1/perfil", json=PERFIL)
    cambio = {**PERFIL, "alergias": ["Látex", "Nueces"], "contactos": []}
    datos = cliente.put("/usuarios/1/perfil", json=cambio).json()
    assert datos["alergias"] == ["Látex", "Nueces"]
    assert datos["contactos"] == []
    assert datos["padecimientos"] == ["Asma"]


def test_put_limpia_vacios_y_repetidos(cliente):
    cambio = {**PERFIL, "alergias": [" Penicilina ", "", "penicilina", "Látex"]}
    datos = cliente.put("/usuarios/1/perfil", json=cambio).json()
    assert datos["alergias"] == ["Penicilina", "Látex"]


@pytest.mark.parametrize(
    "campo, valor",
    [
        ("nombre", "   "),
        ("tipo_sangre", "Z+"),
        ("fecha_nacimiento", "2999-01-01"),
        ("contactos", [{"nombre": "Ana", "parentesco": "Hija", "telefono": "123"}]),
    ],
)
def test_put_rechaza_datos_invalidos(cliente, campo, valor):
    r = cliente.put("/usuarios/1/perfil", json={**PERFIL, campo: valor})
    assert r.status_code == 422


def test_salud(cliente):
    assert cliente.get("/salud").json() == {"estado": "ok"}
