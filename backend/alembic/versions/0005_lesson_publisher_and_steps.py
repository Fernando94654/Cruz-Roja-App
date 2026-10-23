"""lesson_publisher_and_steps

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-22 21:57:46.052397
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY


revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    op.add_column('lessons', sa.Column('publisher', sa.Text(), nullable=True))
    op.add_column('lessons', sa.Column('steps', ARRAY(sa.Text()), server_default=sa.text("'{}'::text[]"), nullable=False))


def downgrade():
    op.drop_column('lessons', 'steps')
    op.drop_column('lessons', 'publisher')
