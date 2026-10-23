"""family circle names, relationships and wellbeing requests

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-22 10:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0007'
down_revision = '0006'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('circle_invitations', sa.Column('name', sa.String(length=120), server_default='', nullable=False))
    op.add_column('circle_invitations', sa.Column('relationship', sa.String(length=40), nullable=True))
    op.add_column('circle_members', sa.Column('relationship', sa.String(length=40), nullable=True))
    op.add_column('wellbeing_checks', sa.Column('requested_by', sa.Uuid(), nullable=True))
    op.add_column('wellbeing_checks', sa.Column('answered_at', sa.DateTime(timezone=True), nullable=True))
    op.create_foreign_key(op.f('fk_wellbeing_checks_requested_by_users'), 'wellbeing_checks', 'users',
                          ['requested_by'], ['id'], ondelete='SET NULL')


def downgrade():
    op.drop_constraint(op.f('fk_wellbeing_checks_requested_by_users'), 'wellbeing_checks', type_='foreignkey')
    op.drop_column('wellbeing_checks', 'answered_at')
    op.drop_column('wellbeing_checks', 'requested_by')
    op.drop_column('circle_members', 'relationship')
    op.drop_column('circle_invitations', 'relationship')
    op.drop_column('circle_invitations', 'name')
