"""dependent profiles

Medical profiles for people the user looks after who don't use the app
(parents, children), each with its own emergency contacts.

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-22 21:40:12
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None

# The blood_type enum already exists (0001); reuse it instead of creating it again
blood_type = postgresql.ENUM('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', name='blood_type', create_type=False)


def upgrade():
    op.create_table('dependent_profiles',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('owner_id', sa.Uuid(), nullable=False),
    sa.Column('relationship', sa.String(length=60), nullable=False),
    sa.Column('full_name', sa.String(length=120), nullable=False),
    sa.Column('date_of_birth', sa.Date(), nullable=True),
    sa.Column('blood_type', blood_type, nullable=True),
    sa.Column('allergies', sa.LargeBinary(), nullable=True),
    sa.Column('conditions', sa.LargeBinary(), nullable=True),
    sa.Column('medications', sa.LargeBinary(), nullable=True),
    sa.Column('qr_token', sa.String(length=64), server_default=sa.text("encode(gen_random_bytes(24), 'hex')"), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['owner_id'], ['users.id'], name=op.f('fk_dependent_profiles_owner_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_dependent_profiles')),
    sa.UniqueConstraint('qr_token', name=op.f('uq_dependent_profiles_qr_token'))
    )
    op.create_index(op.f('ix_dependent_profiles_owner_id'), 'dependent_profiles', ['owner_id'], unique=False)
    op.create_table('dependent_contacts',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('dependent_id', sa.Uuid(), nullable=False),
    sa.Column('name', sa.String(length=120), nullable=False),
    sa.Column('relationship', sa.String(length=60), nullable=True),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.Column('position', sa.Integer(), server_default='0', nullable=False),
    sa.ForeignKeyConstraint(['dependent_id'], ['dependent_profiles.id'], name=op.f('fk_dependent_contacts_dependent_id_dependent_profiles'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_dependent_contacts'))
    )
    op.create_index(op.f('ix_dependent_contacts_dependent_id'), 'dependent_contacts', ['dependent_id'], unique=False)

    # Same rule as 0003: no access through Supabase's Data API; the backend connects as the owner
    op.execute('ALTER TABLE dependent_profiles ENABLE ROW LEVEL SECURITY')
    op.execute('ALTER TABLE dependent_contacts ENABLE ROW LEVEL SECURITY')


def downgrade():
    op.drop_index(op.f('ix_dependent_contacts_dependent_id'), table_name='dependent_contacts')
    op.drop_table('dependent_contacts')
    op.drop_index(op.f('ix_dependent_profiles_owner_id'), table_name='dependent_profiles')
    op.drop_table('dependent_profiles')
