@echo off
echo ==============================================
echo  Starting DevRadar AI Backend (FastAPI)
echo ==============================================
cd /d "%~dp0backend"

if not exist ".venv" (
    echo Creating virtual environment .venv...
    python -m venv .venv
    .venv\Scripts\python -m pip install -r requirements-dev.txt
)

echo Ensuring database and seed data are ready...
.venv\Scripts\python -c "from app.db.base import Base; from app.db.session import engine; import app.models; Base.metadata.create_all(engine)"
.venv\Scripts\python -m scripts.seed

echo.
echo ==============================================
echo  Backend running at: http://localhost:8080
echo  Swagger API Docs:   http://localhost:8080/docs
echo ==============================================
.venv\Scripts\uvicorn app.main:app --port 8080 --reload
