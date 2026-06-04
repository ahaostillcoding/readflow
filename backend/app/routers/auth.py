from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import get_current_user
from ..security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=schemas.TokenResponse)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.scalar(select(models.User).where(models.User.email == payload.email.lower()))
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
    user = models.User(email=payload.email.lower(), password_hash=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return schemas.TokenResponse(access_token=create_access_token(str(user.id)))


@router.post("/login", response_model=schemas.TokenResponse)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.scalar(select(models.User).where(models.User.email == form.username.lower()))
    if user is None or not verify_password(form.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")
    return schemas.TokenResponse(access_token=create_access_token(str(user.id)))


@router.post("/devices")
def upsert_device(
    payload: schemas.DeviceUpsert,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    device = db.scalar(
        select(models.Device).where(models.Device.user_id == user.id, models.Device.device_key == payload.device_key)
    )
    if device is None:
        device = models.Device(user_id=user.id, device_key=payload.device_key, name=payload.name, platform=payload.platform)
        db.add(device)
    else:
        device.name = payload.name
        device.platform = payload.platform
        device.last_seen_at = datetime.utcnow()
    db.commit()
    db.refresh(device)
    return {"id": device.id, "device_key": device.device_key}
