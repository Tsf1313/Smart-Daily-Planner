# Backend API contract

This contract follows [team-development-agreement.md](./team-development-agreement.md).

**Status:** Team-agreed routes and fields in this contract. Endpoint status is explicitly labeled below.

Base URL: `/api/v1`

Protected requests require `Authorization: Bearer <Firebase ID token>`.

## Response and error formats

Success: `{ "data": {} }`

List: `{ "data": { "items": [], "page": 1, "pageSize": 20, "total": 0 } }`

Error:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Please check the submitted fields.",
    "details": { "title": "Title is required." }
  }
}
```

`GET /health` is public and returns `{ "status": "ok" }`.

## Endpoint status

| Method and route | Status | Purpose |
| --- | --- | --- |
| `GET /health` | Implemented | Health check |
| `GET /api/v1/me` | Implemented | Get/create profile |
| `PATCH /api/v1/me` | Implemented | Update name |
| `POST /api/v1/entries` | Implemented | Create deadline/routine |
| `GET /api/v1/entries?from=&to=&page=&pageSize=` | Implemented | List owned entries; range max 31 days |
| `GET /api/v1/entries/{id}` | Implemented | View owned entry |
| `PATCH /api/v1/entries/{id}` | Implemented | Edit owned entry |
| `DELETE /api/v1/entries/{id}` | Implemented | Delete owned entry |
| `PUT /api/v1/entries/{id}/completion` | Implemented | Set deadline completion |
| `GET /api/v1/routine-occurrences?from=&to=` | Implemented | List owned occurrences; range max 31 days |
| `PUT /api/v1/routine-occurrences/{id}/completion` | Implemented | Set occurrence completion |
| `GET /api/v1/facilities?latitude=&longitude=&radiusMeters=5000` | Implemented | Search active facilities nearest first |
| `POST /api/v1/photos` | Implemented | Upload JPEG/PNG, max 5 MB |
| `GET /api/v1/photos/{id}` | Implemented | Return owned image content |
| `DELETE /api/v1/photos/{id}` | Implemented | Delete unreferenced owned photo |
| `GET /api/v1/admin/users?search=&page=&pageSize=` | Implemented | List/search accounts |
| `PATCH /api/v1/admin/users/{id}/status` | Implemented | Suspend/reactivate account |
| `GET /api/v1/admin/facilities?active=` | Implemented | List facilities |
| `POST /api/v1/admin/facilities` | Implemented | Create facility |
| `PATCH /api/v1/admin/facilities/{id}` | Implemented | Edit/deactivate facility |
| `GET /api/v1/admin/actions?targetId=` | Implemented | List admin action history |

## Profile

`GET /api/v1/me` creates a student profile on first successful Firebase verification.

```json
{
  "data": {
    "id": "application-profile-id",
    "firebaseUid": "firebase-uid",
    "name": "Student",
    "email": "student@example.test",
    "role": "student",
    "status": "active",
    "createdAt": "2026-11-24T09:30:00.000Z",
    "updatedAt": "2026-11-24T09:30:00.000Z"
  }
}
```

`PATCH /api/v1/me` accepts only `{ "name": "Student Name" }`; name is required, trimmed, and 1–100 characters.

## Entries

Deadline creation:

```json
{
  "kind": "deadline",
  "title": "Submit MAD report",
  "description": "Upload the final PDF",
  "timeZone": "Asia/Kuala_Lumpur",
  "dueAt": "2026-11-25T09:00:00Z",
  "reminderMinutes": 30,
  "location": null,
  "photoId": null
}
```

Routine creation:

```json
{
  "kind": "routine",
  "title": "Study",
  "description": null,
  "timeZone": "Asia/Kuala_Lumpur",
  "startDate": "2026-11-25",
  "startTime": "20:00",
  "endTime": "21:00",
  "repeat": "weekly",
  "weekdays": [1, 3, 5],
  "repeatUntil": null,
  "reminderMinutes": 15,
  "location": null,
  "photoId": null
}
```

Creation may not submit `id`, `ownerId`, `createdAt`, or `updatedAt`.

PATCH uses omission for unchanged fields and `null` to clear nullable fields. `kind` cannot change.

Deadline completion body:

```json
{ "isCompleted": true }
```

Occurrence completion body:

```json
{ "isCompleted": false }
```

`GET /api/v1/routine-occurrences` returns:

```json
{
  "data": {
    "items": [
      {
        "id": "occurrence-id",
        "entryId": "routine-entry-id",
        "date": "2026-11-25",
        "startAt": "2026-11-25T12:00:00.000Z",
        "endAt": "2026-11-25T13:00:00.000Z",
        "isCompleted": false
      }
    ]
  }
}
```

## Facilities and photos

Facility search response items contain `facilityId`, `name`, `latitude`, `longitude`, and `distanceMeters`. Default radius is 5,000 metres; maximum is 50,000 metres.

Create facility:

```json
{
  "name": "Sample Campus Library",
  "latitude": 2.3,
  "longitude": 111.8,
  "isActive": true
}
```

Upload uses multipart/form-data with field name `file`. Maximum size: 5 MB. The route returns:

```json
{ "data": { "id": "photo-id", "mimeType": "image/png", "sizeBytes": 1234, "createdAt": "2026-11-24T09:30:00.000Z" } }
```

Photo content is returned as its image MIME type, not a JSON envelope.

## Admin

Suspend/reactivate:

```json
{ "status": "suspended" }
```

An admin cannot suspend or reactivate their own account.

## Error status codes

- `400` `VALIDATION_ERROR`
- `401` `UNAUTHENTICATED`
- `403` `ACCOUNT_SUSPENDED` or `FORBIDDEN`
- `404` `NOT_FOUND`
- `409` `CONFLICT`
- `413` `UPLOAD_TOO_LARGE`
- `415` `UNSUPPORTED_MEDIA_TYPE`
- `500` `INTERNAL_ERROR`
