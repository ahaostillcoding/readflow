# ReadFlow API

FastAPI service skeleton for account auth, device registration, feed metadata, sync events, and AI metadata.

## Run locally

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Use `READFLOW_DATABASE_URL` to point at PostgreSQL in production. The default uses local SQLite for development.
