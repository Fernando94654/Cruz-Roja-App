"""Pruebas del importador de avisos del SMN con un archivo CAP de ejemplo, sin usar la red."""

from datetime import datetime, timezone

from app.models.alerts import Severity
from app.smn_alerts import parse_cap, state_names

CAP_XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
  <identifier>avisossmn-LLuvias-481</identifier>
  <sent>2026-11-16T11:40:00-06:00</sent>
  <status>Actual</status>
  <msgType>Alert</msgType>
  <info>
    <event>Aviso de lluvias</event>
    <severity>Severe</severity>
    <effective>2026-11-16T11:40:00-06:00</effective>
    <expires>2026-11-17T06:00:00-06:00</expires>
    <headline>Frente frio num. 6</headline>
    <description>Lluvias muy fuertes (50 a 75 mm).</description>
    <area>
      <areaDesc>NL, TAMPS</areaDesc>
      <polygon>25.0,-100.0 26.0,-100.0 26.0,-99.0 25.0,-100.0</polygon>
    </area>
  </info>
</alert>"""

URL = "https://smn.conagua.gob.mx/tools/PHP/feedsmn/FILES/xml_cap/ejemplo_cap.xml"


def test_parse_cap_maps_fields():
    alert = parse_cap(CAP_XML, URL)
    assert alert["source"] == "SMN" and alert["type"] == "smn"
    assert alert["title"] == "Aviso de lluvias: Frente frio num. 6"
    assert alert["area_name"] == "Nuevo León, Tamaulipas"
    assert alert["severity"] == Severity.high
    assert alert["expires_at"] == datetime(2026, 11, 17, 12, 0, tzinfo=timezone.utc)
    # CAP usa lat,lon y PostGIS lon lat
    assert alert["area"] == "SRID=4326;MULTIPOLYGON(((-100.0 25.0,-100.0 26.0,-99.0 26.0,-100.0 25.0)))"


def test_same_file_gets_same_id():
    assert parse_cap(CAP_XML, URL)["id"] == parse_cap(CAP_XML, URL)["id"]


def test_cancel_and_test_messages_are_ignored():
    assert parse_cap(CAP_XML.replace(b"<msgType>Alert", b"<msgType>Cancel"), URL) is None
    assert parse_cap(CAP_XML.replace(b"<status>Actual", b"<status>Test"), URL) is None


def test_alert_without_polygon_uses_mexico_box():
    xml = CAP_XML.replace(b"<polygon>25.0,-100.0 26.0,-100.0 26.0,-99.0 25.0,-100.0</polygon>", b"")
    assert parse_cap(xml, URL)["area"].startswith("SRID=4326;MULTIPOLYGON(((-118.4 14.5")


def test_unknown_state_codes_are_kept():
    assert state_names("NL, XYZ, NL") == "Nuevo León, XYZ"
