"""Tablas del perfil médico.

perfil_medico         1 por usuario: nombre, fecha de nacimiento y tipo de sangre.
condicion_medica      N por perfil: alergias, padecimientos y medicamentos.
contacto_emergencia   N por perfil: nombre, parentesco y teléfono.
"""

from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

TIPOS_CONDICION = ("alergia", "padecimiento", "medicamento")


class PerfilMedico(Base):
    __tablename__ = "perfil_medico"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuario.id", ondelete="CASCADE"), unique=True
    )
    nombre: Mapped[str] = mapped_column(String(120))
    fecha_nacimiento: Mapped[date | None] = mapped_column(Date)
    tipo_sangre: Mapped[str] = mapped_column(String(12), default="desconocido")
    actualizado: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    usuario: Mapped["Usuario"] = relationship(back_populates="perfil")  # noqa: F821
    condiciones: Mapped[list["CondicionMedica"]] = relationship(
        back_populates="perfil", cascade="all, delete-orphan", order_by="CondicionMedica.id"
    )
    contactos: Mapped[list["ContactoEmergencia"]] = relationship(
        back_populates="perfil", cascade="all, delete-orphan", order_by="ContactoEmergencia.id"
    )


class CondicionMedica(Base):
    __tablename__ = "condicion_medica"

    id: Mapped[int] = mapped_column(primary_key=True)
    perfil_id: Mapped[int] = mapped_column(ForeignKey("perfil_medico.id", ondelete="CASCADE"))
    tipo: Mapped[str] = mapped_column(String(20))  # alergia | padecimiento | medicamento
    descripcion: Mapped[str] = mapped_column(String(120))

    perfil: Mapped[PerfilMedico] = relationship(back_populates="condiciones")


class ContactoEmergencia(Base):
    __tablename__ = "contacto_emergencia"

    id: Mapped[int] = mapped_column(primary_key=True)
    perfil_id: Mapped[int] = mapped_column(ForeignKey("perfil_medico.id", ondelete="CASCADE"))
    nombre: Mapped[str] = mapped_column(String(120))
    parentesco: Mapped[str] = mapped_column(String(40))
    telefono: Mapped[str] = mapped_column(String(10))

    perfil: Mapped[PerfilMedico] = relationship(back_populates="contactos")
