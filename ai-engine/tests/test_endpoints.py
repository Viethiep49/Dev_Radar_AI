"""Integration smoke test against a running ai-engine.

Run it manually after `docker compose up ai-engine`:

    python tests/test_endpoints.py

It is NOT part of the pytest suite (it needs a live server + Ollama).
"""

import json

import requests

BASE_URL = "http://127.0.0.1:8000"


def pretty(response: requests.Response) -> str:
    try:
        return json.dumps(response.json(), indent=2, ensure_ascii=False)
    except ValueError:
        return response.text


def main() -> None:
    print("--- /health ---")
    response = requests.get(f"{BASE_URL}/health", timeout=10)
    print(response.status_code, response.text)

    print("\n--- /summarize ---")
    summarize_payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "readme": (
            "# FastAPI Project\n\nThis is a sample project using FastAPI, "
            "SQLAlchemy and Docker.\n\n## Installation\n\n"
        ),
    }
    response = requests.post(f"{BASE_URL}/summarize", json=summarize_payload, timeout=120)
    print(response.status_code, pretty(response))

    print("\n--- /index ---")
    index_payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "documents": [{"path": "README.md", "content": summarize_payload["readme"]}],
    }
    response = requests.post(f"{BASE_URL}/index", json=index_payload, timeout=120)
    print(response.status_code, pretty(response))

    print("\n--- /chat ---")
    chat_payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "question": "Làm thế nào để chạy project này?",
        "history": [],
    }
    response = requests.post(f"{BASE_URL}/chat", json=chat_payload, timeout=120)
    print(response.status_code, pretty(response))


if __name__ == "__main__":
    main()
