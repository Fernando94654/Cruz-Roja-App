# Enlace Vital — Backend

FastAPI + SQLAlchemy + Alembic on PostgreSQL 17 with PostGIS (Docker).

## Setup

```bash
# from the repo root
cp .env.example .env            # set a password and generate MEDICAL_DATA_KEY
docker compose up -d

cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
alembic upgrade head
python scripts/seed.py          # demo data (wipes existing data)
uvicorn app.main:app --reload
```

- Health check: http://127.0.0.1:8000/health
- Interactive docs: http://127.0.0.1:8000/docs
- Database shell: `docker compose exec db psql -U enlace_vital -d enlace_vital`

**Physical iPhone:** the simulator reaches `127.0.0.1`, a device doesn't. Run `uvicorn app.main:app --host 0.0.0.0` and set `APIConfig.baseURL` in the app to your Mac's LAN IP.

## Tests

```bash
# Explicit, separate LOCAL database; credentials here are for your local test container only.
TEST_DATABASE_URL=postgresql+psycopg://USER:PASSWORD@127.0.0.1:5432/enlace_vital_test .venv/bin/pytest
```

Tests require `TEST_DATABASE_URL`: a loopback PostgreSQL host, a database name ending in `_test`, and no query overrides. They never derive a target from `.env` or the shared Supabase URL. The fixture refuses to overwrite an existing database, creates its own database, runs the local migrations, rolls back each test, and drops only the database it created. The database role needs local `CREATEDB` privileges.

From the repository root, run the Swift behavior checks with `bash tests/swift/run.sh` (Xcode command-line tools required).

## Curated YouTube lessons

`GET /lessons` returns the database records ordered by `position`, then `id`, with nullable `guide_id`, `description`, `video_url`, `publisher`, and `duration_seconds`, plus ordered `steps`. Unknown UUIDs get `guide_id: null`. An empty catalog returns `[]`; database failures return a generic 503. The app decodes the UUID and lesson content directly, without generating a replacement or falling back to sample lessons. The emergency assistant's guide text remains local for this version.

The four reviewed UUIDs and expected original values are in `app/lesson_catalog.py`. To update only those records:

```bash
# From backend, using the DATABASE_URL configured for the app:
.venv/bin/alembic upgrade 0005                           # add publisher and ordered steps after revision 0004
.venv/bin/python -m scripts.update_lesson_videos          # validate, then roll back
.venv/bin/python -m scripts.update_lesson_videos --apply  # commit the scoped update
```

Migration `0005` adds a nullable publisher and an ordered PostgreSQL text array for steps. The two earlier migration files restored in this checkout are copied unchanged from `origin/main`. The updater locks the four records in UUID order and checks every previous value before changing any record. A missing record or unexpected edit aborts the transaction. Already-updated records are skipped, so a second run updates zero rows. IDs and positions are preserved; unverified sample durations are cleared. New lessons can use any publisher and ordered step list; these values are served from the database.

**Do not run `scripts/seed.py` against shared Supabase:** it truncates shared tables. Before upgrading an existing database, check its Alembic revision and apply only pending migrations. The Supabase database was at `0004` before this change, so only `0005` was applied there.

The app loads YouTube's embed URL directly in `WKWebView`, passing its installed bundle identifier in the HTTPS `Referer` header as [YouTube requires](https://developers.google.com/youtube/terms/required-minimum-functionality). It uses YouTube controls, inline playback, and no autoplay. WebKit's native playback-state query is checked while the lesson is visible so speech stops when a video begins. A validated external YouTube link remains available if embedding fails. Leaving the lesson unloads the player and stops speech; backgrounding pauses playback. Emergency video loading never blocks the existing text/voice guidance.

## Structure

```
app/
  main.py       FastAPI app and routers
  db.py         Engine, session and declarative base
  deps.py       Per-request database session
  crypto.py     Encryption of medical data (Fernet, MEDICAL_DATA_KEY)
  models/       Tables (SQLAlchemy), one module per feature
  schemas/      Request/response JSON and validation (Pydantic)
  routers/      Endpoints, one module per feature
alembic/        Migrations, the only source of the schema
scripts/seed.py Demo data
tests/
```

### Adding a feature

1. Models in `app/models/<feature>.py`, exported from `app/models/__init__.py`.
2. `alembic revision --autogenerate -m "description"`, review the file, `alembic upgrade head`.
3. Schemas in `app/schemas/<feature>.py` and endpoints in `app/routers/<feature>.py`.
4. `app.include_router(...)` in `app/main.py`.
5. Tests in `tests/test_<feature>.py`.

## Endpoints

| Method | Path | Description | Responses |
|---|---|---|---|
| GET | `/users/{user_id}/medical-profile` | Returns the medical profile | 200, 404 |
| PUT | `/users/{user_id}/medical-profile` | Creates or replaces the whole profile | 200, 404, 422 |
| GET | `/lessons` | Ordered lessons with stable UUID and optional emergency guide ID | 200, 503 |

```json
{
  "user_id": "00000000-0000-4000-8000-000000000001",
  "full_name": "María López",
  "date_of_birth": "1958-03-14",
  "blood_type": "O+",
  "allergies": ["Penicilina"],
  "conditions": ["Asma"],
  "medications": ["Salbutamol"],
  "contacts": [{ "name": "Ana López", "relationship": "Hija", "phone": "8112345678" }],
  "updated_at": "2026-10-21T18:14:07Z"
}
```

Validation: `full_name` required; `blood_type` is one of `A+ A- B+ B- AB+ AB- O+ O- unknown`; `date_of_birth` can't be in the future; phones must have 10 digits (only digits are stored); at most 20 items per list and 5 contacts; lists drop blanks and duplicates.

Allergies, conditions and medications are stored encrypted. The demo user id matches `APIConfig.demoUserID` in the iOS app.
