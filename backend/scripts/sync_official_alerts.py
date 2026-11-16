"""Importa ahora mismo los avisos vigentes del Servicio Meteorologico Nacional (SMN).

    python scripts/sync_official_alerts.py            # guarda los avisos en official_alerts
    python scripts/sync_official_alerts.py --dry-run  # solo muestra los avisos, no toca la base de datos

El servidor tambien los importa solo cada 15 minutos al consultar GET /alerts/official.
Solo modifica las alertas con type 'smn'; las de demo y el resto de la base de datos no se alteran.
"""

import sys

from app import smn_alerts


def main() -> None:
    if "--dry-run" in sys.argv:
        alerts = smn_alerts.fetch_active_alerts()
        for a in alerts:
            print(f"[{a['severity'].value:8}] {a['title']} | {a['area_name']} | vence {a['expires_at']:%Y-%m-%d %H:%M}")
        print(f"{len(alerts)} avisos vigentes (no se guardo nada)")
        return
    from app.db import SessionLocal

    with SessionLocal() as db:
        print(f"Guardados {smn_alerts.sync(db)} avisos vigentes del SMN")


if __name__ == "__main__":
    main()
