# AGENT.md — Technical Documentation for AI Engine

> **Project:** Dev Radar AI  
> **Service:** `ai-engine` (FastAPI, Python)  
> **Last updated:** 2026-09-23

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                        Backend (Go)                          │
│              calls HTTP POST to ai-engine:8000                │
└──────────┬────────────────────┬────────────────┬────────────┘
           │ /index             │ /summarize     │ /chat
           ▼                    ▼                ▼
┌──────────────────────────────────────────────────────────────┐
│                  AI Engine (FastAPI :8000)                   │
│                                                              │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │  Indexer Agent  │  │ Summarizer Agent │  │  RAG Chat  │ │
│  │   (Agent 1)    │  │   (Agent 2)      │  │  (Agent 3) │ │
│  └───────┬─────────┘  └───────┬──────────┘  └─────┬──────┘ │
│          │                 │                     │          │
│  sentence‑transformers   Ollama (qwen2.5:7b)   sentence‑transformers │
│  (local embed)            via HTTP :11434    (local embed) │
│          │                 │                     │          │
└──────────┼─────────────────┼─────────────────────┼──────────┘
           │                 │                     │
           ▼                 ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│          PostgreSQL 16 + pgvector (db:5432)                 │
│                  Table: repo_embeddings                     │
│   (repo_id, path, content, embedding vector(384))           │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Remarks |
|---|---|---|
| **API** | FastAPI `>=0.110.0` | Async, auto‑generated OpenAPI |
| **Server** | Uvicorn `>=0.27.1` | Runs on port 8000 |
| **Validation** | Pydantic v2 `>=2.8.2` | Request/response models |
| **HTTP Client** | httpx `>=0.27.0` | Calls Ollama (timeout 120 s) |
| **Embedding** | `sentence‑transformers` `>=2.5.1` | Model **all‑MiniLM‑L6‑v2** (384‑dim) – runs locally, CPU only |
| **LLM** | Ollama container (`qwen2.5:7b`) | GPU‑enabled via NVIDIA driver |
| **Vector DB** | PostgreSQL 16 + pgvector `>=0.2.5` | Index `ivfflat` on `vector_cosine_ops` |
| **ORM** | SQLAlchemy `>=2.0.29` + raw SQL | Simple `text()` statements for vector ops |
| **Driver** | psycopg2‑binary `>=2.9.9` | PostgreSQL driver |
| **Chunker** | `langchain‑text‑splitters` (fallback builtin) | `RecursiveCharacterTextSplitter` |
| **Containerisation** | Docker / docker‑compose | Python 3.12‑slim base image |

---

## Agent 1 – Indexer (Tiêu hoá dữ liệu)

### Goal
Accept a list of documents (README, docs, source files), split each into ~500‑token chunks, embed the chunks with `sentence‑transformers`, and store the vectors in PostgreSQL + pgvector.

### Endpoint
```
POST /index
```

### Request schema
```json
{
  "repo_id": 123,
  "full_name": "owner/repo",
  "documents": [
    {"path": "README.md", "content": "..."},
    {"path": "docs/setup.md", "content": "..."}
  ]
}
```

### Response schema
```json
{"chunks": 42}
```

### Processing steps
1. **Delete old chunks** for the given `repo_id` (`DELETE FROM repo_embeddings WHERE repo_id = :repo_id`).
2. **Chunking** – `RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)`; preferred separators `"\n\n" → "\n" → " " → ""`.
3. **Embedding** – `embedder.encode(chunks).tolist()` producing a list of 384‑dim vectors.
4. **Insert** each `(repo_id, path, chunk, embedding)` into `repo_embeddings`.
5. Commit and return total number of stored chunks.

### Tools used
- ✅ **sentence‑transformers** (local) – no network call.
- ✅ **langchain‑text‑splitters** – fallback implementation if the library is unavailable.
- ✅ **SQLAlchemy + pgvector** – batch INSERT.
- ❌ **Ollama** – **not used** in this agent.

### Important notes
- The whole operation is **idempotent**: a fresh index wipes prior data for the same `repo_id`.
- Vectors are serialized as Python list strings (`str([...])`) before insertion – PostgreSQL’s `vector` type accepts that format.
- Chunk size 500 tokens ≈ 350 words; overlap 50 tokens provides continuity for cross‑chunk context.

---

## Agent 2 – Summarizer (Tóm tắt)

### Goal
Read the entire README, ask Ollama to produce **exactly one JSON object** containing:
- `summary`: 3‑5 Vietnamese sentences (max 600 chars).
- `quickstart`: Markdown‑formatted install/run snippet (or fallback string).
The model must be forced to output JSON to avoid parsing errors.

### Endpoint
```
POST /summarize
```

### Request schema
```json
{
  "repo_id": 123,
  "full_name": "owner/repo",
  "readme": "# My Project\n..."
}
```

### Response schema
```json
{
  "summary": "…",
  "quickstart": "```bash\n...\n```",
  "model": "qwen2.5:7b-local"
}
```

### Processing steps
1. **Truncate** README to the first 3000 characters (protects model context window).
2. **Prompt construction** – clear role, explicit output schema, and the truncated README.
3. **Call Ollama** with payload:
   ```json
   {
     "model": "qwen2.5:7b",
     "prompt": "<prompt>",
     "stream": false,
     "format": "json"
   }
   ```
   `format: "json"` forces grammar‑constrained decoding.
4. **Parse** `response["response"]` as JSON. On success return the fields; on `JSONDecodeError` raise `HTTP 500` with a clear message.

### Tools used
- ✅ **Ollama** (`qwen2.5:7b`) – generation with JSON constraint.
- ❌ **sentence‑transformers** – not used.

### Prompt example (excerpt)
```
Bạn là chuyên gia phân tích mã nguồn. Hãy đọc README của dự án {full_name}.
Yêu cầu trả về đúng định dạng JSON với 2 trường:
- "summary": 3‑5 câu tiếng Việt (max 600 ký tự) mô tả dự án.
- "quickstart": câu lệnh cài đặt/chạy (markdown) hoặc "Chưa có hướng dẫn nhanh".

README:
{readme[:3000]}
```

---

## Agent 3 – RAG Chat (Hỏi đáp)

### Goal
Given a user question, retrieve the most relevant chunks from `repo_embeddings` (top 3 by cosine similarity), combine them with recent chat history, and let Ollama generate a concise Vietnamese answer. **Never hallucinate** – if no relevant data exists, answer *"Không tìm thấy trong tài liệu"*.

### Endpoint
```
POST /chat
```

### Request schema
```json
{
  "repo_id": 123,
  "full_name": "owner/repo",
  "question": "Làm sao cài đặt?",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

### Response schema
```json
{
  "answer": "...",
  "sources": [
    {"path": "README.md", "excerpt": "..."},
    {"path": "docs/install.md", "excerpt": "..."}
  ]
}
```

### Processing pipeline
1. **Embed question** – `embedder.encode(question).tolist()` (local embedding).
2. **Vector search** – PGSQL query using `<=>` (cosine distance) limited to 3 rows:
   ```sql
   SELECT path, content
   FROM repo_embeddings
   WHERE repo_id = :repo_id
   ORDER BY embedding <=> :q_vector::vector
   LIMIT 3;
   ```
3. **If no rows** → return `{answer: "Không tìm thấy trong tài liệu", sources: []}`.
4. **Build context** – join the 3 chunks with `\n---\n`.
5. **Gather recent history** – last 6 messages concatenated as `role: content` lines.
6. **Prompt creation** – role‑playing assistant, strict instruction not to fabricate:
   ```text
   Bạn là trợ lý giải thích repo GitHub "{full_name}".
   Chỉ dùng thông tin trong TÀI LIỆU dưới đây để trả lời.
   Nếu tài liệu không chứa câu trả lời, hãy nói chính xác "Không tìm thấy trong tài liệu", KHÔNG bịa đặt.
   Trả lời ngắn gọn bằng tiếng Việt.

   TÀI LIỆU:
   {context_text}

   LỊCH SỬ CHAT:
   {history_text}

   Câu hỏi hiện tại: {question}
   Trả lời:
   ```
   ```
7. **Call Ollama** (no `format: json` – we need free‑form Vietnamese).
8. Return the model answer and the list of sources (path + first 300 chars of each chunk).

### Tools used
- ✅ **sentence‑transformers** – embed the query.
- ✅ **pgvector** – cosine similarity search.
- ✅ **Ollama** – generate final answer.
- 🔗 **Combination** – retrieval via embedding, generation via LLM.

### Important notes
- Only the **top‑3** chunks are fed to the LLM to keep the prompt within the model’s context window.
- History is limited to **6 most recent messages** to avoid overflow.
- Sources are returned so the UI can display the origin of each piece of information.
- The prompt explicitly forbids hallucination; the model still may attempt to answer, but the instruction dramatically reduces fabrication.

---

## Directory Layout
## Directory Layout
```
ai-engine/
├─ AGENT.md                ← documentation (this file)
├─ Dockerfile              ← Python 3.12‑slim, installs PyTorch‑CPU + requirements
├─ .dockerignore
├─ requirements.txt        ← fastapi, uvicorn, pydantic, httpx,
│                           sentence-transformers, sqlalchemy,
│                           psycopg2-binary, pgvector, langchain‑text‑splitters
├─ app/
│   ├─ __init__.py
│   ├─ main.py             ← FastAPI app, includes routers
│   ├─ core/
│   │   ├─ config.py       ← environment variable management
│   │   └─ database.py     ← SQLAlchemy engine & SessionLocal
│   ├─ schemas/
│   │   ├─ payload.py      ← request models (SummarizeRequest, ChatRequest, IndexRequest)
│   │   └─ response.py     ← optional response models
│   ├─ services/
│   │   ├─ embedder.py     ← SentenceTransformer singleton
│   │   ├─ llm_client.py   ← httpx wrapper for Ollama
│   │   └─ text_processor.py ← chunking logic (Langchain splitter)
│   └─ api/
│       └─ v1.py           ← routes: /index, /summarize, /chat
```

---

## Environment Variables
| Variable | Default | Description |
|---|---|---|
| `OLLAMA_URL` | `http://ollama:11434/api/generate` | Ollama endpoint (auto‑normalized to end with `/api/generate`). |
| `DATABASE_URL` | `postgresql://devradar:change_me@db:5432/devradar` | PostgreSQL connection string (used by SQLAlchemy). |

---

## Database Schema (`repo_embeddings`)
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE repo_embeddings (
    id        SERIAL PRIMARY KEY,
    repo_id   INTEGER NOT NULL,
    path      TEXT NOT NULL,                 -- file path inside repository
    content   TEXT NOT NULL,                 -- raw chunk text
    embedding vector(384) NOT NULL           -- all‑MiniLM‑L6‑v2 output
);

-- Index for fast cosine similarity search (ivfflat)
CREATE INDEX repo_embeddings_embedding_idx ON repo_embeddings
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
```
> The migration is managed by the backend service; AI Engine only reads/writes rows.

---

## Deployment
### Docker‑Compose (single command)
```bash
# From the project root directory
docker-compose up -d
```
Boot order (via `depends_on`):
1. **db** – PostgreSQL + pgvector, health‑checked.
2. **ollama** – GPU container.
3. **ollama‑pull** – pulls `qwen2.5:7b` (runs once, may take minutes).
4. **ai‑engine** – waits for `ollama` started & `db` healthy, loads the embedding model.
5. **backend** – finally starts.

### Local development
```bash
cd ai-engine
pip install -r requirements.txt
# Install CPU‑only PyTorch (≈90 MB)
pip install torch --index-url https://download.pytorch.org/whl/cpu

# Set env vars (adjust as needed)
export OLLAMA_URL=http://localhost:11434
export DATABASE_URL=postgresql://devradar:change_me@localhost:5432/devradar

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
The embedding model is loaded on startup:
```python
print("Đang tải model embedding local...")
embedder = SentenceTransformer('all-MiniLM-L6-v2')
```
The first run will download the model (~90 MB) and cache it inside the container.

---

## Limitations & Future Improvements
| Current limitation | Suggested improvement |
|---|---|
| Fixed 120 s timeout for Ollama calls | Add exponential back‑off with retries, surface a clear error to the client. |
| No similarity threshold – always returns 3 chunks | Introduce a cosine‑distance cutoff (e.g., 0.8) and return *"Không tìm thấy trong tài liệu"* when all distances exceed it. |
| Model embedding loaded at cold start | Bake the model into the Docker image or mount a persistent cache volume to reduce cold‑start latency. |
| History limited to 6 messages | Persist conversation state in Redis or a DB for multi‑turn sessions exceeding 6 messages. |
| No rate‑limiting / authentication on the API | Add FastAPI middleware (e.g., `slowapi`) to cap requests per minute and enforce API keys. |
| JSON parsing failures when Ollama returns stray text | Add a tolerant post‑processor that extracts a JSON block with regex before `json.loads`. |

---

*End of `AGENT.md`*
