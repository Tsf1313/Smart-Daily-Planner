# Backend

Node.js/Express API with Firebase token verification and MySQL migration/seed support.

## Requirements

- ## Requirements

- Node.js 18 or newer
- npm
- MySQL 8 or newer
- Firebase project and Admin credentials

## Run locally

```powershell
Copy `.env.example` to `.env` and replace placeholders. Never commit `.env`.

```powershell
npm install
npm run migrate
npm run seed
npm start
```

Create the database first:

```sql
CREATE DATABASE smart_daily_planner CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'sdp'@'localhost' IDENTIFIED BY 'change-me';
GRANT ALL PRIVILEGES ON smart_daily_planner.* TO 'sdp'@'localhost';
```

Firebase Admin credentials can be supplied with `FIREBASE_SERVICE_ACCOUNT` as JSON or through
`GOOGLE_APPLICATION_CREDENTIALS`. `FIREBASE_PROJECT_ID` is a development guard; production should
configure Firebase Admin credentials explicitly.
```

The server listens on port `3000` by default. Set `PORT` to use another port.
Check health:

```powershell
Invoke-RestMethod http://localhost:3000/health
```

Example authenticated requests:

```powershell
$headers = @{ Authorization = "Bearer $env:FIREBASE_ID_TOKEN" }
Invoke-RestMethod -Method Get -Headers $headers http://localhost:3000/api/v1/me
Invoke-RestMethod -Method Post -Headers $headers -ContentType "application/json" `
  -Body '{"kind":"deadline","title":"Submit MAD report","dueAt":"2026-11-25T09:00:00Z"}' `
  http://localhost:3000/api/v1/entries
Invoke-RestMethod -Method Post -Headers $headers -ContentType "multipart/form-data" `
  -InFile ".\photo.jpg" `
  http://localhost:3000/api/v1/photos
```

The exact contract is in `../docs/backend-api-contract-proposal.md`.

## Test

```powershell
npm test
```

The current test store is in memory. Production MySQL repository adapters are not yet connected;
run migration commands against MySQL before deploying database-backed work.
