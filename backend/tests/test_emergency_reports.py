from sqlalchemy import select

from app.models import EmergencyReport

REPORT = {
    "reporting_for": "other",
    "patient_name": "Abuela",
    "reason": "Caída",
    "injured_count": 1,
    "place": "Casa habitación",
    "mental_state": "Confundido",
    "skin": "Pálida",
    "transcript": "Mi abuela se cayó en la casa, está confundida y pálida",
    "summary": "Caída en casa habitación, 1 lesionado; confundido, piel pálida.",
    "medical_summary": "Sangre O+ · Alergias: Penicilina",
    "latitude": 25.6516,
    "longitude": -100.2895,
    "address": "Av. Eugenio Garza Sada 2501 Sur",
}


def test_create_report_returns_share_link(client, db):
    r = client.post("/emergency-reports", json=REPORT)
    assert r.status_code == 201
    token = r.json()["share_url"].rsplit("/r/", 1)[1]

    stored = db.scalar(select(EmergencyReport).where(EmergencyReport.share_token == token))
    assert stored.status.value == "sent"
    assert stored.ai_summary == REPORT["summary"]


def test_operator_page_shows_report(client):
    url = client.post("/emergency-reports", json=REPORT).json()["share_url"]
    page = client.get("/r/" + url.rsplit("/r/", 1)[1])
    assert page.status_code == 200
    assert "Caída en casa habitación" in page.text
    assert "25.651600, -100.289500" in page.text
    assert "Sangre O+" in page.text


def test_operator_page_escapes_html(client):
    url = client.post("/emergency-reports", json={**REPORT, "reason": "<script>x</script>", "summary": None}).json()["share_url"]
    page = client.get("/r/" + url.rsplit("/r/", 1)[1])
    assert "<script>x</script>" not in page.text


def test_unknown_token_is_404(client):
    assert client.get("/r/nope").status_code == 404


def test_rejects_invalid_coordinates(client):
    assert client.post("/emergency-reports", json={**REPORT, "latitude": 200}).status_code == 422
