import logging

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from .config import DATABASE_URL

logger = logging.getLogger(__name__)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

EMBEDDING_DIM = 384  # paraphrase-multilingual-MiniLM-L12-v2 output size

# Schema of the ai-engine's own table. Kept here so /index and /chat can be
# sure the table exists even though the backend's alembic migration does not
# create it (this table belongs to the ai-engine schema).
ENSURE_SCHEMA_SQL = [
    "CREATE EXTENSION IF NOT EXISTS vector",
    f"""
    CREATE TABLE IF NOT EXISTS repo_embeddings (
        id        SERIAL PRIMARY KEY,
        repo_id   INTEGER NOT NULL,
        path      TEXT NOT NULL,
        content   TEXT NOT NULL,
        embedding vector({EMBEDDING_DIM}) NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS repo_embeddings_repo_id_idx ON repo_embeddings (repo_id)",
    # ivfflat has been removed because it scans clusters before filtering by repo_id,
    # which can cause 0 chunks to be returned for small datasets.
    # If the dataset grows very large, consider using HNSW with hnsw.iterative_scan = strict_order.
]


def ensure_schema() -> None:
    """Create the ai-engine table/index if they are missing. Never raises."""
    try:
        with engine.begin() as connection:
            for statement in ENSURE_SCHEMA_SQL:
                connection.execute(text(statement))
        logger.info("ai-engine schema is ready")
    except Exception:
        logger.exception("Could not prepare the ai-engine schema (is the DB up?)")
