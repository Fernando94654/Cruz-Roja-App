"""Store emergency guide associations on lesson rows.

Revision ID: 0006
Revises: 0005
"""

from alembic import op
import sqlalchemy as sa


revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    op.add_column("lessons", sa.Column("guide_id", sa.String(80), nullable=True))

    # Backfill the four existing Supabase lessons once. Future associations are data edits.
    connection = op.get_bind()
    for lesson_id, guide_id in (
        ("e0509eb5-e732-4a8d-ac14-af41b4b3e3ed", "cardiac_arrest"),
        ("ee8c8787-42da-4aae-8b18-d2a0180622ed", "choking"),
        ("94b0b4d8-dcf4-422a-a304-af86d4918663", "bleeding"),
        ("e2104370-1408-4e6b-ac32-f226b54996ad", "burn"),
    ):
        connection.execute(
            sa.text("UPDATE lessons SET guide_id = :guide_id WHERE id = CAST(:lesson_id AS uuid)"),
            {"lesson_id": lesson_id, "guide_id": guide_id},
        )


def downgrade():
    op.drop_column("lessons", "guide_id")
