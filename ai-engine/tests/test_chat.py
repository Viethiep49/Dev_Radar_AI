import requests
import json

BASE_URL = "http://127.0.0.1:8000"

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
