"""Fallback AI used when AI_ENGINE_URL is empty (the real AI engine is not running).

It is a simple, explainable stand-in for the real AI engine, with no ML library:
- summarize: take the first meaningful paragraph(s) of the README;
- quickstart: take the code block(s) under an "install" / "usage" / "getting started" heading;
- chat: keyword retrieval instead of RAG. The README is split into paragraphs,
  each paragraph gets a score = number of question words it contains,
  and the top 3 paragraphs are returned as the answer and as sources.

The real engine (see docs/AI_ENGINE_CONTRACT.md) does the same steps with
embeddings + an LLM, so the app works the same way in both modes.
"""

import re

MODEL_NAME = "fallback"
SUMMARY_MAX_CHARS = 600
EXCERPT_MAX_CHARS = 300
TOP_K = 3
MIN_WORD_LENGTH = 3  # words shorter than this ("a", "is", "to") are ignored

FALLBACK_PREFIX = "(Chế độ dự phòng, chưa có AI engine)"
NO_QUICKSTART = "Chưa có hướng dẫn nhanh"
NO_ANSWER = "Không tìm thấy thông tin này trong tài liệu của repo."
NO_README_ANSWER = "Repo này chưa có tài liệu (README) nên chưa thể trả lời câu hỏi."

QUICKSTART_HEADINGS = ("install", "usage", "getting started", "quick start", "quickstart", "setup")

# Common English words that would match almost every paragraph.
STOP_WORDS = {
    "the", "and", "for", "you", "your", "are", "this", "that", "with", "how", "what",
    "can", "does", "which", "who", "why", "when", "where", "from", "use", "have", "has",
}

_CODE_BLOCK_RE = re.compile(r"```.*?```", re.DOTALL)
_HTML_TAG_RE = re.compile(r"<[^>]+>")
_IMAGE_RE = re.compile(r"!\[[^\]]*\]\([^)]*\)")  # ![alt](url), also badges
_LINK_RE = re.compile(r"\[([^\]]*)\]\([^)]*\)")  # [text](url) -> text
_WORD_RE = re.compile(r"\w+")


def _clean_markdown(text: str) -> str:
    """Remove html tags, images/badges and link urls, keep the readable text."""
    text = _HTML_TAG_RE.sub("", text)
    text = _IMAGE_RE.sub("", text)
    text = _LINK_RE.sub(r"\1", text)
    return text.strip()


def _paragraphs(readme: str) -> list[str]:
    """Split the README (without code blocks) into cleaned, non-empty paragraphs."""
    text = _CODE_BLOCK_RE.sub("", readme)
    result = []
    for block in re.split(r"\n\s*\n", text):
        cleaned = _clean_markdown(block)
        if cleaned:
            result.append(cleaned)
    return result


def _is_meaningful(paragraph: str) -> bool:
    """A real sentence: not a heading, not a list of links, has enough words."""
    if paragraph.startswith("#"):
        return False
    return len(_WORD_RE.findall(paragraph)) >= 5


def _trim(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rsplit(" ", 1)[0] + "..."


def _summary_text(readme: str) -> str:
    chosen = []
    for paragraph in _paragraphs(readme):
        if not _is_meaningful(paragraph):
            continue
        chosen.append(" ".join(paragraph.split()))  # join wrapped lines
        if len(" ".join(chosen)) >= SUMMARY_MAX_CHARS or len(chosen) == 2:
            break
    if not chosen:
        return "Chưa có mô tả."
    return _trim(" ".join(chosen), SUMMARY_MAX_CHARS)


def _quickstart_text(readme: str) -> str:
    """Code blocks found under an install/usage/getting started heading."""
    # Read line by line so a "# comment" inside a code block is not taken for a heading.
    blocks = []
    current = None  # lines of the code block being read, or None when outside a block
    in_quickstart_section = False
    for line in readme.splitlines():
        if line.strip().startswith("```"):
            if current is None:
                current = [line]
            else:
                current.append(line)
                if in_quickstart_section:
                    blocks.append("\n".join(current))
                current = None
        elif current is not None:
            current.append(line)
        elif line.startswith("#"):
            heading = line.lower()
            in_quickstart_section = any(word in heading for word in QUICKSTART_HEADINGS)
        if len(blocks) == 2:
            break
    if not blocks:
        return NO_QUICKSTART
    return "\n\n".join(blocks)


def summarize(repo_id: int, full_name: str, readme: str) -> dict:
    return {"summary": _summary_text(readme), "quickstart": _quickstart_text(readme), "model": MODEL_NAME}


def index(repo_id: int, full_name: str, documents: list[dict]) -> dict:
    """Nothing to index without embeddings; return the paragraph count as "chunks"."""
    chunks = sum(len(_paragraphs(doc.get("content") or "")) for doc in documents)
    return {"chunks": chunks}


def _keywords(text: str) -> set[str]:
    words = _WORD_RE.findall(text.lower())
    return {w for w in words if len(w) >= MIN_WORD_LENGTH and w not in STOP_WORDS}


def chat(repo_id: int, full_name: str, question: str, history: list[dict], readme: str | None) -> dict:
    """Answer from the README paragraphs that share the most words with the question."""
    if not readme:
        return {"answer": f"{FALLBACK_PREFIX} {NO_README_ANSWER}", "sources": []}

    question_words = _keywords(question)
    scored = []
    for position, paragraph in enumerate(_paragraphs(readme)):
        score = len(question_words & _keywords(paragraph))
        if score > 0:
            scored.append((score, position, paragraph))

    if not scored:
        return {"answer": f"{FALLBACK_PREFIX} {NO_ANSWER}", "sources": []}

    # Best score first; for equal scores keep the README order.
    scored.sort(key=lambda item: (-item[0], item[1]))
    excerpts = [_trim(" ".join(paragraph.split()), EXCERPT_MAX_CHARS) for _, _, paragraph in scored[:TOP_K]]

    answer = f"{FALLBACK_PREFIX} Theo README của {full_name}:\n" + "\n".join(f"- {e}" for e in excerpts)
    sources = [{"path": "README.md", "excerpt": e} for e in excerpts]
    return {"answer": answer, "sources": sources}
