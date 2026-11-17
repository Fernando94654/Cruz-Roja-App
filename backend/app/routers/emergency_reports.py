import os
import secrets
from datetime import datetime, timezone
from html import escape

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from geoalchemy2 import Geometry
from sqlalchemy import cast, func, select
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import EmergencyReport
from app.models.reports import ReportingFor, ReportStatus
from app.schemas.emergency_report import EmergencyReportCreated, EmergencyReportIn

router = APIRouter(tags=["Emergency reports"])


def public_base_url(request: Request) -> str:
    """Base URL used in the operator links."""
    # Set PUBLIC_BASE_URL to an address reachable from the operator's phone (e.g. the LAN IP)
    return os.environ.get("PUBLIC_BASE_URL", str(request.base_url)).rstrip("/")


@router.post("/emergency-reports", response_model=EmergencyReportCreated, status_code=status.HTTP_201_CREATED)
def create_report(data: EmergencyReportIn, request: Request, db: Session = Depends(get_db)) -> EmergencyReportCreated:
    """Store an emergency report and return its operator link."""
    fields = data.model_dump(exclude={"reporting_for", "summary", "latitude", "longitude"})
    report = EmergencyReport(
        **fields,
        reporting_for=ReportingFor(data.reporting_for),
        ai_summary=data.summary,
        location=f"SRID=4326;POINT({data.longitude} {data.latitude})",
        status=ReportStatus.sent,
        sent_at=datetime.now(timezone.utc),
        share_token=secrets.token_urlsafe(12),
    )
    db.add(report)
    db.commit()
    return EmergencyReportCreated(id=report.id, share_url=f"{public_base_url(request)}/r/{report.share_token}")


@router.get("/r/{token}", response_class=HTMLResponse, include_in_schema=False)
def operator_page(token: str, db: Session = Depends(get_db)) -> str:
    """Show the operator page for a shared report."""
    point = cast(EmergencyReport.location, Geometry)
    row = db.execute(
        select(EmergencyReport, func.ST_Y(point), func.ST_X(point)).where(EmergencyReport.share_token == token)
    ).first()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Reporte no encontrado")
    report, lat, lng = row
    return render_operator_page(report, lat, lng)


def render_operator_page(report: EmergencyReport, lat: float, lng: float) -> str:
    """Render the report, map and medical summary as HTML."""
    rows = [
        ("Para", report.patient_name or ("La persona que reporta" if report.reporting_for == ReportingFor.self else "Otra persona")),
        ("Motivo", report.reason),
        ("Lesionados", str(report.injured_count)),
        ("Lesión principal", report.injury),
        ("Lugar", report.place),
        ("Estado mental", report.mental_state),
        ("Respiración", report.breathing),
        ("Color de piel", report.skin),
        ("Referencia", report.reference),
        ("Perfil médico", report.medical_summary),
        ("Lo que dijo", report.transcript),
    ]
    table = "".join(f"<tr><th>{escape(k)}</th><td>{escape(v or '—')}</td></tr>" for k, v in rows)
    bbox = f"{lng - 0.004},{lat - 0.003},{lng + 0.004},{lat + 0.003}"
    sent = report.sent_at.astimezone().strftime("%d/%m/%Y %H:%M") if report.sent_at else ""
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reporte de emergencia</title>
<style>
body{{font-family:-apple-system,Helvetica,Arial,sans-serif;margin:0;background:#f2f2f7;color:#111}}
header{{background:#EE140A;color:#fff;padding:16px}}h1{{margin:0;font-size:22px}}
main{{padding:16px;max-width:720px;margin:auto}}.card{{background:#fff;border-radius:12px;padding:16px;margin-bottom:12px}}
th{{text-align:left;color:#666;font-weight:500;padding:6px 12px 6px 0;vertical-align:top;white-space:nowrap}}td{{padding:6px 0}}
iframe{{width:100%;height:280px;border:0;border-radius:12px}}a{{color:#EE140A}}
</style></head><body>
<header><h1>Reporte de emergencia</h1><div>Enviado {escape(sent)}</div></header>
<main>
<div class="card"><strong>{escape(report.ai_summary or report.reason or 'Sin resumen')}</strong></div>
<div class="card"><iframe src="https://www.openstreetmap.org/export/embed.html?bbox={bbox}&layer=mapnik&marker={lat},{lng}"></iframe>
<p>{escape(report.address or '')}<br>{lat:.6f}, {lng:.6f} ·
<a href="https://www.google.com/maps?q={lat},{lng}">Abrir en mapas</a></p></div>
<div class="card"><table>{table}</table></div>
</main></body></html>"""
