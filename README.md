# Access_app

Flutter authentication app with a local Node.js auth backend using PostgreSQL, JWT, and role-based permissions.

## Tech Stack

- Flutter (Dart)
- flutter_bloc (state management)
- Dio (HTTP client)
- Node.js backend in `backend_for-access_app/`

## Project Structure

```text
access_app/
  lib/                        Flutter app source
  backend_for-access_app/     Node.js auth backend
```

## Prerequisites

- Flutter SDK (compatible with Dart `^3.11.0`)
- Docker or local Node.js + PostgreSQL + Redis for backend auth

## Flutter Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Run the app:

```bash
flutter run
```

## Backend Setup (Optional but Recommended)

Backend is located in [`backend_for-access_app`](backend_for-access_app/README.md).

Quick start with Docker:

```bash
cd backend_for-access_app
docker compose up --build
```

Default backend URL expectations in Flutter:

- Android emulator: `http://10.0.2.2:3000`
- Web/Desktop/iOS simulator: `http://localhost:3000`

Override backend URL at run time:

```bash
flutter run --dart-define=AUTH_SERVER_BASE_URL=http://localhost:3000
```

## Useful Commands

```bash
flutter analyze
flutter test
```

