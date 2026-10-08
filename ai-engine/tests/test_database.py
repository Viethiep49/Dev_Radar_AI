"""ensure_schema() must self-heal databases created by older versions."""

from unittest.mock import patch

from app.core.database import ensure_schema


def _executed_statements(engine) -> list[str]:
    connection = engine.begin.return_value.__enter__.return_value
    return [str(call.args[0]) for call in connection.execute.call_args_list]


def test_ensure_schema_drops_the_legacy_ivfflat_index():
    """An index created before ivfflat was removed is still in old databases.

    With lists=100 over a few hundred rows and the default probes=1,
    `ORDER BY embedding <=> $1 LIMIT k` scans a single list and can return 0
    rows, so /chat answers "Không tìm thấy trong tài liệu" for every question.
    CREATE ... IF NOT EXISTS cannot drop it, so ensure_schema has to.
    """
    with patch("app.core.database.engine") as engine:
        ensure_schema()

    statements = _executed_statements(engine)
    assert any("DROP INDEX IF EXISTS repo_embeddings_embedding_idx" in s for s in statements)


def test_ensure_schema_keeps_the_repo_id_index():
    with patch("app.core.database.engine") as engine:
        ensure_schema()

    statements = _executed_statements(engine)
    assert any("repo_embeddings_repo_id_idx" in s and "CREATE INDEX" in s for s in statements)


def test_ensure_schema_never_raises_when_the_db_is_down():
    with patch("app.core.database.engine") as engine:
        engine.begin.side_effect = Exception("db down")

        ensure_schema()  # must swallow: startup continues without the table
