"""Tabla de usuarios (mínima).

La comparten todos los módulos. Quien haga el inicio de sesión puede
agregarle los campos que necesite (contraseña, Apple ID, etc.).
"""

from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Usuario(Base):
    __tablename__ = "usuario"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(120))
    correo: Mapped[str] = mapped_column(String(160), unique=True)
    creado: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    perfil: Mapped["PerfilMedico | None"] = relationship(  # noqa: F821
        back_populates="usuario", uselist=False, cascade="all, delete-orphan"
    )
