from app.core.database import SessionLocal
from sqlalchemy import text
db = SessionLocal()
res = db.execute(text("""
EXPLAIN ANALYZE
SELECT path, content
FROM (
    SELECT path, content, embedding <=> CAST(array_fill(0, ARRAY[384]) AS vector) AS dist
    FROM repo_embeddings
    WHERE repo_id = 1
) sub
WHERE dist <= 0.65
ORDER BY dist
LIMIT 3
"""))
print('\n'.join(row[0] for row in res))
