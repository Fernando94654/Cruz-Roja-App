"""knowledge base

Revision ID: 0011
Revises: 0010
Create Date: 2026-11-15 12:00:00
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY


revision = '0011'
down_revision = '0010'
branch_labels = None
depends_on = None

MAX_CHUNK_CHARS = 1800


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    op.create_table('kb_chunks',
    sa.Column('id', sa.String(length=120), nullable=False),
    sa.Column('text', sa.Text(), nullable=False),
    sa.Column('embedding', ARRAY(sa.REAL()), nullable=True),
    sa.Column('embedding_model', sa.Text(), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint("id ~ '^[a-z0-9]+(-[a-z0-9]+)*$'", name=op.f('ck_kb_chunks_id_slug')),
    sa.CheckConstraint(f"char_length(btrim(text)) BETWEEN 1 AND {MAX_CHUNK_CHARS}",
                       name=op.f('ck_kb_chunks_text_length')),
    sa.CheckConstraint('(embedding IS NULL) = (embedding_model IS NULL)',
                       name=op.f('ck_kb_chunks_embedding_has_model')),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_kb_chunks'))
    )

    # If the text changes, the old vector is deleted
    op.execute("""
        CREATE FUNCTION kb_chunks_before_update() RETURNS trigger
        LANGUAGE plpgsql SET search_path = '' AS $$
        BEGIN
            NEW.updated_at = now();
            IF NEW.text IS DISTINCT FROM OLD.text AND NEW.embedding IS NOT DISTINCT FROM OLD.embedding THEN
                NEW.embedding = NULL;
                NEW.embedding_model = NULL;
            END IF;
            RETURN NEW;
        END $$
    """)
    op.execute("""
        CREATE TRIGGER kb_chunks_before_update BEFORE UPDATE ON kb_chunks
        FOR EACH ROW EXECUTE FUNCTION kb_chunks_before_update()
    """)

    op.execute('ALTER TABLE kb_chunks ENABLE ROW LEVEL SECURITY')


def downgrade():
    op.drop_table('kb_chunks')
    op.execute('DROP FUNCTION kb_chunks_before_update()')
