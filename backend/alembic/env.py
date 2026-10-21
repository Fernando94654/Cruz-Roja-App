from logging.config import fileConfig

from alembic import context
from geoalchemy2 import alembic_helpers

import app.models  # noqa: F401
from app.db import Base, engine

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)


def include_object(obj, name, type_, reflected, compare_to):
    # Skip tables we don't model (PostGIS, tiger, topology)
    if type_ == "table" and reflected and compare_to is None:
        return False
    return alembic_helpers.include_object(obj, name, type_, reflected, compare_to)


with engine.connect() as connection:
    context.configure(
        connection=connection,
        target_metadata=Base.metadata,
        include_object=include_object,
        process_revision_directives=alembic_helpers.writer,
        render_item=alembic_helpers.render_item,
    )
    with context.begin_transaction():
        context.run_migrations()
