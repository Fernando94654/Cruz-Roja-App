"""emergency report sharing

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-21 14:39:36.104874
"""
from alembic import op
import sqlalchemy as sa


revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('emergency_reports', sa.Column('medical_summary', sa.Text(), nullable=True))
    op.add_column('emergency_reports', sa.Column('share_token', sa.String(length=32), nullable=True))
    op.create_unique_constraint(op.f('uq_emergency_reports_share_token'), 'emergency_reports', ['share_token'])


def downgrade():
    op.drop_constraint(op.f('uq_emergency_reports_share_token'), 'emergency_reports', type_='unique')
    op.drop_column('emergency_reports', 'share_token')
    op.drop_column('emergency_reports', 'medical_summary')
