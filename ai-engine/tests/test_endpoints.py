import requests
import json

BASE_URL = "http://127.0.0.1:8000"

print("--- Testing /health ---")
r = requests.get(f"{BASE_URL}/health")
print("Status:", r.status_code)
print("Response:", r.text)
print()

print("--- Testing /summarize ---")
summarize_payload = {
    "repo_id": 1,
    "full_name": "test/repo",
    "readme": "# FastAPI Project\n\nThis is a sample project using FastAPI, SQLAlchemy, and Docker.\n\n## Installation\n\n```bash\ndocker compose up -d\n```\n\n## Usage\n\nNavigate to `http://localhost:8000/docs` to see the API endpoints."
}
r = requests.post(f"{BASE_URL}/summarize", json=summarize_payload)
print("Status:", r.status_code)
try:
    print("Response:", json.dumps(r.json(), indent=2, ensure_ascii=False))
except:
    print("Response:", r.text)
print()

print("--- Testing /index ---")
index_payload = {
    "repo_id": 1,
    "full_name": "test/repo",
    "documents": [
        {"path": "README.md", "content": summarize_payload["readme"]},
        {"path": "app/main.py", "content": "from fastapi import FastAPI\napp = FastAPI()\n@app.get('/')\ndef read_root():\n    return {'Hello': 'World'}"}
    ]
}
r = requests.post(f"{BASE_URL}/index", json=index_payload)
print("Status:", r.status_code)
try:
    print("Response:", json.dumps(r.json(), indent=2, ensure_ascii=False))
except:
    print("Response:", r.text)
print()

print("--- Testing /chat ---")
chat_payload = {
    "repo_id": 1,
    "full_name": "test/repo",
    "question": "Làm thế nào để chạy project này?",
    "history": []
}
r = requests.post(f"{BASE_URL}/chat", json=chat_payload)
print("Status:", r.status_code)
try:
    print("Response:", json.dumps(r.json(), indent=2, ensure_ascii=False))
except:
    print("Response:", r.text)
print()
