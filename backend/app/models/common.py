import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import DateTime, func, text
from sqlalchemy.orm import Mapped, mapped_column


def point():
    return Geography(geometry_type="POINT", srid=4326, spatial_index=False)


def uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(primary_key=True, server_default=text("gen_random_uuid()"))


def timestamp_now() -> Mapped[datetime]:
    return mapped_column(DateTime(timezone=True), server_default=func.now())
