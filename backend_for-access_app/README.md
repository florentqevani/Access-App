# backend_for-access_app

Node.js auth backend for the Flutter `access_app` project.

## Stack

- Express API
- PostgreSQL for persistent user/token storage
- Redis for cache and refresh-session lookup
- Firebase Admin SDK for `idToken` verification

## API used by Flutter

- `POST /auth/exchange` with `{ "idToken": "..." }`
- `POST /auth/refresh` with `{ "refreshToken": "..." }`
- `POST /auth/revoke` with `{ "refreshToken": "..." }`

## Docker Setup

1. Put Firebase service account JSON at:
   `secrets/firebase-service-account.json`
   Optional: if you skip this file, backend still starts and verifies Firebase
   ID token signatures, but token revocation checks are disabled.
2. Optional: edit `.env.docker` token secrets.
3. Start stack:

```bash
docker compose up --build
```

If using service account file with Docker, add this to `.env.docker`:

```bash
GOOGLE_APPLICATION_CREDENTIALS=/app/secrets/firebase-service-account.json
```

Backend will be on `http://localhost:3000`.

## Local Setup (without Docker)

1. Copy `.env.example` to `.env` and fill values.
2. Ensure Postgres + Redis are running.
3. Run:

```bash
npm install
npm run dev
```

## Flutter App Connection

`access_app` defaults to `http://10.0.2.2:3000` for Android emulator.

Override backend URL if needed:

```bash
flutter run --dart-define=AUTH_SERVER_BASE_URL=http://localhost:3000
```
