# Smart Daily Planner — Team Development Agreement

**Approved by:** TSF

**Version:** 1.0

**Date:** 24 November 2026

This document is the repository-wide development rule for AI agents and team members.

## Technology and ownership

- Mobile: Flutter Android, existing `lib/app/`, `lib/core/`, and `lib/features/<feature>/` structure.
- Application state: Cubit/BLoC pattern. Screens must call Cubits/repositories, never HTTP or SQL directly.
- Authentication: Firebase Authentication.
- Backend: Node.js and Express.
- Database: MySQL.
- Offline cache: SQLite in the phone.
- Admin: separate React web application.
- Maps: Dominic's `flutter_map` implementation using OpenStreetMap. Tile configuration and usage conditions require release verification.

## Shared entry model

An entry is either `deadline` or `routine`. The `id`, `ownerId`, `createdAt`, and `updatedAt` fields are server-managed; create requests must not submit them. `kind` cannot change after creation.

Common fields:

| Field | Type | Rule |
| --- | --- | --- |
| `id` | string | Created by backend |
| `ownerId` | string | Assigned from the authenticated profile |
| `kind` | `deadline` or `routine` | Cannot change |
| `title` | string | Required, trimmed, 1–100 characters |
| `description` | string or null | Optional, maximum 2,000 characters |
| `timeZone` | string | `Asia/Kuala_Lumpur` in version 1 |
| `reminderMinutes` | integer or null | `15`, `30`, or `null` for Off |
| `location` | object or null | Explicitly selected by the user |
| `photoId` | string or null | One uploaded photo per entry |
| `createdAt` | timestamp | Backend-managed UTC |
| `updatedAt` | timestamp | Backend-managed UTC |

### Deadline

- `dueAt` is required.
- `isCompleted` defaults to `false` and is changed only through the completion endpoint.
- An unfinished deadline is overdue after `dueAt`.

### Routine

Routines preserve local clock times and version 1 routines start and end on the same day.

- `startDate`: date string.
- `startTime` and `endTime`: local `HH:mm`.
- `endTime` must be later than `startTime`.
- `repeat`: `none`, `daily`, or `weekly`.
- `weekdays`: unique integers `1`–`7`, where Monday is `1`.
- `repeatUntil`: inclusive date string or `null`.
- Weekly routines require at least one weekday.
- None/daily routines use an empty `weekdays` array.
- None routines require `repeatUntil: null`.
- `repeatUntil` cannot precede `startDate`.

Completion belongs to each routine occurrence. Stable occurrence IDs are opaque server-generated strings. Editing a routine changes the series; historical completions remain and future affected occurrences are regenerated. Deleting a routine removes the series and occurrence records.

## Calendar and statistics

- Routines appear as time blocks; deadlines appear at their due date/time.
- Calendar range queries are bounded to 31 days.
- Range conventions: inclusive `from`, exclusive `to`.
- Completed entries remain visible.
- An unfinished routine occurrence is overdue after `endAt`.
- Overdue items remain visible but are excluded from dashboard upcoming items and completion-rate calculations.
- Completion rate is `completed items / (completed items + unfinished non-overdue items) * 100`.
- Count each routine occurrence separately. If the denominator is zero, show “No data”.

## Location and photo rules

Location objects contain `facilityId` (string or null), required `name` (maximum 150 characters), JSON number `latitude` in `-90` to `90`, and JSON number `longitude` in `-180` to `180`.

- Default facility radius is 5,000 metres; maximum is 50,000 metres.
- Facilities are nearest first and include `distanceMeters`.
- GPS/permission denial must not prevent manual location selection.
- Sample facilities must be labelled clearly.
- One photo per entry.
- Only JPEG or PNG; maximum 5 MB.
- Validate file type and actual content on mobile and backend.
- Upload using multipart field name `file`.
- Keep files outside public static access; only the owner may access or delete them.
- Removing/replacing a photo detaches and safely cleans up unused storage.

## Reminder rules

- Store `reminderMinutes` in the backend.
- Flutter schedules device notifications.
- Deadline reminder: `dueAt - reminderMinutes`.
- Routine reminder: occurrence `startAt - reminderMinutes`.
- Repeated saves replace existing notifications; completion, deletion, and Off cancel affected notifications.
- If the reminder time has passed, skip it and explain.
- Notification permission denial does not prevent saving.
- For recurring routines, schedule the next seven days and refresh on app open/resume or relevant entry changes.
- Logout cancels user pending notifications.

## Authentication and admin

- Firebase handles passwords; passwords must not be stored in MySQL.
- The backend verifies Firebase ID tokens and creates/maps application profiles.
- New profiles receive `student` role and `active` status.
- Clients cannot assign role or status.
- All protected operations enforce profile ownership.
- Suspended users cannot use protected application APIs.
- Super Admin accounts are provisioned only through controlled setup.
- Admin functions include account search/status changes, facility create/edit/deactivate, and action history.
- Admins cannot suspend themselves.
- Action history records acting admin, target, action, and timestamp.
- Students' task descriptions and photos must not be exposed to admins or other users.

## API conventions

- Base prefix: `/api/v1`.
- Protected requests use `Authorization: Bearer <Firebase ID token>`.
- Success responses use `{ "data": {} }`.
- Errors use `{ "error": { "code": "...", "message": "...", "details": ... } }`.
- IDs are strings.
- Timestamps are ISO 8601 UTC strings ending in `Z`.
- Date fields use `YYYY-MM-DD`.
- Optional empty values use `null`.
- PATCH omission means unchanged; `null` explicitly clears a nullable field.
- Lists use `data.items`.
- Paginated lists include `data.page`, `data.pageSize`, and `data.total`.
- Default page size is 20; maximum is 100.
- Backend validates every request and must not expose stack traces, tokens, or database details.

Error status codes: `400` invalid request, `401` missing/invalid authentication, `403` suspended/forbidden, `404` unavailable to the caller, `409` conflict, `413` upload too large, `415` unsupported file type, `500` unexpected server error.

The exact route and field contract is in [backend-api-contract-proposal.md](./backend-api-contract-proposal.md).

## Offline behaviour

Offline is read-only viewing of previously downloaded information.

- Cache successful entry/calendar responses in SQLite under the signed-in user's ID.
- Show an offline indicator and last successful refresh time.
- Disable mutations and upload while offline.
- Clear cache on logout or account change.
- A user with no cache sees “No saved data available offline.”
- Refresh after reconnecting.
- Cached notifications may still fire offline.
- There is no offline mutation queue and uncached photos/map tiles are not guaranteed offline.

## GitHub workflow

- `main` is the stable release; `develop` is shared integration; work occurs on feature branches.
- Open small PRs into `develop`, not directly into `main`.
- PR descriptions must state what changed, setup/run steps, tests and results, sample data, incomplete features/known limits, and contract changes.
- Start each feature from an updated clean `develop`.
- Never commit secrets, service-account keys, `.env` credentials, `node_modules`, or generated build folders.
- Mobile PRs must run `flutter analyze` and `flutter test`; backend PRs must run `npm test`; Lim coordinates test records.

## AI agent instructions

Read this agreement, repository instructions, the API contract, and relevant source before coding. Follow existing structure and names; do not invent alternative routes, fields, enums, or response formats. Coordinate shared-file changes with the feature owner. Enforce ownership and admin permissions in the backend. Run relevant checks and report actual results, incomplete work, and verification steps. Never claim an unrun test passed.
