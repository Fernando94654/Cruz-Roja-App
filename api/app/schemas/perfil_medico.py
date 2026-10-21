"""Formato del perfil médico en el JSON del API, con sus validaciones."""

import re
from datetime import date, datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

TipoSangre = Literal["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "desconocido"]

MAX_ELEMENTOS = 20
MAX_CONTACTOS = 5


class ContactoEmergencia(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    nombre: str = Field(min_length=1, max_length=120)
    parentesco: str = Field(min_length=1, max_length=40)
    telefono: str

    @field_validator("nombre", "parentesco")
    @classmethod
    def sin_espacios_extra(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("no puede estar vacío")
        return valor

    @field_validator("telefono")
    @classmethod
    def telefono_10_digitos(cls, valor: str) -> str:
        digitos = re.sub(r"\D", "", valor)
        if len(digitos) != 10:
            raise ValueError("el teléfono debe tener 10 dígitos")
        return digitos


class PerfilMedicoEntrada(BaseModel):
    """Lo que la app envía al guardar (PUT)."""

    nombre: str = Field(min_length=1, max_length=120)
    fecha_nacimiento: date | None = None
    tipo_sangre: TipoSangre = "desconocido"
    alergias: list[str] = Field(default_factory=list, max_length=MAX_ELEMENTOS)
    padecimientos: list[str] = Field(default_factory=list, max_length=MAX_ELEMENTOS)
    medicamentos: list[str] = Field(default_factory=list, max_length=MAX_ELEMENTOS)
    contactos: list[ContactoEmergencia] = Field(default_factory=list, max_length=MAX_CONTACTOS)

    @field_validator("nombre")
    @classmethod
    def nombre_sin_espacios(cls, valor: str) -> str:
        valor = valor.strip()
        if not valor:
            raise ValueError("el nombre es obligatorio")
        return valor

    @field_validator("fecha_nacimiento")
    @classmethod
    def fecha_no_futura(cls, valor: date | None) -> date | None:
        if valor and valor > date.today():
            raise ValueError("la fecha de nacimiento no puede ser futura")
        return valor

    @field_validator("alergias", "padecimientos", "medicamentos")
    @classmethod
    def limpiar_lista(cls, valores: list[str]) -> list[str]:
        """Quita espacios, elementos vacíos y repetidos (sin importar mayúsculas)."""
        limpios: list[str] = []
        vistos: set[str] = set()
        for valor in valores:
            valor = valor.strip()[:120]
            if valor and valor.lower() not in vistos:
                vistos.add(valor.lower())
                limpios.append(valor)
        return limpios


class PerfilMedicoSalida(PerfilMedicoEntrada):
    """Lo que el API regresa (GET y PUT)."""

    usuario_id: int
    actualizado: datetime

    @field_serializer("actualizado")
    def fecha_iso(self, valor: datetime) -> str:
        """ISO 8601 en UTC y sin microsegundos, el formato que iOS lee sin ajustes."""
        if valor.tzinfo is None:
            valor = valor.replace(tzinfo=timezone.utc)
        return valor.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
