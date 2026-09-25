"""Chunking of README/docs before embedding.

`RecursiveCharacterTextSplitter` counts **characters**, not tokens. A chunk of
1500 characters is roughly 300-400 words (~500 tokens), which matches the size
described in AGENT.md / the backend contract.
"""

try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    chunker = RecursiveCharacterTextSplitter(chunk_size=1500, chunk_overlap=150)
except ImportError:

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

    chunker = _SimpleTextSplitter(chunk_size=1500, chunk_overlap=150)
