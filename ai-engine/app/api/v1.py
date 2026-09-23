import json
from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.schemas.payload import SummarizeRequest, IndexRequest, ChatRequest
from app.services.llm_client import call_ollama
from app.services.text_processor import chunker
from app.services.embedder import embedder
from app.core.database import SessionLocal

router = APIRouter()

@router.post("/summarize")
def summarize(req: SummarizeRequest):
    prompt = f"""Bạn là chuyên gia phân tích mã nguồn. Hãy đọc README sau của dự án {req.full_name}.
Yêu cầu trả về đúng định dạng JSON với 2 trường:
- "summary": Viết 3-5 câu tiếng Việt tóm tắt dự án này làm gì, giải quyết vấn đề gì (tối đa 600 ký tự).
- "quickstart": Trích xuất câu lệnh cài đặt hoặc chạy thử (markdown). Nếu không có, ghi "Chưa có hướng dẫn nhanh".

README:
{req.readme[:3000]} # Cắt ngắn để tránh tràn context
"""
    
    response_text = call_ollama(prompt, json_format=True)
    
    try:
        data = json.loads(response_text)
        return {
            "summary": data.get("summary", "Không thể tóm tắt."),
            "quickstart": data.get("quickstart", "Chưa có hướng dẫn nhanh"),
            "model": "qwen2.5:7b-local"
        }
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Ollama trả về JSON không hợp lệ.")

@router.post("/index")
def index_repo(req: IndexRequest):
    db = SessionLocal()
    try:
        # 1. Xóa chunk cũ
        db.execute(text("DELETE FROM repo_embeddings WHERE repo_id = :repo_id"), {"repo_id": req.repo_id})
        
        total_chunks = 0
        # 2. Băm và lưu chunk mới
        for doc in req.documents:
            chunks = chunker.split_text(doc.content)
            if not chunks:
                continue
                
            embeddings = embedder.encode(chunks).tolist()
            
            for chunk, emb in zip(chunks, embeddings):
                db.execute(
                    text("INSERT INTO repo_embeddings (repo_id, path, content, embedding) VALUES (:repo_id, :path, :content, :embedding)"),
                    {"repo_id": req.repo_id, "path": doc.path, "content": chunk, "embedding": str(emb)}
                )
                total_chunks += 1
        
        db.commit()
        return {"chunks": total_chunks}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()

@router.post("/chat")
def chat(req: ChatRequest):
    # 1. Nhúng câu hỏi của user
    question_vector = embedder.encode(req.question).tolist()
    
    db = SessionLocal()
    try:
        # 2. Tìm top 3 chunk giống nhất (Cosine similarity <=> pgvector)
        result = db.execute(
            text("""
                SELECT path, content 
                FROM repo_embeddings 
                WHERE repo_id = :repo_id 
                ORDER BY embedding <=> :q_vector::vector 
                LIMIT 3
            """),
            {"repo_id": req.repo_id, "q_vector": str(question_vector)}
        )
        
        rows = result.fetchall()
        if not rows:
            return {"answer": "Chưa có tài liệu cho repository này.", "sources": []}
            
        context_text = "\n---\n".join([row[1] for row in rows])
        sources = [{"path": row[0], "excerpt": row[1][:300]} for row in rows]
        
    finally:
        db.close()

    # 3. Chuẩn bị prompt với history
    history_text = "\n".join([f"{msg.role}: {msg.content}" for msg in req.history[-6:]])
    
    prompt = f"""Bạn là trợ lý giải thích repo GitHub "{req.full_name}".
Chỉ dùng thông tin trong TÀI LIỆU bên dưới để trả lời. Nếu tài liệu không có thông tin, hãy nói chính xác "Không tìm thấy trong tài liệu", KHÔNG được bịa đặt. Trả lời ngắn gọn bằng tiếng Việt.

TÀI LIỆU:
{context_text}

LỊCH SỬ CHAT:
{history_text}

Câu hỏi hiện tại: {req.question}
Trả lời:"""

    answer = call_ollama(prompt, json_format=False)
    
    return {
        "answer": answer.strip(),
        "sources": sources
    }
