import json

def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_summarize(client, mock_ollama):
    mock_ollama.return_value = json.dumps({
        "summary": "Dự án test",
        "quickstart": "npm start",
        "model": "test-model"
    })
    
    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "readme": "# Hello"
    }
    
    response = client.post("/summarize", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["summary"] == "Dự án test"
    assert data["quickstart"] == "npm start"
    mock_ollama.assert_called_once()

def test_index(client, mock_embedder, mock_db):
    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "documents": [
            {"path": "README.md", "content": "Hello World"}
        ]
    }
    
    response = client.post("/index", json=payload)
    assert response.status_code == 200
    assert response.json() == {"chunks": 1}
    
    # Verify DB calls
    assert mock_db.execute.call_count >= 2 # DELETE + INSERT
    mock_db.commit.assert_called_once()
    mock_embedder.encode.assert_called_once()

def test_chat(client, mock_embedder, mock_db, mock_ollama):
    mock_ollama.return_value = "Đây là câu trả lời mock."
    
    payload = {
        "repo_id": 1,
        "full_name": "test/repo",
        "question": "Làm thế nào để chạy?",
        "history": []
    }
    
    response = client.post("/chat", json=payload)
    assert response.status_code == 200
    data = response.json()
    
    assert data["answer"] == "Đây là câu trả lời mock."
    assert len(data["sources"]) == 1
    assert data["sources"][0]["path"] == "README.md"
    
    mock_embedder.encode.assert_called_once()
    mock_db.execute.assert_called_once()
    mock_ollama.assert_called_once()
