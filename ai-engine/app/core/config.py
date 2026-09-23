import os

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434/api/generate")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://devradar:change_me@db:5432/devradar")
