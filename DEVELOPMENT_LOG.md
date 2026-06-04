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
- Installed Visual Studio Build Tools 2022 and verified Windows debug build from ASCII-path copy:
  `C:\readflow_mvp_check2\build\windows\x64\runner\Debug\readflow.exe`.
- Installed Android command-line tools, SDK 36, Build Tools 36/35/28, CMake 3.22.1, and JDK 17.
- Verified Android debug APK build from ASCII-path copy:
  `C:\readflow_android_check\build\app\outputs\flutter-apk\app-debug.apk`.
- Removed the Android-blocking `file_picker` plugin from the MVP build. OPML parsing and generation remain covered by tests; OPML file import/export now returns a clear unsupported message until a compatible file picker is reintroduced.
- Updated Android build configuration for AGP 9-era tooling: core library desugaring, lower Gradle heap usage, SDK 36 support, and Workmanager 0.9 API compatibility.

### Environment blockers observed

- Docker Desktop installation is blocked by the host OS version. Docker Desktop requires Windows 10 22H2 build 19045 or newer, while this machine reports Windows 10 Enterprise LTSC 2021 build 19044.
- Flutter Windows and Android builds must be executed from an ASCII-only project path on this machine. The original workspace path contains non-ASCII characters and causes Windows/Gradle/Flutter path encoding failures.
