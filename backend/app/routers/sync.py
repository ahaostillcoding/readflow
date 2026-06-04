import json

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import get_current_user

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push")
def push_changes(
    changes: list[schemas.SyncChange],
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    created = []
    for change in changes:
        device_id = None
        if change.device_key:
            device = db.scalar(
                select(models.Device).where(models.Device.user_id == user.id, models.Device.device_key == change.device_key)
            )
            device_id = device.id if device else None
        event = models.SyncEvent(
            user_id=user.id,
            device_id=device_id,
            entity_type=change.entity_type,
            entity_id=change.entity_id,
            action=change.action,
            payload_json=json.dumps(change.payload),
        )
        db.add(event)
        created.append(event)
    db.commit()
    return {"accepted": len(created)}


@router.get("/pull", response_model=schemas.SyncPullResponse)
def pull_changes(
    cursor: int = 0,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    events = db.scalars(
        select(models.SyncEvent)
        .where(models.SyncEvent.user_id == user.id, models.SyncEvent.id > cursor)
        .order_by(models.SyncEvent.id)
        .limit(500)
    ).all()
    next_cursor = cursor if not events else events[-1].id
    return schemas.SyncPullResponse(
        cursor=next_cursor,
        events=[
            {
                "id": event.id,
                "entity_type": event.entity_type,
                "entity_id": event.entity_id,
                "action": event.action,
                "payload": json.loads(event.payload_json),
                "created_at": event.created_at.isoformat(),
            }
            for event in events
        ],
    )
