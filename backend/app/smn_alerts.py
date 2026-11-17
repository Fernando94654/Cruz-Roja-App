"""Importa las alertas oficiales del Servicio Meteorologico Nacional (SMN) a la tabla official_alerts.

El SMN publica sus avisos (lluvias, frentes frios, ciclones tropicales) en un feed Atom gratuito
y sin llave, con licencia CC BY 4.0. Cada entrada apunta a un archivo CAP 1.2 (Common Alerting
Protocol) con la severidad, la vigencia y el poligono de la zona afectada.

    fetch_active_alerts()  Descarga y convierte los avisos vigentes, sin tocar la base de datos
    sync(db)               Guarda los avisos vigentes y borra los que expiraron hace mas de un dia
    sync_if_due()          Igual que sync, pero como maximo una vez cada SYNC_MINUTES (lo usa GET /alerts/official)
"""

import logging
import threading
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models import OfficialAlert
from app.models.alerts import Severity

log = logging.getLogger(__name__)

FEED_URL = "https://smn.conagua.gob.mx/tools/PHP/feedsmn/cap.php"
SMN_TYPE = "smn"
SOURCE = "SMN"
SYNC_MINUTES = 15
# El feed conserva cientos de avisos viejos; solo se descargan los publicados en estos ultimos dias
RECENT_DAYS = 3
TIMEOUT = 15

ATOM = "{http://www.w3.org/2005/Atom}"
CAP = "{urn:oasis:names:tc:emergency:cap:1.2}"

# Severidad CAP -> severidad de la app
SEVERITY = {
    "Extreme": Severity.extreme,
    "Severe": Severity.high,
    "Moderate": Severity.moderate,
    "Minor": Severity.info,
    "Unknown": Severity.info,
}

# Abreviaturas de estados que usa el SMN en areaDesc
STATES = {
    "AGS": "Aguascalientes", "BC": "Baja California", "BCS": "Baja California Sur", "CAMP": "Campeche",
    "CHIS": "Chiapas", "CHIH": "Chihuahua", "CDMX": "Ciudad de México", "COAH": "Coahuila",
    "COL": "Colima", "DGO": "Durango", "GTO": "Guanajuato", "GRO": "Guerrero", "HGO": "Hidalgo",
    "JAL": "Jalisco", "MEX": "Estado de México", "EDOMEX": "Estado de México", "MICH": "Michoacán",
    "MOR": "Morelos", "NAY": "Nayarit", "NL": "Nuevo León", "OAX": "Oaxaca", "PUE": "Puebla",
    "QRO": "Querétaro", "QROO": "Quintana Roo", "SLP": "San Luis Potosí", "SIN": "Sinaloa",
    "SON": "Sonora", "TAB": "Tabasco", "TAMPS": "Tamaulipas", "TLAX": "Tlaxcala", "VER": "Veracruz",
    "YUC": "Yucatán", "ZAC": "Zacatecas",
}

# Si un aviso no trae poligono se usa el rectangulo de Mexico para no perderlo
MEXICO_BOX = "(((-118.4 14.5,-86.7 14.5,-86.7 32.7,-118.4 32.7,-118.4 14.5)))"


def text(node: ET.Element | None, tag: str) -> str | None:
    child = node.find(CAP + tag) if node is not None else None
    return child.text.strip() if child is not None and child.text else None


# Convierte "TAMPS, VER" en "Tamaulipas, Veracruz"; las abreviaturas desconocidas se dejan igual
def state_names(area_desc: str) -> str:
    names = [STATES.get(code.strip().upper(), code.strip()) for code in area_desc.split(",") if code.strip()]
    return ", ".join(dict.fromkeys(names))


# CAP usa "lat,lon lat,lon ..."; PostGIS espera "lon lat, lon lat, ..." con el anillo cerrado
def ring_wkt(polygon: str) -> str | None:
    points = []
    for pair in polygon.split():
        lat, lon = pair.split(",")
        points.append(f"{float(lon)} {float(lat)}")
    if len(points) < 3:
        return None
    if points[0] != points[-1]:
        points.append(points[0])
    return "((" + ",".join(points) + "))"


def parse_cap(xml: bytes, url: str) -> dict | None:
    """Convierte un archivo CAP en los campos de OfficialAlert. Regresa None si no aplica."""
    alert = ET.fromstring(xml)
    info = alert.find(CAP + "info")
    if info is None or text(alert, "status") != "Actual" or text(alert, "msgType") == "Cancel":
        return None
    expires = text(info, "expires")
    starts = text(info, "effective") or text(alert, "sent")
    if not expires or not starts:
        return None

    areas = info.findall(CAP + "area")
    rings = [ring_wkt(p.text) for a in areas for p in a.findall(CAP + "polygon") if p.text]
    rings = [r for r in rings if r]
    area_desc = ", ".join(d for a in areas if (d := text(a, "areaDesc")))

    event = text(info, "event") or "Aviso del SMN"
    headline = text(info, "headline")
    title = f"{event}: {headline}" if headline else event
    return {
        # El id se deriva del archivo CAP, asi volver a importar el mismo aviso no lo duplica
        "id": uuid.uuid5(uuid.NAMESPACE_URL, url),
        "source": SOURCE,
        "type": SMN_TYPE,
        "title": title[:160],
        "description": text(info, "description"),
        "area_name": state_names(area_desc)[:120] or None,
        "severity": SEVERITY.get(text(info, "severity") or "", Severity.info),
        "area": "SRID=4326;MULTIPOLYGON(" + (",".join(rings) if rings else MEXICO_BOX[1:-1]) + ")",
        "starts_at": datetime.fromisoformat(starts),
        "expires_at": datetime.fromisoformat(expires),
    }


def fetch_active_alerts(now: datetime | None = None) -> list[dict]:
    """Descarga el feed del SMN y regresa los avisos que siguen vigentes."""
    now = now or datetime.now(timezone.utc)
    alerts = []
    with httpx.Client(timeout=TIMEOUT, follow_redirects=True) as client:
        feed = ET.fromstring(client.get(FEED_URL).raise_for_status().content)
        for entry in feed.iter(ATOM + "entry"):
            updated = entry.findtext(ATOM + "updated")
            link = entry.find(ATOM + "link")
            if not updated or link is None or datetime.fromisoformat(updated) < now - timedelta(days=RECENT_DAYS):
                continue
            url = link.get("href")
            try:
                alert = parse_cap(client.get(url).raise_for_status().content, url)
            except (httpx.HTTPError, ET.ParseError, ValueError) as error:
                # Un archivo danado no debe impedir que se importen los demas
                log.warning("Aviso del SMN omitido %s: %s", url, error)
                continue
            if alert and alert["expires_at"] > now:
                alerts.append(alert)
    return alerts


def sync(db: Session) -> int:
    """Guarda en la base de datos los avisos vigentes del SMN. Regresa cuantos se guardaron."""
    now = datetime.now(timezone.utc)
    alerts = fetch_active_alerts(now)
    for alert in alerts:
        # merge inserta el aviso nuevo o actualiza el existente con el mismo id
        db.merge(OfficialAlert(**alert))
    db.execute(delete(OfficialAlert).where(OfficialAlert.type == SMN_TYPE,
                                           OfficialAlert.expires_at < now - timedelta(days=1)))
    db.commit()
    return len(alerts)


_last_sync: datetime | None = None
_lock = threading.Lock()


def sync_if_due() -> None:
    """Sincroniza con el SMN si ya pasaron SYNC_MINUTES desde la ultima vez. Los errores solo se registran."""
    global _last_sync
    now = datetime.now(timezone.utc)
    with _lock:
        if _last_sync and now - _last_sync < timedelta(minutes=SYNC_MINUTES):
            return
        _last_sync = now
    from app.db import SessionLocal

    try:
        with SessionLocal() as db:
            log.info("Avisos del SMN sincronizados: %d", sync(db))
    except Exception:
        # Si el SMN no responde, la app sigue mostrando las alertas que ya estaban guardadas
        log.exception("No se pudieron sincronizar los avisos del SMN")
