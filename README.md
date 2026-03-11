# Access_app

Flutter authentication app with Firebase Auth on the client and a local Node.js auth backend.

## Tech Stack

- Flutter (Dart)
- Firebase Auth + Firebase Core
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
- Firebase project configured for your target platforms
- (Optional, for full auth flow) Docker or local Node.js + PostgreSQL + Redis

## Flutter Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Ensure Firebase platform config files are present.
   If missing, run FlutterFire setup:

```bash
flutterfire configure
```

3. Run the app:

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

