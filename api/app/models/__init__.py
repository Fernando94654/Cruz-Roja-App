"""Tablas de la base de datos.

Cada módulo del equipo agrega aquí sus modelos para que se creen al iniciar.
"""

from app.models.perfil_medico import CondicionMedica, ContactoEmergencia, PerfilMedico
from app.models.usuario import Usuario

__all__ = ["Usuario", "PerfilMedico", "CondicionMedica", "ContactoEmergencia"]
