from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import get_current_user

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/metadata")
def save_ai_metadata(
    payload: schemas.AiMetadataIn,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing = db.scalar(select(models.EntryAiMetadata).where(models.EntryAiMetadata.entry_id == payload.entry_id))
    tags = ",".join(payload.tags)
    if existing is None:
        existing = models.EntryAiMetadata(
            entry_id=payload.entry_id,
            summary=payload.summary,
            tags=tags,
            model=payload.model,
            content_hash=payload.content_hash,
        )
        db.add(existing)
    else:
        existing.summary = payload.summary
        existing.tags = tags
        existing.model = payload.model
        existing.content_hash = payload.content_hash
    db.commit()
    return {"saved": True}


@router.post("/summarize")
def enqueue_summary(entry_id: int, user: models.User = Depends(get_current_user)):
    return {
        "queued": True,
        "entry_id": entry_id,
        "status": "placeholder",
        "message": "Connect this endpoint to the worker and model provider in Phase 2.3.",
    }
