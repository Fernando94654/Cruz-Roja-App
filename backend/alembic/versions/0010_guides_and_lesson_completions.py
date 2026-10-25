"""guides and lesson completions

Moves the emergency guides from the app into the database, makes
lessons.guide_id a foreign key to them, and stores which lessons each
user has completed.

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-23 12:00:00
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY, JSONB


revision = '0010'
down_revision = '0009'
branch_labels = None
depends_on = None


# Same content as FirstAidGuide.bundled in the app, which stays as the offline fallback
GUIDES = [
    {
        'id': 'cardiac_arrest', 'title': 'Paro cardiaco', 'icon': 'heart.slash.fill', 'manual_page': 34, 'position': 0,
        'keywords': ['no respira', 'no responde', 'infarto', 'corazón', 'corazon', 'paro', 'rcp', 'inconsciente'],
        'steps': [
            {'title': 'Revisa la escena', 'instruction': 'Asegúrate de que el lugar sea seguro para ti y para la persona.', 'icon': 'eye.fill'},
            {'title': 'Revisa si responde', 'instruction': 'Toca sus hombros y pregunta en voz alta si está bien. Observa si respira durante diez segundos.', 'icon': 'hand.tap.fill', 'seconds': 10},
            {'title': 'Coloca tus manos', 'instruction': 'Pon el talón de una mano en el centro del pecho y la otra encima, con los dedos entrelazados.', 'icon': 'hands.clap.fill'},
            {'title': 'Compresiones', 'instruction': 'Presiona fuerte y rápido, unos cinco centímetros, siguiendo el ritmo. Haz treinta compresiones.', 'icon': 'waveform.path.ecg', 'seconds': 18, 'rate': 110},
            {'title': 'No te detengas', 'instruction': 'Si no sabes dar respiraciones de rescate, sigue solo con compresiones hasta que llegue la ambulancia.', 'icon': 'arrow.clockwise.heart.fill', 'rate': 110},
        ],
    },
    {
        'id': 'choking', 'title': 'Atragantamiento', 'icon': 'lungs.fill', 'manual_page': 41, 'position': 1,
        'keywords': ['atragant', 'ahog', 'no puede hablar', 'trag', 'comida', 'garganta'],
        'steps': [
            {'title': 'Pregunta', 'instruction': 'Pregunta si se está atragantando. Si puede toser con fuerza, anímalo a seguir tosiendo.', 'icon': 'questionmark.bubble.fill'},
            {'title': 'Golpes en la espalda', 'instruction': 'Inclínalo hacia adelante y da cinco golpes firmes entre los omóplatos con el talón de la mano.', 'icon': 'hand.raised.fill'},
            {'title': 'Compresiones abdominales', 'instruction': 'Colócate detrás, pon tu puño sobre el ombligo y empuja hacia adentro y hacia arriba cinco veces.', 'icon': 'figure.stand'},
            {'title': 'Repite', 'instruction': 'Alterna cinco golpes y cinco compresiones hasta que el objeto salga o la persona pierda el conocimiento.', 'icon': 'repeat'},
        ],
    },
    {
        'id': 'bleeding', 'title': 'Hemorragia', 'icon': 'drop.fill', 'manual_page': 52, 'position': 2,
        'keywords': ['sangr', 'herida', 'cortad', 'corté', 'corte', 'hemorragia'],
        'steps': [
            {'title': 'Protégete', 'instruction': 'Protege tus manos con guantes o una bolsa de plástico.', 'icon': 'hand.raised.square.fill'},
            {'title': 'Presión directa', 'instruction': 'Presiona con firmeza sobre la herida con una tela limpia. No la retires.', 'icon': 'hand.point.down.fill', 'seconds': 60},
            {'title': 'Agrega más tela', 'instruction': 'Si la tela se empapa, pon otra encima y sigue presionando.', 'icon': 'square.stack.fill'},
            {'title': 'Mantén el calor', 'instruction': 'Mantén a la persona acostada y abrigada hasta que llegue la ambulancia.', 'icon': 'thermometer.medium'},
        ],
    },
    {
        'id': 'burn', 'title': 'Quemadura', 'icon': 'flame.fill', 'manual_page': 60, 'position': 3,
        'keywords': ['quem', 'fuego', 'aceite', 'agua caliente', 'ampolla'],
        'steps': [
            {'title': 'Aleja la fuente', 'instruction': 'Detén la quemadura alejando a la persona de la fuente de calor.', 'icon': 'xmark.octagon.fill'},
            {'title': 'Enfría con agua', 'instruction': 'Enfría la zona con agua corriente fría, no helada, durante al menos diez minutos.', 'icon': 'drop.triangle.fill', 'seconds': 600},
            {'title': 'Retira objetos', 'instruction': 'Quita anillos o ropa cerca de la quemadura, solo si no está pegada a la piel.', 'icon': 'circle.dashed'},
            {'title': 'Cubre', 'instruction': 'Cubre con plástico limpio o un apósito que no se pegue. No pongas cremas ni hielo.', 'icon': 'bandage.fill'},
        ],
    },
    {
        'id': 'seizure', 'title': 'Convulsión', 'icon': 'bolt.heart.fill', 'manual_page': 73, 'position': 4,
        'keywords': ['convuls', 'ataque', 'epilep', 'temblor', 'sacud'],
        'steps': [
            {'title': 'Despeja el área', 'instruction': 'Retira objetos cercanos con los que pueda golpearse.', 'icon': 'square.dashed'},
            {'title': 'Protege la cabeza', 'instruction': 'Pon algo suave bajo su cabeza. No lo sujetes ni pongas nada en su boca.', 'icon': 'person.crop.circle.badge.exclamationmark'},
            {'title': 'Mide el tiempo', 'instruction': 'Toma el tiempo de la convulsión. Si dura más de cinco minutos, avisa a la ambulancia.', 'icon': 'stopwatch.fill', 'seconds': 300},
            {'title': 'Ponlo de lado', 'instruction': 'Cuando termine, colócalo de lado y quédate con él hasta que despierte por completo.', 'icon': 'bed.double.fill'},
        ],
    },
    {
        'id': 'fainting', 'title': 'Desmayo', 'icon': 'figure.fall', 'manual_page': 78, 'position': 5,
        'keywords': ['desmay', 'mare', 'se cayó', 'perdió el conocimiento'],
        'steps': [
            {'title': 'Acuéstalo', 'instruction': 'Recuesta a la persona boca arriba en un lugar seguro.', 'icon': 'bed.double.fill'},
            {'title': 'Eleva las piernas', 'instruction': 'Levanta sus piernas unos treinta centímetros para ayudar a la circulación.', 'icon': 'arrow.up.circle.fill'},
            {'title': 'Afloja la ropa', 'instruction': 'Afloja cinturones, corbatas o ropa ajustada.', 'icon': 'tshirt.fill'},
            {'title': 'Vigila la respiración', 'instruction': 'Si no despierta en un minuto o deja de respirar, prepárate para dar RCP.', 'icon': 'lungs.fill', 'seconds': 60},
        ],
    },
]


def upgrade():
    op.execute("SET LOCAL lock_timeout = '5s'")
    guides = op.create_table('guides',
    sa.Column('id', sa.String(length=80), nullable=False),
    sa.Column('title', sa.String(length=120), nullable=False),
    sa.Column('icon', sa.String(length=80), nullable=False),
    sa.Column('keywords', ARRAY(sa.Text()), server_default=sa.text("'{}'::text[]"), nullable=False),
    sa.Column('manual_page', sa.Integer(), nullable=True),
    sa.Column('position', sa.Integer(), server_default='0', nullable=False),
    sa.Column('steps', JSONB(), server_default=sa.text("'[]'::jsonb"), nullable=False),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_guides'))
    )
    op.bulk_insert(guides, GUIDES)

    # Fails, and rolls back, if a lesson points to a guide that doesn't exist: fix the data instead of losing it
    op.create_foreign_key(op.f('fk_lessons_guide_id_guides'), 'lessons', 'guides', ['guide_id'], ['id'],
                          onupdate='CASCADE', ondelete='SET NULL')

    op.create_table('lesson_completions',
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('lesson_id', sa.Uuid(), nullable=False),
    sa.Column('completed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_lesson_completions_user_id_users'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['lesson_id'], ['lessons.id'], name=op.f('fk_lesson_completions_lesson_id_lessons'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_id', 'lesson_id', name=op.f('pk_lesson_completions'))
    )

    # Same rule as 0003: no access through Supabase's Data API; the backend connects as the owner
    op.execute('ALTER TABLE guides ENABLE ROW LEVEL SECURITY')
    op.execute('ALTER TABLE lesson_completions ENABLE ROW LEVEL SECURITY')


def downgrade():
    op.drop_table('lesson_completions')
    op.drop_constraint(op.f('fk_lessons_guide_id_guides'), 'lessons', type_='foreignkey')
    op.drop_table('guides')
