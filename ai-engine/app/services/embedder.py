from sentence_transformers import SentenceTransformer

print("Đang tải model embedding local...")
embedder = SentenceTransformer('all-MiniLM-L6-v2')
