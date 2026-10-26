"""community report flags

Lets users mark a neighbor report as false, once per user per report,
same shape as community_report_confirmations.

Revision ID: 0009
Revises: 0008 
Create Date: 2026-10-23 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0009'
down_revision = '0008'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('community_report_flags',
    sa.Column('report_id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['report_id'], ['community_reports.id'], name=op.f('fk_community_report_flags_report_id_community_reports'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_community_report_flags_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('report_id', 'user_id', name=op.f('pk_community_report_flags'))
    )

    # Same rule as 0003: no access through Supabase's Data API; the backend connects as the owner
    op.execute('ALTER TABLE community_report_flags ENABLE ROW LEVEL SECURITY')


def downgrade():
    op.drop_table('community_report_flags')
