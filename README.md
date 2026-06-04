# ReadFlow

ReadFlow is a local-first RSS reader MVP for Windows and Android. It uses Flutter on the client, SQLite for offline storage, and a FastAPI backend for account-based sync.

## MVP Features

- Windows and Android Flutter clients.
- RSS 2.0, Atom, and common RDF feed parsing.
- Add, preview, edit, enable/disable, delete, and refresh feeds.
- Article list, category filters, unread/favorite/read-later filters.
- Article detail reader with HTML rendering and reading progress.
- Local search across title, summary, cached content, AI fields, and source.
- Favorite and read-later support.
- SQLite local storage with migrations.
- OPML import/export.
- Sync account MVP: register, login, device registration, and manual outbox sync.
- Backend API with auth, devices, feeds, sync events, and AI metadata placeholders.
- Docker Compose deployment for API + PostgreSQL.

## Project Structure

```text
lib/
  core/                 Shared database, models, networking, sync, theme
  features/             Modular feature packages
backend/
  app/                  FastAPI application
  tests/                Backend API tests
android/                Flutter Android platform
windows/                Flutter Windows platform
test/                   Flutter unit tests
tool/                   Local bootstrap helpers
```

## Local Flutter SDK

This workspace can use a project-local Flutter SDK at `.tooling/flutter`.

```powershell
git clone --depth 1 -b stable https://github.com/flutter/flutter.git .tooling\flutter
.\.tooling\flutter\bin\flutter.bat pub get
```

Generate platform projects if needed:

```powershell
.\.tooling\flutter\bin\flutter.bat create --platforms=windows,android .
```

## Client Commands

Because the current workspace path contains non-ASCII characters, `flutter analyze` may crash in this Flutter version. Use an ASCII-path copy for verification:

```powershell
$target = 'C:\readflow_mvp_check'
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
New-Item -ItemType Directory -Force -Path $target | Out-Null
robocopy . $target /E /XD .git .tooling .dart_tool build ephemeral .gradle backend\.venv /XF readflow_dev.db *.log
D:\Codex项目文件\RSS订阅\.tooling\flutter\bin\flutter.bat analyze
D:\Codex项目文件\RSS订阅\.tooling\flutter\bin\flutter.bat test
```

Build commands:

```powershell
.\.tooling\flutter\bin\flutter.bat build windows
.\.tooling\flutter\bin\flutter.bat build apk --debug
```

Windows builds require Visual Studio with the “Desktop development with C++” workload. Android builds require Android SDK command-line tools and a compatible JDK.

## Backend Commands

```powershell
python -m venv backend\.venv
.\backend\.venv\Scripts\python.exe -m pip install -r backend\requirements.txt
.\backend\.venv\Scripts\python.exe -m pytest
```

Run the API locally:

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Health check:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

## Docker Deployment

Docker Compose runs the API and PostgreSQL:

```powershell
docker compose up --build
```

Then verify:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

## Current Verification

Verified in this workspace:

- Flutter SDK installed locally: Flutter 3.44.1.
- `flutter analyze` passed from ASCII-path verification copy.
- `flutter test` passed: RSS parser and OPML tests.
- Backend dependencies installed in `backend/.venv`.
- Backend pytest passed.
- Backend local smoke test passed: `/health` returned `{"status":"ok"}`.

Blocked by machine-level tools:

- Windows build reaches the Flutter build stage but fails because Visual Studio C++ toolchain is not installed.
- Android build reaches the Flutter build stage but fails because Android SDK is not installed.
- Docker deployment cannot be executed until Docker Engine / Docker Desktop is installed and running.
