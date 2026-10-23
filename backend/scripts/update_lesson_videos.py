"""Scoped, repeatable data update. Run from backend: .venv/bin/python -m scripts.update_lesson_videos --apply"""
import argparse

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.lesson_catalog import CATALOG
from app.models.learning import Lesson


class LessonConflict(RuntimeError):
    pass


def update_lessons(db: Session) -> int:
    """Caller owns the transaction. Validate ALL locked rows before changing any."""
    db.execute(text("SET LOCAL lock_timeout = '5s'"))
    rows = {row.id: row for row in db.scalars(
        select(Lesson).where(Lesson.id.in_([item.id for item in CATALOG]))
        .order_by(Lesson.id).with_for_update()
    )}
    pending = []
    for item in CATALOG:
        row = rows.get(item.id)
        if row is None:
            raise LessonConflict(f"Missing lesson {item.id}; no records updated.")
        actual = {key: getattr(row, key) for key in item.values}
        if actual == item.values:
            continue
        if actual not in (item.previous_values, item.previous_video_values):
            raise LessonConflict(f"Lesson {item.id} changed since review; no records updated.")
        pending.append((row, item))
    for row, item in pending:
        for key, value in item.values.items():
            if key != "position":  # position is checked but never rewritten
                setattr(row, key, value)
    db.flush()
    return len(pending)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Commit the four-record update; otherwise validate and roll back.")
    args = parser.parse_args()
    with SessionLocal() as db:
        try:
            count = update_lessons(db)
            if args.apply:
                db.commit()
            else:
                db.rollback()
        except Exception:
            db.rollback()
            raise
    print(f"{count} lessons {'updated' if args.apply else 'validated (dry run, rolled back)' }.")


if __name__ == "__main__":
    main()
