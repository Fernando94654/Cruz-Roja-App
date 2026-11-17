"""Carga alertas oficiales de demostracion mientras no se integran las fuentes reales (SMN, Proteccion Civil).

    python scripts/demo_official_alerts.py           # reemplaza las alertas de demo por unas nuevas
    python scripts/demo_official_alerts.py --remove  # elimina las alertas de demo

Solo modifica las alertas con type 'demo'; el resto de la base de datos no se altera.
"""

import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete

from app.db import SessionLocal
from app.models import OfficialAlert
from app.models.alerts import Severity

DEMO_TYPE = "demo"
DAYS = 60


# Genera el area de la alerta como un rectangulo (MULTIPOLYGON) a partir de sus limites
def box(west: float, south: float, east: float, north: float) -> str:
    return f"SRID=4326;MULTIPOLYGON((({west} {south},{east} {south},{east} {north},{west} {north},{west} {south})))"


# Alertas de ejemplo: fuente, titulo, descripcion, zona, severidad, area y minutos desde que iniciaron
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
        # Primero se eliminan las alertas de demo anteriores para no duplicarlas
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
