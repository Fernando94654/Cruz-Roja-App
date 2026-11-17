# Adds the new texts to the database, computes the missing vectors and writes the app's copy.
# Needs a Mac with Xcode. Run with: python -m scripts.load_knowledge
import json
import subprocess
import tempfile
from pathlib import Path

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

from app.models.knowledge import KbChunk
from scripts.knowledge_content import CHUNKS

REPO = Path(__file__).resolve().parents[2]
BUNDLED = REPO / "CruzRoja/Resources/knowledge.json"


def embed(texts: dict[str, str], query: bool = False) -> tuple[str, dict[str, list[float]]]:
    # Builds and runs the Swift tool so the vectors match the app
    sources = [REPO / "CruzRoja/Features/Assistant/Services/Embedder.swift",
               REPO / "CruzRoja/Features/Assistant/Services/BPETokenizer.swift",
               REPO / "tools/embed-knowledge/main.swift"]
    with tempfile.TemporaryDirectory() as folder:
        tool = Path(folder) / "embed-knowledge"
        subprocess.run(["xcrun", "swiftc", "-O", *map(str, sources), "-o", str(tool)], check=True)
        command = [str(tool), str(REPO / "CruzRoja/Resources/EmbeddingGemma.mlpackage"),
                   str(REPO / "CruzRoja/Resources/EmbeddingGemma-tokenizer.json")] + (["--query"] if query else [])
        items = [{"id": key, "text": text} for key, text in texts.items()]
        output = subprocess.run(command, input=json.dumps(items).encode(), capture_output=True, check=True).stdout
    result = json.loads(output)
    return result["model"], result["vectors"]


def insert_missing(db: Session) -> int:
    added = db.scalars(insert(KbChunk).values(CHUNKS).on_conflict_do_nothing().returning(KbChunk.id)).all()
    return len(added)


def embed_missing(db: Session, embed=embed) -> int:
    chunks = db.scalars(select(KbChunk).where(KbChunk.embedding.is_(None))).all()
    if not chunks:
        return 0
    model, vectors = embed({chunk.id: chunk.text for chunk in chunks})
    for chunk in chunks:
        db.execute(update(KbChunk).where(KbChunk.id == chunk.id)
                   .values(embedding=vectors[chunk.id], embedding_model=model))
    return len(chunks)


def write_bundle(db: Session) -> int:
    chunks = [{"id": c.id, "text": c.text, "embedding_model": c.embedding_model,
               "embedding": [round(value, 6) for value in c.embedding]}
              for c in db.scalars(select(KbChunk).where(KbChunk.embedding.is_not(None)).order_by(KbChunk.id))]
    BUNDLED.write_text(json.dumps(chunks, ensure_ascii=False) + "\n", encoding="utf-8")
    return len(chunks)


def main() -> None:
    from app.db import SessionLocal, engine

    target = make_url(engine.url)
    print(f"Database: {target.host}/{target.database}")
    with SessionLocal() as db:
        inserted = insert_missing(db)
        embedded = embed_missing(db)
        db.commit()
        written = write_bundle(db)
    print(f"Inserted {inserted} chunks, embedded {embedded}, wrote {written} to {BUNDLED.relative_to(REPO)}")


if __name__ == "__main__":
    main()
