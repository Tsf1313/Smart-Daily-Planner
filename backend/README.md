# Planner backend

<<<<<<< HEAD
Node.js/Express API with Firebase token verification and MySQL migration/seed support.

## Requirements

- ## Requirements

- Node.js 18 or newer
- npm
- MySQL 8 or newer
- Firebase project and Admin credentials
=======
This first planner milestone creates and lists student deadlines. It uses Express, MySQL 8 and Firebase Authentication. Dates represent calendar days and have no time or timezone.
>>>>>>> 81dc15830990c3536e7160733ff99fbc99efbdae

## Run locally

1. Install Node.js 22 or newer. In the backend folder run `npm ci` and `npm test`. The HTTP tests inject authentication and storage doubles.
2. Create a MySQL database named `smart_daily_planner`. Open `sql/001_deadlines.sql` in MySQL Workbench, select the database as the default schema and execute the script. Give the API's database user SELECT and INSERT access to the table.
3. Use Firebase Application Default Credentials for the same Firebase project used by the mobile app. For local development keep the service account file outside the repository. The service account needs permission to read Firebase Auth users for disabled-account and revocation checks.
4. In the same PowerShell terminal set the connection details and start the server. Percent-encode special characters in the MySQL URL credentials.

```powershell
<<<<<<< HEAD
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
=======
$env:MYSQL_URL = "mysql://planner_user:PASSWORD@localhost:3306/smart_daily_planner"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\private\planner-service-account.json"
npm start
```

## Mobile API contract
>>>>>>> 81dc15830990c3536e7160733ff99fbc99efbdae

Send a Firebase ID token from the signed-in user's client in the Authorization header. The API derives ownership from that token. In PowerShell the following commands assume that $token holds a test student's Firebase ID token.

```powershell
$headers = @{ Authorization = "Bearer $token" }
$url = "http://localhost:3000/api/v1/entries"
$body = @{kind="deadline"; title="Submit MAD report"; dueDate="2026-11-30"} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType "application/json" -Body $body
Invoke-RestMethod -Uri "${url}?from=2026-11-01&to=2026-11-30" -Headers $headers
```

<<<<<<< HEAD
The current test store is in memory. Production MySQL repository adapters are not yet connected;
run migration commands against MySQL before deploying database-backed work.
=======
POST returns 201 with the created entry under data, including its server-generated id. Titles allow 1–200 characters after trimming. GET returns 200 with an array under data ordered by dueDate and id. Both date filters are optional and inclusive. Validation errors return 400. Missing, revoked or invalid tokens return 401. Firebase-disabled accounts receive 403. GET /health checks the HTTP process only.

For a live smoke test, save an entry, restart Node and list it with the same student's token. Repeat the listing with another student's token to check account isolation.
>>>>>>> 81dc15830990c3536e7160733ff99fbc99efbdae
