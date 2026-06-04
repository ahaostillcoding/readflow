from fastapi import FastAPI

from .database import Base, engine
from .routers import ai, auth, feeds, sync

Base.metadata.create_all(bind=engine)

app = FastAPI(title="ReadFlow API")

app.include_router(auth.router)
app.include_router(feeds.router)
app.include_router(sync.router)
app.include_router(ai.router)


@app.get("/health")
def health():
    return {"status": "ok"}
