try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
except ImportError:
    class RecursiveCharacterTextSplitter:
        def __init__(self, chunk_size, chunk_overlap):
            self.chunk_size = chunk_size
            self.chunk_overlap = chunk_overlap

        def split_text(self, text):
            # Fallback simple chunking if langchain is not available
            chunks = []
            start = 0
            while start < len(text):
                chunks.append(text[start:start+self.chunk_size])
                start += self.chunk_size - self.chunk_overlap
            return chunks

chunker = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
