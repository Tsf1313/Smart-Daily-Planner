# Backend

This is the initial Node.js/Express scaffold. It currently provides an internal
health check at `GET /health`; application routes, persistence, and
authentication are intentionally not implemented.

## Requirements

- Node.js 18 or newer
- npm

## Run locally

```powershell
npm install
npm start
```

The server listens on port `3000` by default. Set `PORT` to use another port.
Check that it is running with `Invoke-RestMethod http://localhost:3000/health`.

## Test

```powershell
npm test
```

MySQL, Firebase Authentication, API contracts, and configuration are pending
team confirmation; add them only after the shared agreement is approved.
