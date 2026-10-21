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
pytest
```

Tests create a separate `enlace_vital_test` database in the same container, run the migrations and roll back every test.

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
