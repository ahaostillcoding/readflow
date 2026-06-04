# Development Log

## 2026-06-04

- Converted the architecture roadmap into tracked project work in `ROADMAP.md`.
- Repaired the local-first Flutter client structure and replaced corrupted UI strings.
- Added Saved, Search, Recommended, Novel, and Movie reading surfaces.
- Expanded SQLite with migration support, reading progress, AI metadata fields, and a local sync outbox.
- Added FastAPI backend skeleton for auth, devices, feeds, sync events, and AI metadata.
- Initialized Git repository so MVP milestones can be committed.
- Generated Flutter Windows and Android platform projects.
- Installed project-local Flutter SDK 3.44.1 under `.tooling/flutter`.
- Added Dockerfile and Docker Compose deployment for API + PostgreSQL.
- Added backend API tests and Flutter parser/OPML tests.
- Added client sync account MVP: API base URL, register, login, device registration, and manual outbox sync.
- Verified `flutter analyze` and `flutter test` from ASCII-path copy because Flutter analysis crashes on the original non-ASCII workspace path.
- Verified backend pytest and local `/health` smoke test.

### Environment blockers observed

- Windows build is blocked by missing Visual Studio C++ desktop toolchain.
- Android build is blocked by missing Android SDK. Automatic download from `dl.google.com` timed out in this environment.
- Docker deployment is blocked because Docker is not installed in PATH.
