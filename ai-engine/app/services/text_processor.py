"""Chunking of README/docs before embedding.

The embedding model `paraphrase-multilingual-MiniLM-L12-v2` has
`max_seq_length = 128` tokens: anything longer is silently truncated, so the end
of the chunk is never embedded. Measured on the real FastAPI README, 450-character
chunks gave up to 174 tokens (24/66 chunks over 128), so chunks are now sized in
**tokens** with the model's own tokenizer: 120 tokens + [CLS]/[SEP] <= 128.
"""

import logging
import threading

logger = logging.getLogger(__name__)

CHUNK_TOKENS = 120
CHUNK_OVERLAP_TOKENS = 15
# Character fallback (only if the tokenizer cannot be loaded).
FALLBACK_CHUNK_CHARS = 350
FALLBACK_OVERLAP_CHARS = 40


class _SimpleTextSplitter:
    """Fallback used when langchain is not installed: split on blank lines."""

    def __init__(self, chunk_size: int, chunk_overlap: int):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def split_text(self, text: str) -> list[str]:
        paragraphs = [p for p in text.split("\n\n") if p.strip()]
        chunks: list[str] = []
        current = ""
        for paragraph in paragraphs:
            if current and len(current) + len(paragraph) + 2 > self.chunk_size:
                chunks.append(current)
                tail = current[-self.chunk_overlap :] if self.chunk_overlap else ""
                current = f"{tail}\n\n{paragraph}" if tail else paragraph
            else:
                current = f"{current}\n\n{paragraph}" if current else paragraph
        if current:
            chunks.append(current)
        return chunks


def _build_splitter():
    try:
        from langchain_text_splitters import RecursiveCharacterTextSplitter
    except ImportError:
        return _SimpleTextSplitter(FALLBACK_CHUNK_CHARS, FALLBACK_OVERLAP_CHARS)

    try:
        from app.services.embedder import get_model

        tokenizer = get_model().tokenizer
        return RecursiveCharacterTextSplitter.from_huggingface_tokenizer(
            tokenizer, chunk_size=CHUNK_TOKENS, chunk_overlap=CHUNK_OVERLAP_TOKENS
        )
    except Exception:
        logger.exception("Tokenizer unavailable, falling back to character chunks")
        return RecursiveCharacterTextSplitter(
            chunk_size=FALLBACK_CHUNK_CHARS, chunk_overlap=FALLBACK_OVERLAP_CHARS
        )


class _LazyChunker:
    """Builds the token splitter on first use (the tokenizer comes with the model)."""

    def __init__(self):
        self._splitter = None
        self._lock = threading.Lock()

    def split_text(self, text: str) -> list[str]:
        if self._splitter is None:
            with self._lock:
                if self._splitter is None:
                    self._splitter = _build_splitter()
        return self._splitter.split_text(text)


chunker = _LazyChunker()
