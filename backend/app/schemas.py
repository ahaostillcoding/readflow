from pydantic import BaseModel, ConfigDict, EmailStr


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserCreate(BaseModel):
    email: EmailStr
    password: str


class DeviceUpsert(BaseModel):
    device_key: str
    name: str
    platform: str


class FeedCreate(BaseModel):
    title: str
    url: str
    category: str = "Other"
    site_url: str | None = None
    description: str | None = None


class FeedOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    url: str
    category: str
    enabled: bool


class SyncChange(BaseModel):
    entity_type: str
    entity_id: str
    action: str
    payload: dict
    device_key: str | None = None


class SyncPullResponse(BaseModel):
    cursor: int
    events: list[dict]


class AiMetadataIn(BaseModel):
    entry_id: int
    summary: str | None = None
    tags: list[str] = []
    model: str | None = None
    content_hash: str | None = None
