"""EXPLAIN ANALYZE the /chat retrieval query with a real question embedding.

Usage (inside the ai-engine container, after at least one repo was indexed):
    python scripts/explain_test.py <repo_id> "câu hỏi"
"""
import sys

from sqlalchemy import text

from app.api.v1 import _vector_literal
from app.core.config import MIN_SIMILARITY
from app.core.database import SessionLocal
from app.services.embedder import embedder

repo_id = int(sys.argv[1]) if len(sys.argv) > 1 else 1
question = sys.argv[2] if len(sys.argv) > 2 else "Cài đặt dự án như thế nào?"

# A zero vector has no cosine distance, so always use a real embedding.
q_vector = _vector_literal(embedder.encode(question).tolist())

db = SessionLocal()
try:
    rows = db.execute(
        text(
            """
            EXPLAIN ANALYZE
            SELECT path, content
            FROM (
                SELECT path, content, embedding <=> CAST(:q_vector AS vector) AS dist
                FROM repo_embeddings
                WHERE repo_id = :repo_id
            ) sub
            WHERE dist <= :max_distance
            ORDER BY dist
            LIMIT 3
            """
        ),
        {"q_vector": q_vector, "repo_id": repo_id, "max_distance": 1 - MIN_SIMILARITY},
    )
    print("\n".join(row[0] for row in rows))
finally:
    db.close()
