# Enlace Vital — Backend

FastAPI + SQLAlchemy + Alembic on PostgreSQL 17 with PostGIS (Docker).

## Setup

```bash
# from the repo root
cp .env.example .env            # set a password, generate MEDICAL_DATA_KEY and JWT_SECRET
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

## Supabase

The backend uses Supabase only as its Postgres database; the schema still comes from Alembic.

1. In Supabase: **Project → Connect → Session pooler**, copy the connection string.
2. In `.env`, set `DATABASE_URL` to it, changing `postgresql://` to `postgresql+psycopg://` and adding `?sslmode=require`. URL-encode special characters in the password (`@` → `%40`).
3. `alembic upgrade head` creates the extensions, tables and Row Level Security.
4. Optional: `python scripts/seed.py` for demo data (wipes existing data).

Every table has Row Level Security enabled with no policies, so the Data API (publishable key) can't read or write them; the backend connects as the table owner and isn't affected. New tables need `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` in their migration (`tests/test_security.py` fails otherwise).

## Tests

```bash
# Explicit, separate LOCAL database; credentials here are for your local test container only.
TEST_DATABASE_URL=postgresql+psycopg://USER:PASSWORD@127.0.0.1:5432/enlace_vital_test .venv/bin/pytest
```

Tests require `TEST_DATABASE_URL`: a loopback PostgreSQL host, a database name ending in `_test`, and no query overrides. They never derive a target from `.env` or the shared Supabase URL. The fixture refuses to overwrite an existing database, creates its own database, runs the local migrations, rolls back each test, and drops only the database it created. The database role needs local `CREATEDB` privileges.

From the repository root, run the Swift behavior checks with `bash tests/swift/run.sh` (Xcode command-line tools required).

## Curated YouTube lessons

`GET /lessons` returns the database records ordered by `position`, then `id`, with nullable `guide_id`, `description`, `video_url`, `publisher`, and `duration_seconds`, plus ordered `steps`. An empty catalog returns `[]`; database failures return a generic 503. The app decodes the UUID and lesson content directly, without generating a replacement or falling back to sample lessons. The emergency assistant's guide text remains local for this version.

Migration `0005` added the publisher and ordered steps columns. The four YouTube lessons were populated in Supabase before this change. Migration `0006` adds `guide_id` and backfills its four existing rows by UUID; afterward, lesson associations are edited in Supabase like any other lesson field. The API has no hardcoded UUID-to-guide catalog, and the completed one-time lesson updater has been removed.

Migration `0008` adds dependent medical profiles after the family-circle migration. This keeps the merged Alembic history in one sequence.

```bash
# From backend, using the DATABASE_URL configured for the app, after checking its current revision:
.venv/bin/alembic upgrade head
```

New lessons can use any publisher, guide ID, and ordered step list. The development seed no longer clears or inserts lesson samples.

**Do not run `scripts/seed.py` against shared Supabase:** it still truncates shared user and alert tables. Before upgrading an existing database, check its Alembic revision and apply only pending migrations.

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

| POST | `/emergency-reports` | Stores a sent emergency report and returns `{id, share_url}` | 201, 422 |
| GET | `/r/{token}` | Public HTML page for the operator: summary, map and details | 200, 404 |

`share_url` uses `PUBLIC_BASE_URL` from `.env`; set it to an address the operator's phone can reach (e.g. `http://<LAN IP>:8000` and run uvicorn with `--host 0.0.0.0`).

Validation: `full_name` required; `blood_type` is one of `A+ A- B+ B- AB+ AB- O+ O- unknown`; `date_of_birth` can't be in the future; phones must have 10 digits (only digits are stored); at most 20 items per list and 5 contacts; lists drop blanks and duplicates.

### Dependent profiles

Medical profiles of people the user looks after who don't use the app (parents, children). Same fields as the user's own profile plus `relationship`.

| Method | Path | Description | Responses |
|---|---|---|---|
| GET | `/users/{user_id}/dependents` | Lists the user's dependents | 200, 404 |
| POST | `/users/{user_id}/dependents` | Adds a dependent | 201, 404, 409 (more than 10), 422 |
| GET | `/users/{user_id}/dependents/{dependent_id}` | Returns one dependent | 200, 404 |
| PUT | `/users/{user_id}/dependents/{dependent_id}` | Replaces a dependent | 200, 404, 422 |
| DELETE | `/users/{user_id}/dependents/{dependent_id}` | Removes a dependent and its contacts | 204, 404 |

```json
{
  "id": "6f1c…",
  "relationship": "Abuela",
  "full_name": "Rosa Martínez",
  "date_of_birth": "1945-07-02",
  "blood_type": "A+",
  "allergies": ["Sulfas"],
  "conditions": ["Diabetes tipo 2", "Hipertensión"],
  "medications": ["Metformina", "Losartán"],
  "contacts": [{ "name": "Luis Martínez", "relationship": "Hijo", "phone": "8123456789" }],
  "updated_at": "2026-10-22T21:40:12Z"
}
```

A dependent that belongs to another user answers 404.

Allergies, conditions and medications are stored encrypted. The demo user id matches `APIConfig.demoUserID` in the iOS app.

### Sign in

`POST /auth/login` with `{"email", "password"}` returns `access_token`. Send it as `Authorization: Bearer <token>`; the family endpoints take the user from the token, never from the URL. Seed user: `user@example.com` / `demo1234`.

### Family

All return the whole family (`members`, `sent_invitations`, `received_invitations`, `wellbeing_request`, `shares_location`), 401 without a valid token.

| Method | Path | Description |
|---|---|---|
| GET | `/family` | My family |
| POST | `/family/invitations` | Invite `{name, contact, relationship}`, contact is a 10 digit phone or an email (201, 409, 422) |
| DELETE | `/family/invitations/{id}` | Cancel an invitation I sent |
| POST | `/family/invitations/{id}/accept` · `/decline` | Answer an invitation I received |
| POST | `/family/members/{id}/wellbeing-check` | Ask "¿Estás bien?", one pending question per person |
| POST | `/family/wellbeing-answer` | Answer `{status: ok \| need_help}`, reaches everyone who asked |
| DELETE | `/family/members/{id}` | Remove someone, only the circle admin (403) |
| PUT | `/family/sharing` | `{shares_location}` |
