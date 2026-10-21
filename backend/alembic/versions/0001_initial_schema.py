"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-10-21 12:27:01.996689
"""
from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects import postgresql

revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


ENUMS = ['severity', 'user_role', 'community_report_type', 'platform', 'reporting_for', 'report_status', 'blood_type', 'invitation_status', 'circle_role', 'wellbeing_status']


def upgrade():
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("CREATE EXTENSION IF NOT EXISTS citext")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.create_table('lessons',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('title', sa.String(length=120), nullable=False),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('duration_seconds', sa.Integer(), nullable=True),
    sa.Column('video_url', sa.String(length=500), nullable=True),
    sa.Column('position', sa.Integer(), server_default='0', nullable=False),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_lessons'))
    )
    op.create_geospatial_table('official_alerts',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('source', sa.String(length=80), nullable=False),
    sa.Column('type', sa.String(length=60), nullable=False),
    sa.Column('title', sa.String(length=160), nullable=False),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('severity', sa.Enum('info', 'moderate', 'high', 'extreme', name='severity'), nullable=False),
    sa.Column('area', Geography(geometry_type='MULTIPOLYGON', srid=4326, dimension=2, spatial_index=False, from_text='ST_GeogFromText', name='geography', nullable=False), nullable=False),
    sa.Column('starts_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_official_alerts'))
    )
    op.create_geospatial_index('ix_official_alerts_area', 'official_alerts', ['area'], unique=False, postgresql_using='gist', postgresql_ops={})
    op.create_index(op.f('ix_official_alerts_expires_at'), 'official_alerts', ['expires_at'], unique=False)
    op.create_table('users',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('email', postgresql.CITEXT(), nullable=False),
    sa.Column('password_hash', sa.String(length=255), nullable=False),
    sa.Column('name', sa.String(length=120), nullable=False),
    sa.Column('phone', sa.String(length=20), nullable=True),
    sa.Column('role', sa.Enum('user', 'paramedic', 'operator', 'admin', name='user_role'), server_default='user', nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_users')),
    sa.UniqueConstraint('email', name=op.f('uq_users_email'))
    )
    op.create_table('circles',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('name', sa.String(length=80), nullable=False),
    sa.Column('created_by', sa.Uuid(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['created_by'], ['users.id'], name=op.f('fk_circles_created_by_users'), ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_circles'))
    )
    op.create_geospatial_table('community_reports',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=True),
    sa.Column('type', sa.Enum('flood', 'traffic_light', 'accident', 'fallen_tree', 'other', name='community_report_type'), nullable=False),
    sa.Column('details', sa.Text(), nullable=True),
    sa.Column('location', Geography(geometry_type='POINT', srid=4326, dimension=2, spatial_index=False, from_text='ST_GeogFromText', name='geography', nullable=False), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_community_reports_user_id_users'), ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_community_reports'))
    )
    op.create_index(op.f('ix_community_reports_expires_at'), 'community_reports', ['expires_at'], unique=False)
    op.create_geospatial_index('ix_community_reports_location', 'community_reports', ['location'], unique=False, postgresql_using='gist', postgresql_ops={})
    op.create_table('devices',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('apns_token', sa.String(length=255), nullable=False),
    sa.Column('platform', sa.Enum('ios', 'watchos', name='platform'), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_devices_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_devices')),
    sa.UniqueConstraint('apns_token', name=op.f('uq_devices_apns_token'))
    )
    op.create_index(op.f('ix_devices_user_id'), 'devices', ['user_id'], unique=False)
    op.create_table('emergency_contacts',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('name', sa.String(length=120), nullable=False),
    sa.Column('relationship', sa.String(length=60), nullable=True),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_emergency_contacts_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_emergency_contacts'))
    )
    op.create_index(op.f('ix_emergency_contacts_user_id'), 'emergency_contacts', ['user_id'], unique=False)
    op.create_geospatial_table('emergency_reports',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=True),
    sa.Column('reporting_for', sa.Enum('self', 'other', name='reporting_for'), nullable=False),
    sa.Column('patient_name', sa.String(length=120), nullable=True),
    sa.Column('reason', sa.String(length=255), nullable=True),
    sa.Column('injured_count', sa.Integer(), server_default='1', nullable=False),
    sa.Column('injury', sa.String(length=255), nullable=True),
    sa.Column('place', sa.String(length=255), nullable=True),
    sa.Column('reference', sa.String(length=255), nullable=True),
    sa.Column('mental_state', sa.String(length=60), nullable=True),
    sa.Column('breathing', sa.String(length=60), nullable=True),
    sa.Column('skin', sa.String(length=60), nullable=True),
    sa.Column('transcript', sa.Text(), nullable=True),
    sa.Column('ai_summary', sa.Text(), nullable=True),
    sa.Column('location', Geography(geometry_type='POINT', srid=4326, dimension=2, spatial_index=False, from_text='ST_GeogFromText', name='geography'), nullable=True),
    sa.Column('address', sa.String(length=255), nullable=True),
    sa.Column('status', sa.Enum('draft', 'sent', 'received', 'attended', 'cancelled', name='report_status'), server_default='draft', nullable=False),
    sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('injured_count >= 0', name=op.f('ck_emergency_reports_injured_count_non_negative')),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_emergency_reports_user_id_users'), ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_emergency_reports'))
    )
    op.create_geospatial_index('ix_emergency_reports_location', 'emergency_reports', ['location'], unique=False, postgresql_using='gist', postgresql_ops={})
    op.create_index(op.f('ix_emergency_reports_user_id'), 'emergency_reports', ['user_id'], unique=False)
    op.create_table('medical_profiles',
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('blood_type', sa.Enum('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', name='blood_type'), nullable=True),
    sa.Column('allergies', sa.LargeBinary(), nullable=True),
    sa.Column('conditions', sa.LargeBinary(), nullable=True),
    sa.Column('medications', sa.LargeBinary(), nullable=True),
    sa.Column('qr_token', sa.String(length=64), server_default=sa.text("encode(gen_random_bytes(24), 'hex')"), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_medical_profiles_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', name=op.f('pk_medical_profiles')),
    sa.UniqueConstraint('qr_token', name=op.f('uq_medical_profiles_qr_token'))
    )
    op.create_geospatial_table('user_locations',
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('location', Geography(geometry_type='POINT', srid=4326, dimension=2, spatial_index=False, from_text='ST_GeogFromText', name='geography', nullable=False), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_user_locations_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', name=op.f('pk_user_locations'))
    )
    op.create_table('circle_invitations',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('circle_id', sa.Uuid(), nullable=False),
    sa.Column('invited_by', sa.Uuid(), nullable=True),
    sa.Column('contact', sa.String(length=255), nullable=False),
    sa.Column('token', sa.String(length=64), nullable=False),
    sa.Column('status', sa.Enum('pending', 'accepted', 'declined', 'expired', name='invitation_status'), server_default='pending', nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['circle_id'], ['circles.id'], name=op.f('fk_circle_invitations_circle_id_circles'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['invited_by'], ['users.id'], name=op.f('fk_circle_invitations_invited_by_users'), ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_circle_invitations')),
    sa.UniqueConstraint('token', name=op.f('uq_circle_invitations_token'))
    )
    op.create_index(op.f('ix_circle_invitations_circle_id'), 'circle_invitations', ['circle_id'], unique=False)
    op.create_table('circle_members',
    sa.Column('circle_id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('role', sa.Enum('admin', 'member', name='circle_role'), server_default='member', nullable=False),
    sa.Column('shares_location', sa.Boolean(), server_default='true', nullable=False),
    sa.Column('joined_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['circle_id'], ['circles.id'], name=op.f('fk_circle_members_circle_id_circles'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_circle_members_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('circle_id', 'user_id', name=op.f('pk_circle_members'))
    )
    op.create_index(op.f('ix_circle_members_user_id'), 'circle_members', ['user_id'], unique=False)
    op.create_table('community_report_confirmations',
    sa.Column('report_id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['report_id'], ['community_reports.id'], name=op.f('fk_community_report_confirmations_report_id_community_reports'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_community_report_confirmations_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('report_id', 'user_id', name=op.f('pk_community_report_confirmations'))
    )
    op.create_table('wellbeing_checks',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('alert_id', sa.Uuid(), nullable=True),
    sa.Column('report_id', sa.Uuid(), nullable=True),
    sa.Column('status', sa.Enum('ok', 'need_help', 'no_response', name='wellbeing_status'), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['alert_id'], ['official_alerts.id'], name=op.f('fk_wellbeing_checks_alert_id_official_alerts'), ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['report_id'], ['emergency_reports.id'], name=op.f('fk_wellbeing_checks_report_id_emergency_reports'), ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_wellbeing_checks_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_wellbeing_checks'))
    )
    op.create_index(op.f('ix_wellbeing_checks_user_id'), 'wellbeing_checks', ['user_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_wellbeing_checks_user_id'), table_name='wellbeing_checks')
    op.drop_table('wellbeing_checks')
    op.drop_table('community_report_confirmations')
    op.drop_index(op.f('ix_circle_members_user_id'), table_name='circle_members')
    op.drop_table('circle_members')
    op.drop_index(op.f('ix_circle_invitations_circle_id'), table_name='circle_invitations')
    op.drop_table('circle_invitations')
    op.drop_geospatial_table('user_locations')
    op.drop_table('medical_profiles')
    op.drop_index(op.f('ix_emergency_reports_user_id'), table_name='emergency_reports')
    op.drop_geospatial_index('ix_emergency_reports_location', table_name='emergency_reports', postgresql_using='gist', column_name='location')
    op.drop_geospatial_table('emergency_reports')
    op.drop_index(op.f('ix_emergency_contacts_user_id'), table_name='emergency_contacts')
    op.drop_table('emergency_contacts')
    op.drop_index(op.f('ix_devices_user_id'), table_name='devices')
    op.drop_table('devices')
    op.drop_geospatial_index('ix_community_reports_location', table_name='community_reports', postgresql_using='gist', column_name='location')
    op.drop_index(op.f('ix_community_reports_expires_at'), table_name='community_reports')
    op.drop_geospatial_table('community_reports')
    op.drop_table('circles')
    op.drop_table('users')
    op.drop_index(op.f('ix_official_alerts_expires_at'), table_name='official_alerts')
    op.drop_geospatial_index('ix_official_alerts_area', table_name='official_alerts', postgresql_using='gist', column_name='area')
    op.drop_geospatial_table('official_alerts')
    op.drop_table('lessons')
    for name in ENUMS:
        op.execute(f"DROP TYPE IF EXISTS {name}")
