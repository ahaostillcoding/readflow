from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import get_current_user

router = APIRouter(prefix="/feeds", tags=["feeds"])


@router.get("", response_model=list[schemas.FeedOut])
def list_feeds(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.scalars(select(models.Feed).where(models.Feed.user_id == user.id).order_by(models.Feed.category, models.Feed.title)).all()


@router.post("", response_model=schemas.FeedOut)
def create_feed(payload: schemas.FeedCreate, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    feed = models.Feed(
        user_id=user.id,
        title=payload.title,
        url=payload.url,
        site_url=payload.site_url,
        description=payload.description,
        category=payload.category,
        updated_at=datetime.utcnow(),
    )
    db.add(feed)
    db.commit()
    db.refresh(feed)
    return feed


@router.patch("/{feed_id}", response_model=schemas.FeedOut)
def update_feed(feed_id: int, payload: schemas.FeedCreate, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    feed = db.get(models.Feed, feed_id)
    if feed is None or feed.user_id != user.id:
        raise HTTPException(status_code=404, detail="Feed not found")
    feed.title = payload.title
    feed.url = payload.url
    feed.site_url = payload.site_url
    feed.description = payload.description
    feed.category = payload.category
    feed.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(feed)
    return feed


@router.delete("/{feed_id}")
def delete_feed(feed_id: int, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    feed = db.get(models.Feed, feed_id)
    if feed is None or feed.user_id != user.id:
        raise HTTPException(status_code=404, detail="Feed not found")
    db.delete(feed)
    db.commit()
    return {"deleted": True}
