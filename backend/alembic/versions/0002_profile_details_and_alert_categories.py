"""medical profile details and alert categories

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-21 13:40:51.964787
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None

NEW_REPORT_TYPES = ['blocked_street', 'power_outage', 'fire']


def upgrade():
    op.add_column('emergency_contacts', sa.Column('position', sa.Integer(), server_default='0', nullable=False))
    op.add_column('medical_profiles', sa.Column('full_name', sa.String(length=120), server_default='', nullable=False))
    op.add_column('medical_profiles', sa.Column('date_of_birth', sa.Date(), nullable=True))
    op.add_column('official_alerts', sa.Column('area_name', sa.String(length=120), nullable=True))

    for value in NEW_REPORT_TYPES:
        op.execute(f"ALTER TYPE community_report_type ADD VALUE IF NOT EXISTS '{value}'")


def downgrade():
    # Postgres can't drop enum values; the extra community_report_type values stay
    op.drop_column('official_alerts', 'area_name')
    op.drop_column('medical_profiles', 'date_of_birth')
    op.drop_column('medical_profiles', 'full_name')
    op.drop_column('emergency_contacts', 'position')
