"""Crea el usuario de demostración (id 1) con un perfil de ejemplo.

Uso:  python -m app.seed
Se puede correr varias veces: si el usuario ya existe, no lo duplica.
"""

from datetime import date

from sqlalchemy import text

from app import models  # noqa: F401
from app.database import Base, SessionLocal, engine
from app.models import CondicionMedica, ContactoEmergencia, PerfilMedico, Usuario


def main() -> None:
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if db.get(Usuario, 1):
            print("El usuario de demostración ya existe (id 1).")
            return

        usuario = Usuario(id=1, nombre="Usuario Demo", correo="demo@enlacevital.mx")
        usuario.perfil = PerfilMedico(
            nombre="María López",
            fecha_nacimiento=date(1958, 3, 14),
            tipo_sangre="O+",
            condiciones=[
                CondicionMedica(tipo="alergia", descripcion="Penicilina"),
                CondicionMedica(tipo="padecimiento", descripcion="Asma"),
                CondicionMedica(tipo="medicamento", descripcion="Salbutamol"),
            ],
            contactos=[
                ContactoEmergencia(nombre="Ana López", parentesco="Hija", telefono="8112345678"),
            ],
        )
        db.add(usuario)
        db.commit()

        # Ajusta la secuencia de ids de PostgreSQL porque insertamos el id 1 a mano.
        if engine.dialect.name == "postgresql":
            db.execute(
                text(
                    "SELECT setval(pg_get_serial_sequence('usuario', 'id'), "
                    "(SELECT MAX(id) FROM usuario))"
                )
            )
            db.commit()
        print("Usuario de demostración creado (id 1) con perfil médico de ejemplo.")


if __name__ == "__main__":
    main()
