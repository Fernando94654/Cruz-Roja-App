"""Punto de entrada del API de Enlace Vital (Cruz Roja).

Para agregar un módulo nuevo:
  1. Crea sus tablas en app/models/ y regístralas en app/models/__init__.py
  2. Crea sus esquemas en app/schemas/ y sus endpoints en app/routers/
  3. Agrega su router abajo con app.include_router(...)
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import models  # noqa: F401  (registra las tablas)
from app.database import Base, engine
from app.routers import perfiles


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Crea las tablas que falten al iniciar. Suficiente para el prototipo;
    # más adelante se puede cambiar por migraciones con Alembic.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Enlace Vital API", version="0.1.0", lifespan=lifespan)

app.include_router(perfiles.router)


@app.get("/salud", tags=["General"])
def salud() -> dict[str, str]:
    """Para revisar rápido que el API está arriba."""
    return {"estado": "ok"}
