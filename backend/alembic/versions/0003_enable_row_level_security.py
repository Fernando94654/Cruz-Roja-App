"""enable row level security

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-22 12:00:00
"""
from alembic import op

revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None

# Every table we own in public; Supabase exposes public through its Data API with the publishable key
OWN_TABLES = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tableowner = current_user"


def upgrade():
    # RLS without policies blocks the Data API; the backend connects as the owner and isn't affected
    op.execute(f"""
        DO $$
        DECLARE t text;
        BEGIN
            FOR t IN {OWN_TABLES} LOOP
                EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
            END LOOP;
        END $$;
    """)


def downgrade():
    op.execute(f"""
        DO $$
        DECLARE t text;
        BEGIN
            FOR t IN {OWN_TABLES} LOOP
                EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', t);
            END LOOP;
        END $$;
    """)
