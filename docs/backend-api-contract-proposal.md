# Backend API and data-contract proposal

**Status:** Draft for team review; nothing in this document is agreed or implemented.

**Scope:** Stage 1 shared agreement for the backend.
**Basis:** The repository currently has no team contract in `docs/`, and the mobile app is an uncustomized Flutter starter. The two referenced MAD instruction PDFs were not present in the workspace when this draft was prepared.

Do not treat the suggested names, routes, or formats below as final. Confirm them with the owners listed in the review checklist before creating the backend project, schema, or API.

## Proposed baseline

- One versioned REST API, rooted at `/api/v1`, shared by Flutter and the admin website.
- Proposed stack: Node.js, Express, MySQL, and Firebase Authentication, with Firebase ID-token verification by the API. Confirm the stack as a team before adding dependencies.
- Every authenticated request is associated with an application profile. The server derives the Firebase UID and profile from the verified token; clients do not choose an `ownerId`.
- A user may access or change only their own entries, routine occurrences, and photos. Super Admin operations require a server-checked role. Suspended accounts are denied ordinary authenticated operations until reactivated.
- Suggested success response: JSON `{ "data": ... }`. Suggested error response: JSON `{ "error": { "code": "...", "message": "...", "details": ... } }`. Confirm response envelopes, error codes, and pagination before clients depend on them.
- Timestamps should use ISO 8601 with an explicit UTC offset. Whether schedule values also store an IANA timezone needs team agreement.

## Entry and routine model proposal

Suggested shared entry fields:

| Field | Suggested meaning |
| --- | --- |
| `id` | Server-issued stable entry identifier |
| `ownerId` | Server-owned application-profile identifier; never trusted from a write request |
| `kind` | `deadline` or `routine` |
| `title` | Required display title |
| `description` | Optional text |
| `createdAt`, `updatedAt` | Server-managed timestamps |

Deadline-specific fields, schedule/reminder settings, routine recurrence fields, enumerations, nullability, and validation limits remain open. SHAHDAYANA and TSF should confirm the actual model and field names against the mobile/admin needs before implementation.

Routine completion should be recorded per occurrence, not by marking the routine template complete. The API needs a bounded occurrence query (suggested shape: `from` and `to` date-time query parameters) and a stable occurrence identifier. SHAHDAYANA and the backend owner must agree whether IDs are generated from the routine plus scheduled time or stored as server-issued records, and how timezone/DST changes affect them.

## First journey endpoint sketch

These are proposals to review, not client-ready contracts:

| Operation | Suggested route | Purpose |
| --- | --- | --- |
| Get current profile | `GET /api/v1/me` | Return the authenticated application profile and permitted capabilities |
| Create a deadline | `POST /api/v1/entries` | Create an owned deadline |
| List schedule entries | `GET /api/v1/entries?from=...&to=...` | Return only the caller's entries in the requested date range |
| Complete a deadline | `POST /api/v1/entries/{entryId}/completion` | Complete an owned deadline |
| List routine occurrences | `GET /api/v1/routines/{routineId}/occurrences?from=...&to=...` | Return occurrences in a bounded range |
| Complete a routine occurrence | `POST /api/v1/routines/{routineId}/occurrences/{occurrenceId}/completion` | Record completion for that occurrence only |

Confirm naming, methods, request and response schemas, validation errors, date-range bounds, and whether create/update/list operations need pagination before integration.

## Facility, photo, and reminder decisions

Dominic to confirm the service contract before implementation:

- Facility search inputs and outputs, including what “near UTS” means, supported filters, distance units, and empty-result behavior.
- Photo upload and access flow, accepted file constraints, authorization checks, storage response fields, and deletion behavior. Photo access must remain protected and ownership-checked.
- Reminder settings fields, validation, and how the API returns settings to mobile/web. Flutter owns local reminder scheduling; the API does not schedule local notifications.

No storage provider, upload protocol, radius, or reminder field names are selected in this draft.

## Super Admin proposal

Lim to confirm exact routes, payloads, response fields, and role rules for:

- Searching accounts.
- Suspending and reactivating accounts.
- Managing facilities.
- Reading administrative action history.

All such routes should be inaccessible to ordinary users and should record the acting administrator, target, action, and timestamp in an audit history. The exact audit schema, search filters, and suspension semantics remain pending Lim's confirmation.

## Review checklist before backend integration

- [ ] TSF and SHAHDAYANA agree on entry and routine fields, enum values, validation, API routes, and response/error formats.
- [ ] SHAHDAYANA and backend agree on routine occurrence generation, stable IDs, bounded date queries, and per-occurrence completion.
- [ ] Dominic confirms facility, photo, and reminder service inputs and outputs.
- [ ] Lim confirms Super Admin routes, permissions, and administrative action history.
- [ ] Team confirms the Node.js/Express, MySQL, and Firebase Authentication stack.
- [ ] Team confirms the shared contract is recorded and ready for client integration.

Until these items are confirmed, this proposal does not authorize creating backend dependencies, migrations, or implementation code.
