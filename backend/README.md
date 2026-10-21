# Enlace Vital — Backend

PostgreSQL 17 + PostGIS in Docker; schema managed with SQLAlchemy and Alembic.

## Setup

```bash
# from the repo root
cp .env.example .env            # set a password and generate MEDICAL_DATA_KEY
docker compose up -d

cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -e .
alembic upgrade head
python scripts/seed.py          # test data (wipes existing data)
```

Connect: `docker compose exec db psql -U enlace_vital -d enlace_vital`

## Schema changes

1. Edit the models in `app/models/`.
2. `alembic revision --autogenerate -m "description"` and review the generated file.
3. `alembic upgrade head`.
