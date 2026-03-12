# Access App

`access_app` is a Flutter client backed by a local Node.js authorization service. The project models a small role-based access control system with email/password authentication, JWT session issuance, PostgreSQL persistence, Redis-backed token/session caching, and UI modules that expose behavior based on effective permission scope.

This repository contains both the client and the backend so the full stack can be developed, tested, and run locally.

## System Overview

The application is split into two runtime surfaces:

- Flutter client in [`lib/`](./lib/) for authentication, dashboard navigation, user management, reports, logs, and self-service settings
- Express backend in [`backend_for-access_app/`](./backend_for-access_app/) for auth, RBAC enforcement, audit logs, and persistence

At a high level, the flow is:

1. A user signs up or logs in from the Flutter app.
2. The backend validates credentials and issues an access token plus refresh token.
3. The Flutter app stores the authenticated session in memory and uses the JWT/user payload to gate UI access.
4. Protected backend endpoints enforce permissions again server-side via authentication and permission middleware.
5. Sensitive actions are written to the audit log.

## Architecture

### Frontend

The Flutter client uses a lightweight layered structure:

- `presentation/` for screens and Bloc-based state handling
- `domain/` for use cases and repository contracts
- `data/` for remote data sources and repository implementations
- `core/` for shared concerns such as theme, errors, and backend URL resolution

Key UI modules:

- Login and signup
- Dashboard with role-aware module visibility
- Users dashboard and CRUD/role management flows
- Reports page with a dummy generated report and export action
- Logs page for manager/admin audit visibility
- Settings page for profile updates and password changes

State management is intentionally simple:

- `flutter_bloc` handles auth events and auth state transitions
- feature actions outside auth mostly execute use cases directly from the screen layer
- Dio is used as the HTTP client, with explicit response handling for non-2xx server responses

### Backend

The backend is a single Express service with the following responsibilities:

- email/password signup and login
- JWT access/refresh token issuance and refresh-token revocation
- RBAC enforcement through middleware
- Postgres-backed users, roles, permissions, refresh tokens, and audit logs
- Redis-backed user/session caching
- automatic schema migration and seed-on-start behavior

Important backend characteristics:

- schema migrations run automatically at startup via `runMigrations()`
- roles and permissions are seeded by the migration layer
- refresh tokens are persisted in Postgres and cached in Redis
- audit logs are written for protected user-management and reporting actions

## Repository Layout

```text
access_app/
  lib/
    core/
    data/
    domain/
    presentation/
  test/
  backend_for-access_app/
    src/
      config/
      controllers/
      data/
      db/
      middleware/
      routes/
      rbac/
```

Important entry points:

- Flutter bootstrap: [`lib/main.dart`](./lib/main.dart)
- Auth client transport: [`lib/data/data_source/remote_data_source_impl.dart`](./lib/data/data_source/remote_data_source_impl.dart)
- User/access transport: [`lib/data/data_source/user_access_remote_data_source_impl.dart`](./lib/data/data_source/user_access_remote_data_source_impl.dart)
- Backend server bootstrap: [`backend_for-access_app/src/index.js`](./backend_for-access_app/src/index.js)
- Auth routes: [`backend_for-access_app/src/routes/auth_routes.js`](./backend_for-access_app/src/routes/auth_routes.js)
- User/RBAC routes: [`backend_for-access_app/src/routes/users_route.js`](./backend_for-access_app/src/routes/users_route.js)
- Schema + seed logic: [`backend_for-access_app/src/db/migrate.js`](./backend_for-access_app/src/db/migrate.js)

## Auth and RBAC Model

### Authentication

The active backend implementation is email/password based.

Auth endpoints:

- `POST /auth/signup`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/revoke`
- `PATCH /auth/change-password`

The backend returns:

- `accessToken`
- `refreshToken`
- access/refresh expirations
- authenticated user payload including role and permissions

The Flutter client converts that response into `AuthSession` and `AuthUser` domain models and uses them to drive UI access.

### Roles and scopes

The system seeds these role names:

- `admin`
- `manager`
- `user`
- `guest`

Permissions are scope-based. The migration layer and middleware support:

- `none`
- `own`
- `team`
- `limited`
- `full`

This is important because the UI is permission-aware, but the backend remains authoritative. A visible screen does not imply write access; the server still validates the requested action and scope.

### Protected resource areas

The current app models permissions around:

- `dashboard:view`
- `users:read`
- `users:create`
- `users:edit`
- `users:delete`
- `roles:manage`
- `reports:read`
- `reports:export`
- `audit_logs:view`
- `settings:configure`

## Feature Surface

### Users module

The users module supports:

- list users with scope-aware filtering
- create users
- update users
- delete users
- change user role
- reset passwords

User-management affordances are also filtered in the client, so lower-privilege roles do not see admin-only entry points.

### Reports module

The reports page currently exposes a generated dummy report. Export-capable roles can trigger a backend `reports:export` action and save the generated report content locally from the client.

### Logs module

The logs screen is restricted to admin/manager behavior in the client and backed by role-aware server endpoints. The backend records access and mutating actions to the audit log store.

### Settings module

Users can:

- update display name
- change password

Roles with `settings:configure` can also execute protected settings actions.

## API Surface Used by the Client

Core endpoints consumed by the Flutter app:

### Auth

- `POST /auth/signup`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/revoke`
- `PATCH /auth/change-password`

### Users and access

- `GET /users`
- `GET /users/roles`
- `PATCH /users/:userId`
- `DELETE /users/:userId`
- `PATCH /users/:userId/role`
- `POST /users/:userId/password/reset`
- `POST /users/actions/execute`
- `GET /users/logs/role-scoped`
- `PATCH /users/me/profile`

The auth client is tolerant of several auth path aliases such as `/login`, `/signin`, and `/sign-in` to make local backend path changes less brittle during development.

## Local Development

### Prerequisites

- Flutter SDK compatible with Dart `^3.11.0`
- Docker Desktop for the recommended stack
- or local Node.js + PostgreSQL + Redis if running the backend without Docker

### Recommended: run backend with Docker

From the backend directory:

```bash
cd backend_for-access_app
docker compose up --build
```

This starts:

- Postgres on `localhost:5432`
- Redis on `localhost:6379`
- backend API on `localhost:3000`

The Docker path is the most reliable way to run this project because it guarantees the expected database credentials, Redis configuration, and backend port.

### Run the Flutter app

From the repository root:

```bash
flutter pub get
flutter run
```

Backend URL defaults:

- Android emulator: `http://10.0.2.2:3000`
- Web/Desktop/iOS simulator: `http://localhost:3000`

Override explicitly when needed:

```bash
flutter run --dart-define=AUTH_SERVER_BASE_URL=http://localhost:3000
```

### Run backend without Docker

From [`backend_for-access_app/`](./backend_for-access_app/):

1. Copy `.env.example` to `.env`
2. Set valid values for `DATABASE_URL`, `REDIS_URL`, and token secrets
3. Ensure Postgres and Redis are reachable
4. Start the server

```bash
npm install
npm run dev
```

Important note:

- the local `.env` must match the current backend implementation
- if `.env` still contains legacy/unused configuration from older auth approaches, local startup may succeed partially but runtime behavior will not match the current client/backend contract

## Migrations and Data Bootstrapping

The backend performs schema creation and RBAC seeding automatically on startup.

Current tables created by migration logic include:

- `roles`
- `permissions`
- `role_permissions`
- `users`
- `refresh_tokens`
- `logs`

The migration code also contains compatibility handling for older audit-log table layouts.

## Engineering Notes

### Error handling

The client explicitly normalizes server errors instead of relying on raw Dio exceptions. This is important because it keeps API validation failures in normal UI state paths instead of surfacing uncaught HTTP exceptions.

### Authorization strategy

There is intentional duplication between:

- client-side visibility logic
- server-side authorization enforcement

That is by design. The client hides actions that the user should not reach, while the backend remains the trust boundary.

### Data consistency

Role and permission definitions live on the backend, not in the Flutter app. The Flutter app consumes the effective permission set returned by the server and derives available actions from it.

## Verification and Quality Gates

Typical local checks:

```bash
flutter analyze
flutter test
```

Backend smoke checks:

```bash
cd backend_for-access_app
docker compose ps
curl http://localhost:3000/health
```

## Troubleshooting

### The app cannot reach the backend

Check:

- backend container is running on port `3000`
- Android emulator uses `10.0.2.2`, not `localhost`
- `AUTH_SERVER_BASE_URL` is set correctly for the active platform

### Signup or login returns 404

This usually means the running backend process does not match the current source tree. Rebuild the backend image/container and verify the live server exposes `/auth/signup` and `/auth/login`.

### Postgres auth fails locally

If you are not using Docker, confirm that your `.env` matches the current backend config and that `DATABASE_URL` points to a database with the expected credentials.

### UI allows navigation but backend rejects the action

This indicates client visibility and server authority are out of sync. Inspect:

- the role/permission seed data
- the authenticated user payload returned at login
- backend middleware checks in `users_route.js`

## Current Status

The project is suitable for local development and demo environments. It demonstrates:

- end-to-end auth/session handling
- RBAC-driven UI behavior
- protected CRUD-style user workflows
- audit logging
- local full-stack execution via Docker

It is not yet positioned as a production-hardened deployment. Areas such as secret management, deployment topology, observability, and stronger automated backend test coverage would need to be expanded before treating it as production-ready.
