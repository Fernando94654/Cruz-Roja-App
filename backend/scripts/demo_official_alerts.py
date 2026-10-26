"""Demo official alerts for presentations, until the real SMN / Protección Civil ingestion exists.

    python scripts/demo_official_alerts.py           # replaces the demo alerts with fresh ones
    python scripts/demo_official_alerts.py --remove  # deletes the demo alerts

Only touches official_alerts rows with type 'demo'; everything else in the database stays as is.
"""

import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete

from app.db import SessionLocal
from app.models import OfficialAlert
from app.models.alerts import Severity

DEMO_TYPE = "demo"
DAYS = 60


def box(west: float, south: float, east: float, north: float) -> str:
    return f"SRID=4326;MULTIPOLYGON((({west} {south},{east} {south},{east} {north},{west} {north},{west} {south})))"


ALERTS = [
    ("Protección Civil NL", "Lluvias intensas en el área metropolitana",
     "Evita cruzar calles inundadas y mantente en un lugar seguro.",
     "Monterrey", Severity.high, box(-100.40, 25.60, -100.23, 25.75), 20),
    ("SMN", "Tormenta eléctrica",
     "Desconecta aparatos eléctricos y no te refugies bajo árboles.",
     "Apodaca", Severity.extreme, box(-100.25, 25.75, -100.12, 25.85), 45),
    ("Protección Civil NL", "Evitar cruces inundables",
     "Arroyos y pasos a desnivel con corriente fuerte. Usa rutas alternas.",
     "San Nicolás de los Garza", Severity.moderate, box(-100.32, 25.72, -100.24, 25.78), 90),
    ("SMN", "Frente frío: descenso de temperatura",
     "Temperaturas de 5 a 10 °C por la noche. Abrígate y revisa calentadores.",
     "Nuevo León", Severity.info, box(-101.2, 23.1, -98.4, 27.8), 180),
]


def main() -> None:
    remove_only = "--remove" in sys.argv
    now = datetime.now(timezone.utc)
    with SessionLocal.begin() as s:
        removed = s.execute(delete(OfficialAlert).where(OfficialAlert.type == DEMO_TYPE)).rowcount
        if not remove_only:
            s.add_all(
                OfficialAlert(source=source, type=DEMO_TYPE, title=title, description=description,
                              area_name=area_name, severity=severity, area=area,
                              starts_at=now - timedelta(minutes=minutes_ago),
                              expires_at=now + timedelta(days=DAYS))
                for source, title, description, area_name, severity, area, minutes_ago in ALERTS
            )
    print(f"Removed {removed} demo alerts" + ("" if remove_only else f", added {len(ALERTS)} (valid {DAYS} days)"))


if __name__ == "__main__":
    main()
