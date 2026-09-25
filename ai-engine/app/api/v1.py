import json
import logging

from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.core.config import MIN_SIMILARITY
from app.core.database import SessionLocal
from app.schemas.payload import ChatRequest, IndexRequest, SummarizeRequest
from app.services.embedder import embedder
from app.services.llm_client import call_ollama
from app.services.text_processor import chunker

logger = logging.getLogger(__name__)

router = APIRouter()

TOP_K = 3
README_MAX_CHARS = 3000
EXCERPT_MAX_CHARS = 300


def _vector_literal(values) -> str:
    """pgvector text format: [0.1,0.2,0.3] (comma separated, no spaces).

    `str(numpy_array)` uses spaces and makes pgvector fail to parse it.
    """
    return "[" + ",".join(f"{float(value):.7g}" for value in values) + "]"


@router.post("/summarize")
def summarize(req: SummarizeRequest):
    prompt = f"""Bạn là chuyên gia phân tích mã nguồn. Hãy đọc README sau của dự án {req.full_name}.
Yêu cầu trả về đúng định dạng JSON với 2 trường:
- "summary": Viết 3-5 câu tiếng Việt tóm tắt dự án này làm gì, giải quyết vấn đề gì (tối đa 600 ký tự).
- "quickstart": Trích xuất câu lệnh cài đặt hoặc chạy thử (markdown). Nếu không có, ghi "Chưa có hướng dẫn nhanh".

README:
{req.readme[:README_MAX_CHARS]}
"""

    response_text = call_ollama(prompt, json_format=True)

    try:
        data = json.loads(response_text)
    except json.JSONDecodeError:
        logger.warning("Ollama returned invalid JSON for %s", req.full_name)
        raise HTTPException(status_code=502, detail="Ollama trả về JSON không hợp lệ.")

    return {
        "summary": data.get("summary", "Không thể tóm tắt."),
        "quickstart": data.get("quickstart", "Chưa có hướng dẫn nhanh"),
        "model": "qwen2.5:7b-local",
    }


@router.post("/index")
def index_repo(req: IndexRequest):
    db = SessionLocal()
    try:
        # Re-indexing the same repo replaces its old chunks.
        db.execute(text("DELETE FROM repo_embeddings WHERE repo_id = :repo_id"), {"repo_id": req.repo_id})

        total_chunks = 0
        for doc in req.documents:
            chunks = chunker.split_text(doc.content)
            if not chunks:
                continue

            embeddings = embedder.encode(chunks).tolist()

            for chunk, emb in zip(chunks, embeddings):
                db.execute(
                    text(
                        "INSERT INTO repo_embeddings (repo_id, path, content, embedding) "
                        "VALUES (:repo_id, :path, :content, CAST(:embedding AS vector))"
                    ),
                    {
                        "repo_id": req.repo_id,
                        "path": doc.path,
                        "content": chunk,
                        "embedding": _vector_literal(emb),
                    },
                )
                total_chunks += 1

        db.commit()
        return {"chunks": total_chunks}
    except Exception:
        db.rollback()
        logger.exception("Indexing repo %s failed", req.repo_id)
        raise HTTPException(status_code=500, detail="Không thể đánh index tài liệu của repo.")
    finally:
        db.close()


@router.post("/chat")
def chat(req: ChatRequest):
    question_vector = _vector_literal(embedder.encode(req.question).tolist())

    db = SessionLocal()
    try:
        # cosine distance = 1 - cosine similarity; keep only close enough chunks.
        max_distance = 1.0 - MIN_SIMILARITY
        result = db.execute(
            text(
                """
                SELECT path, content
                FROM repo_embeddings
                WHERE repo_id = :repo_id
                  AND embedding <=> CAST(:q_vector AS vector) <= :max_distance
                ORDER BY embedding <=> CAST(:q_vector AS vector)
                LIMIT :top_k
                """
            ),
            {
                "repo_id": req.repo_id,
                "q_vector": question_vector,
                "max_distance": max_distance,
                "top_k": TOP_K,
            },
        )
        rows = result.fetchall()
    finally:
        db.close()

    if not rows:
        return {"answer": "Không tìm thấy trong tài liệu", "sources": []}

    context_text = "\n---\n".join(row[1] for row in rows)
    sources = [{"path": row[0], "excerpt": row[1][:EXCERPT_MAX_CHARS]} for row in rows]

    history_text = "\n".join(f"{msg.role}: {msg.content}" for msg in req.history[-6:])

    prompt = f"""Bạn là trợ lý giải thích repo GitHub "{req.full_name}".
Chỉ dùng thông tin trong TÀI LIỆU bên dưới để trả lời. Nếu tài liệu không có thông tin, hãy nói chính xác "Không tìm thấy trong tài liệu", KHÔNG được bịa đặt. Trả lời ngắn gọn bằng tiếng Việt.

TÀI LIỆU:
{context_text}

LỊCH SỬ CHAT:
{history_text}

Câu hỏi hiện tại: {req.question}
Trả lời:"""

    answer = call_ollama(prompt, json_format=False)

    return {"answer": answer.strip(), "sources": sources}
