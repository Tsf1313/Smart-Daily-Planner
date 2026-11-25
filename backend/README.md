# Planner backend

The Express API verifies Firebase ID tokens and uses MySQL for normal application
storage. Automated tests inject the in-memory store.

## Run locally

1. Install Node.js 22 or newer and run `npm ci` in this directory.
2. Create the database and application user:

   ```sql
   CREATE DATABASE smart_daily_planner CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'sdp'@'localhost' IDENTIFIED BY 'change-me';
   GRANT ALL PRIVILEGES ON smart_daily_planner.* TO 'sdp'@'localhost';
   ```
3. Copy `.env.example` to `.env`. Set the MySQL connection values and Firebase
   Admin credentials. Keep `.env` and service-account credentials out of Git.
4. Run `npm run migrate`, then `npm start`.

The server checks MySQL before listening. It does not fall back to memory if the
database is missing or unavailable; startup fails with a connection error.

Configure MySQL either with `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` and
`DB_NAME`, or with `MYSQL_URL`. Special characters in URL credentials must be
percent-encoded. Firebase Admin accepts `FIREBASE_SERVICE_ACCOUNT` as JSON or
`GOOGLE_APPLICATION_CREDENTIALS` as a file path.

## Entries API

All requests use `Authorization: Bearer <Firebase ID token>`. Ownership is
derived from the verified token.

The dashboard can load all of the signed-in student's deadlines without date
filters:

```http
GET /api/v1/entries
```

The response is `200` with a `data` array containing only `id`, `title` and
date-only `dueDate` fields. An empty deadline list is returned as `{"data":[]}`.
Deadlines written by the earlier `planner_deadlines` schema remain visible;
new deadlines are stored in the unified `entries` table.

Create a deadline with a calendar date:

```json
{
  "kind": "deadline",
  "title": "Submit MAD report",
  "dueDate": "2026-11-30"
}
```

The existing timestamp-based `dueAt` form and routine entry contract remain
supported. Date-range `GET /api/v1/entries?from=...&to=...` requests continue to
support deadlines and routines; bounds may be date-only or ISO 8601 timestamps.

## Tests

Run `npm test`. The API tests use the in-memory store and do not require MySQL or
Firebase credentials. To enable the restart/owner-isolation integration test,
set `MYSQL_TEST_URL` to a separate test database, apply migrations to it, and
rerun `npm test`.
