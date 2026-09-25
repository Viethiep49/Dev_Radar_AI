"""Local sentence-transformers embedding model (loaded lazily, one instance)."""

import logging
import threading

logger = logging.getLogger(__name__)

MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

_model = None
_lock = threading.Lock()


def _load_model():
    from sentence_transformers import SentenceTransformer

    logger.info("Loading embedding model %s ...", MODEL_NAME)
    return SentenceTransformer(MODEL_NAME)


def get_model():
    """Return the shared model, loading it on first use (thread-safe)."""
    global _model
    if _model is None:
        with _lock:
            if _model is None:
                _model = _load_model()
    return _model


def encode(texts):
    """Encode one string or a list of strings. Returns a numpy array."""
    return get_model().encode(texts)


class _LazyEmbedder:
    """Backwards-compatible proxy so `from ... import embedder; embedder.encode(...)` keeps working."""

    def encode(self, texts):
        return encode(texts)


embedder = _LazyEmbedder()
