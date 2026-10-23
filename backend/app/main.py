from fastapi import FastAPI

from app.routers import auth, emergency_reports, family, lessons, medical_profiles

app = FastAPI(title="Enlace Vital API", version="0.1.0")

app.include_router(auth.router)
app.include_router(medical_profiles.router)
app.include_router(family.router)
app.include_router(lessons.router)
app.include_router(emergency_reports.router)


@app.get("/health", tags=["General"])
def health() -> dict[str, str]:
    return {"status": "ok"}
