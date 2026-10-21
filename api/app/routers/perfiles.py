"""Endpoints del perfil médico.

GET /usuarios/{usuario_id}/perfil   Regresa el perfil (404 si aún no existe).
PUT /usuarios/{usuario_id}/perfil   Crea o reemplaza el perfil completo.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, selectinload

from app.database import get_db
from app.models import CondicionMedica, ContactoEmergencia, PerfilMedico, Usuario
from app.schemas.perfil_medico import PerfilMedicoEntrada, PerfilMedicoSalida

router = APIRouter(prefix="/usuarios", tags=["Perfil médico"])


def a_salida(perfil: PerfilMedico) -> PerfilMedicoSalida:
    """Convierte las tablas al JSON que espera la app."""

    def de_tipo(tipo: str) -> list[str]:
        return [c.descripcion for c in perfil.condiciones if c.tipo == tipo]

    return PerfilMedicoSalida(
        usuario_id=perfil.usuario_id,
        nombre=perfil.nombre,
        fecha_nacimiento=perfil.fecha_nacimiento,
        tipo_sangre=perfil.tipo_sangre,
        alergias=de_tipo("alergia"),
        padecimientos=de_tipo("padecimiento"),
        medicamentos=de_tipo("medicamento"),
        contactos=perfil.contactos,
        actualizado=perfil.actualizado,
    )


def buscar_usuario(db: Session, usuario_id: int) -> Usuario:
    usuario = db.get(Usuario, usuario_id)
    if usuario is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    return usuario


def buscar_perfil(db: Session, usuario_id: int) -> PerfilMedico | None:
    return (
        db.query(PerfilMedico)
        .options(selectinload(PerfilMedico.condiciones), selectinload(PerfilMedico.contactos))
        .filter(PerfilMedico.usuario_id == usuario_id)
        .one_or_none()
    )


@router.get("/{usuario_id}/perfil", response_model=PerfilMedicoSalida)
def obtener_perfil(usuario_id: int, db: Session = Depends(get_db)) -> PerfilMedicoSalida:
    buscar_usuario(db, usuario_id)
    perfil = buscar_perfil(db, usuario_id)
    if perfil is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="El usuario aún no tiene perfil médico")
    return a_salida(perfil)


@router.put("/{usuario_id}/perfil", response_model=PerfilMedicoSalida)
def guardar_perfil(
    usuario_id: int, datos: PerfilMedicoEntrada, db: Session = Depends(get_db)
) -> PerfilMedicoSalida:
    buscar_usuario(db, usuario_id)
    perfil = buscar_perfil(db, usuario_id)
    if perfil is None:
        perfil = PerfilMedico(usuario_id=usuario_id)
        db.add(perfil)

    perfil.nombre = datos.nombre
    perfil.fecha_nacimiento = datos.fecha_nacimiento
    perfil.tipo_sangre = datos.tipo_sangre

    # Las listas se reemplazan completas: es más simple que comparar cambios.
    perfil.condiciones = [
        CondicionMedica(tipo=tipo, descripcion=descripcion)
        for tipo, lista in (
            ("alergia", datos.alergias),
            ("padecimiento", datos.padecimientos),
            ("medicamento", datos.medicamentos),
        )
        for descripcion in lista
    ]
    perfil.contactos = [ContactoEmergencia(**c.model_dump()) for c in datos.contactos]

    db.commit()
    db.refresh(perfil)
    return a_salida(perfil)
