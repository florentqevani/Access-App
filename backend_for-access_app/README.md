# backend_for-access_app

Node.js auth backend for the Flutter `access_app` project.

## Stack

- Express API
- PostgreSQL for persistent user/token storage
- Redis for cache and refresh-session lookup
- JWT access + refresh tokens

## API used by Flutter

- `POST /auth/signup` with `{ "name", "email", "password" }`
- `POST /auth/login` with `{ "email", "password" }`
- `POST /auth/refresh` with `{ "refreshToken": "..." }`
- `POST /auth/revoke` with `{ "refreshToken": "..." }`
- `PATCH /auth/change-password` with `{ "currentPassword", "newPassword" }`
- `GET /users/logs/role-scoped` for role-based log visibility

## Docker Setup

1. Optional: edit `.env.docker` token secrets.
2. Start stack:

```bash
docker compose up --build
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
