import uuid

import pytest
from sqlalchemy import select

from app.lesson_catalog import CATALOG
from app.models.learning import Lesson
from scripts.update_lesson_videos import LessonConflict, update_lessons


def insert_originals(db):
    db.add_all(Lesson(id=c.id, **c.previous_values) for c in CATALOG)
    db.flush()


def snapshot(db):
    return [(r.id, r.title, r.description, r.video_url, r.duration_seconds, r.position, r.publisher, r.steps)
            for r in db.scalars(select(Lesson).order_by(Lesson.id))]


def test_update_is_repeatable_and_preserves_other_rows_and_ids(db):
    insert_originals(db)
    unrelated = Lesson(id=uuid.uuid4(), title="Otro", description="Conservar", position=9, duration_seconds=12)
    db.add(unrelated)
    db.flush()
    before_ids = [(r.id, r.position) for r in db.scalars(select(Lesson).order_by(Lesson.id))]
    assert update_lessons(db) == 4
    after = snapshot(db)
    assert update_lessons(db) == 0
    assert snapshot(db) == after
    assert [(r.id, r.position) for r in db.scalars(select(Lesson).order_by(Lesson.id))] == before_ids
    assert (unrelated.title, unrelated.description, unrelated.duration_seconds, unrelated.video_url) == ("Otro", "Conservar", 12, None)
    for item in CATALOG:
        row = db.get(Lesson, item.id)
        assert {key: getattr(row, key) for key in item.values} == item.values


@pytest.mark.parametrize("field,value", [("title", "Edición concurrente"), ("position", 20), ("video_url", "https://example.com"), ("duration_seconds", 42), ("publisher", "Otro editor"), ("steps", ["Edición nueva"])])
def test_conflicts_leave_every_row_untouched(db, field, value):
    insert_originals(db)
    setattr(db.get(Lesson, CATALOG[-1].id), field, value)
    db.flush()
    before = snapshot(db)
    with pytest.raises(LessonConflict):
        update_lessons(db)
    assert snapshot(db) == before


def test_missing_row_aborts_without_partial_updates(db):
    insert_originals(db)
    db.delete(db.get(Lesson, CATALOG[-1].id))
    db.flush()
    before = snapshot(db)
    with pytest.raises(LessonConflict):
        update_lessons(db)
    assert snapshot(db) == before


def test_mixed_already_updated_and_original_records(db):
    insert_originals(db)
    row = db.get(Lesson, CATALOG[0].id)
    for key, value in CATALOG[0].values.items():
        setattr(row, key, value)
    db.flush()
    assert update_lessons(db) == 3


def test_metadata_backfill_for_video_only_records_is_repeatable(db):
    db.add_all(Lesson(id=c.id, **c.previous_video_values) for c in CATALOG)
    db.flush()
    assert update_lessons(db) == 4
    assert update_lessons(db) == 0
    for item in CATALOG:
        row = db.get(Lesson, item.id)
        assert row.publisher == item.publisher and row.steps == list(item.steps)
