"""Configuración del API.

Los valores se leen de variables de entorno (o de un archivo .env).
Así cada integrante puede usar su propia base de datos sin cambiar el código.
"""

import os

from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://cruzroja:cruzroja@localhost:5432/cruzroja",
)
