from sentence_transformers import SentenceTransformer

model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
print("max_seq_length:", model.max_seq_length)

test_chunk = "A" * 450
tokens = model.tokenizer.tokenize(test_chunk)
print("tokens for 450 chars chunk:", len(tokens))
