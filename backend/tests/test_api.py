from uuid import uuid4

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_register_login_and_feed_flow():
    email = f"reader-{uuid4().hex}@example.com"
    password = "secret-password"

    register = client.post("/auth/register", json={"email": email, "password": password})
    assert register.status_code in {200, 409}

    login = client.post("/auth/login", data={"username": email, "password": password})
    assert login.status_code == 200
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    device = client.post(
        "/auth/devices",
        headers=headers,
        json={"device_key": "test-device", "name": "Test Device", "platform": "windows"},
    )
    assert device.status_code == 200

    created = client.post(
        "/feeds",
        headers=headers,
        json={"title": "Example", "url": "https://example.com/rss.xml", "category": "News"},
    )
    assert created.status_code == 200

    feeds = client.get("/feeds", headers=headers)
    assert feeds.status_code == 200
    assert any(feed["url"] == "https://example.com/rss.xml" for feed in feeds.json())

    pushed = client.post(
        "/sync/push",
        headers=headers,
        json=[
            {
                "entity_type": "entry",
                "entity_id": "1",
                "action": "set_favorite",
                "payload": {"isFavorite": True},
                "device_key": "test-device",
            }
        ],
    )
    assert pushed.status_code == 200
    assert pushed.json()["accepted"] == 1

    pulled = client.get("/sync/pull?cursor=0", headers=headers)
    assert pulled.status_code == 200
    assert pulled.json()["events"]
