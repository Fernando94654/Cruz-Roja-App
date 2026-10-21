from fastapi import FastAPI

from app.routers import medical_profiles

app = FastAPI(title="Enlace Vital API", version="0.1.0")

app.include_router(medical_profiles.router)


@app.get("/health", tags=["General"])
def health() -> dict[str, str]:
    return {"status": "ok"}
