"""Pruebas de los endpoints de alertas oficiales y reportes de vecinos."""

from datetime import datetime, timedelta, timezone

import pytest

from app import smn_alerts
from app.auth import create_token
from app.models import CommunityReport, OfficialAlert, User
from app.models.alerts import CommunityReportType, Severity

# Monterrey y Veracruz, para probar el filtro por zona
MTY = (25.6516, -100.2895)
VER = (19.1738, -96.1342)
NOW = datetime.now(timezone.utc)


def box(west, south, east, north):
    return f"SRID=4326;MULTIPOLYGON((({west} {south},{east} {south},{east} {north},{west} {north},{west} {south})))"


def make_user(db, name):
    user = User(email=f"{name.lower()}@example.com", password_hash="x", name=name)
    db.add(user)
    db.flush()
    return user


def auth(user):
    return {"Authorization": f"Bearer {create_token(user.id)}"}


@pytest.fixture(autouse=True)
def no_smn(monkeypatch):
    # Las pruebas no deben descargar avisos reales del SMN
    monkeypatch.setattr(smn_alerts, "sync_if_due", lambda: None)


@pytest.fixture()
def alerts(db):
    """Una alerta vigente en Monterrey, otra en Veracruz y una que ya expiro en Monterrey."""
    def alert(title, area, expires):
        return OfficialAlert(source="SMN", type="smn", title=title, severity=Severity.high, area=area,
                             area_name="Prueba", starts_at=NOW - timedelta(hours=1), expires_at=expires)

    db.add_all([
        alert("Lluvia en Monterrey", box(-100.5, 25.5, -100.1, 25.9), NOW + timedelta(hours=5)),
        alert("Frente frio en Veracruz", box(-96.5, 18.9, -95.9, 19.5), NOW + timedelta(hours=5)),
        alert("Alerta vieja", box(-100.5, 25.5, -100.1, 25.9), NOW - timedelta(minutes=1)),
    ])
    db.flush()


def titles(response):
    assert response.status_code == 200
    return {a["title"] for a in response.json()}


def test_official_alerts_without_location_returns_all_active(client, alerts):
    assert titles(client.get("/alerts/official")) == {"Lluvia en Monterrey", "Frente frio en Veracruz"}


def test_official_alerts_near_returns_only_that_zone(client, alerts):
    assert titles(client.get("/alerts/official/near/%s/%s" % MTY)) == {"Lluvia en Monterrey"}
    assert titles(client.get("/alerts/official/near/%s/%s" % VER)) == {"Frente frio en Veracruz"}
    assert titles(client.get("/alerts/official/near/20.67/-103.35")) == set()  # Guadalajara


def test_official_alerts_near_rejects_invalid_coordinates(client):
    assert client.get("/alerts/official/near/95/-100").status_code == 422
    assert client.get("/alerts/official/near/25/-200").status_code == 422


@pytest.fixture()
def people(db):
    return make_user(db, "Ana"), make_user(db, "Beto")


def publish(client, user, title, where=MTY, type_="flood"):
    body = {"type": type_, "title": title, "latitude": where[0], "longitude": where[1]}
    response = client.post("/alerts/reports", json=body, headers=auth(user))
    assert response.status_code == 201
    return response.json()


def test_reports_near_only_include_reports_within_radius(client, people):
    ana, beto = people
    publish(client, ana, "Calle inundada", MTY)
    publish(client, ana, "Arbol caido a 3 km", (25.6786, -100.2895))
    publish(client, ana, "Semaforo en Veracruz", VER)

    near = titles(client.get("/alerts/reports/near/%s/%s" % MTY, headers=auth(beto)))
    assert near == {"Calle inundada", "Arbol caido a 3 km"}
    everywhere = titles(client.get("/alerts/reports", headers=auth(beto)))
    assert "Semaforo en Veracruz" in everywhere


def test_reports_require_sign_in(client):
    assert client.get("/alerts/reports").status_code == 401
    assert client.get("/alerts/reports/near/%s/%s" % MTY).status_code == 401


def test_expired_reports_are_hidden(client, db, people):
    ana, beto = people
    db.add(CommunityReport(user_id=ana.id, type=CommunityReportType.fire, details="Humo viejo",
                           location="SRID=4326;POINT(-100.2895 25.6516)", expires_at=NOW - timedelta(minutes=1)))
    db.flush()
    assert titles(client.get("/alerts/reports/near/%s/%s" % MTY, headers=auth(beto))) == set()


def test_one_vote_per_user_and_no_self_confirm(client, people):
    ana, beto = people
    report = publish(client, ana, "Calle inundada")
    rid = report["id"]
    assert report["is_mine"] is True

    assert client.post(f"/alerts/reports/{rid}/confirm", headers=auth(ana)).status_code == 409

    confirmed = client.post(f"/alerts/reports/{rid}/confirm", headers=auth(beto)).json()
    assert confirmed["confirmations"] == 1 and confirmed["confirmed_by_me"] and not confirmed["is_mine"]
    # Repetir la confirmacion no duplica el voto
    assert client.post(f"/alerts/reports/{rid}/confirm", headers=auth(beto)).json()["confirmations"] == 1
    # Marcar como falso cambia el voto
    flagged = client.post(f"/alerts/reports/{rid}/flag", headers=auth(beto)).json()
    assert flagged["confirmations"] == 0 and flagged["flags"] == 1 and flagged["flagged_by_me"]
    undone = client.delete(f"/alerts/reports/{rid}/flag", headers=auth(beto)).json()
    assert undone["flags"] == 0 and not undone["flagged_by_me"]


def test_report_hidden_after_three_flags(client, db, people):
    ana, _ = people
    rid = publish(client, ana, "Reporte falso")["id"]
    for name in ("Carla", "Diego", "Eva"):
        assert client.post(f"/alerts/reports/{rid}/flag", headers=auth(make_user(db, name))).status_code == 200
    assert titles(client.get("/alerts/reports/near/%s/%s" % MTY, headers=auth(ana))) == set()
    assert client.post(f"/alerts/reports/{rid}/flag", headers=auth(make_user(db, "Fer"))).status_code == 404


def test_official_alerts_only_current_and_newest_first(client, db):
    """Una alerta que todavia no empieza no aparece, y las vigentes llegan de la mas reciente a la mas antigua."""
    def alert(title, starts):
        return OfficialAlert(source="SMN", type="smn", title=title, severity=Severity.info,
                             area=box(-100.5, 25.5, -100.1, 25.9), area_name="Prueba",
                             starts_at=starts, expires_at=NOW + timedelta(days=1))

    db.add_all([
        alert("Vieja", NOW - timedelta(hours=3)),
        alert("Reciente", NOW - timedelta(minutes=5)),
        alert("Futura", NOW + timedelta(hours=2)),
    ])
    db.flush()
    response = client.get("/alerts/official")
    assert response.status_code == 200
    assert [a["title"] for a in response.json()] == ["Reciente", "Vieja"]


def test_reports_never_expose_the_author(client, people):
    ana, beto = people
    publish(client, ana, "Calle inundada")
    report = client.get("/alerts/reports", headers=auth(beto)).json()[0]
    assert report["is_mine"] is False
    assert set(report) == {"id", "type", "title", "confirmations", "confirmed_by_me", "flags",
                           "flagged_by_me", "is_mine", "expires_at"}
    assert ana.name not in str(report) and ana.email not in str(report)


def test_cannot_confirm_own_report_message(client, people):
    ana, _ = people
    rid = publish(client, ana, "Humo en el parque")["id"]
    response = client.post(f"/alerts/reports/{rid}/confirm", headers=auth(ana))
    assert response.status_code == 409
    assert response.json()["detail"] == "No puedes confirmar tu propio reporte"
