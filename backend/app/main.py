from fastapi import FastAPI

from app.routers import lessons, medical_profiles
from app.routers import emergency_reports, medical_profiles

app = FastAPI(title="Enlace Vital API", version="0.1.0")

app.include_router(medical_profiles.router)
app.include_router(lessons.router)
app.include_router(emergency_reports.router)


@app.get("/health", tags=["General"])
def health() -> dict[str, str]:
    return {"status": "ok"}
