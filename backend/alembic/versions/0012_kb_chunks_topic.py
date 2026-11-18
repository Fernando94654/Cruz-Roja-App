"""kb_chunks topic

Revision ID: 0012
Revises: 0011
Create Date: 2026-11-18 12:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0012'
down_revision = '0011'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    op.add_column('kb_chunks', sa.Column('topic', sa.String(length=120), nullable=True))
    # Old ids end with the part name, so the topic is the id without its last part
    op.execute("UPDATE kb_chunks SET topic = regexp_replace(id, '-[a-z0-9]+$', '')")
    op.alter_column('kb_chunks', 'topic', nullable=False)
    op.create_check_constraint(op.f('ck_kb_chunks_topic_slug'), 'kb_chunks', "topic ~ '^[a-z0-9]+(-[a-z0-9]+)*$'")
    op.create_index(op.f('ix_kb_chunks_topic'), 'kb_chunks', ['topic'])


def downgrade():
    op.drop_index(op.f('ix_kb_chunks_topic'), table_name='kb_chunks')
    op.drop_column('kb_chunks', 'topic')
