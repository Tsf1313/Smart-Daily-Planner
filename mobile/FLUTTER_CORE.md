# Flutter Core on Android

Start on an up-to-date develop checkout that includes deadline API PR #4. Apply the mobile folder at repository root on your Flutter feature branch.

In Firebase, register the Android app with package name `com.group4.smart_daily_planner` in the project used by the API. Enable the Email/Password sign-in provider. Copy `config/android.example.json` to `config/android.local.json` inside mobile. Fill it with public Android client settings from the registered app. In google-services.json, these correspond to project_id, mobilesdk_app_id, current_key and project_number. Backend service account credentials belong only on the server.

Start the Express backend with the setup in backend/README.md, including its database table. In Android emulator debug builds, the default API URL reaches your computer through 10.0.2.2. Keep the trailing slash. For a hosted service, use its HTTPS /api/v1/ URL.

From mobile in PowerShell:

```powershell
flutter pub get
flutter test test/widget_test.dart
flutter run --dart-define-from-file=config/android.local.json
```

Include the refreshed pubspec.lock with your Flutter commit. Check registration, sign-in, switching tabs, editing the profile name and signing out. To test dashboard integration, create a future deadline through the API using the same test account, then refresh the dashboard. Close the app, disable the emulator network and reopen it while still signed in. The dashboard should show the saved deadline and offline notice. Restore the network, sign in as a different account and check that the previous student's entry is absent.

Dashboard totals and lists currently concern upcoming deadlines. Routine and completion data can be integrated when the corresponding backend routes are available. The cache stores deadlines in the Android app's private storage, keyed by the signed-in Firebase UID. The app uses Firebase's persisted session to reopen offline.

## Tasks, campus locations, photos and reminders

The signed-in Android app uses the Planner UI and the authenticated API. Start
the backend from the branch for PR #5 or a shared branch containing that PR.
Use the API URL and Firebase settings for the same environment. Set
`CAMPUS_LATITUDE` and `CAMPUS_LONGITUDE` in your local Android launch
configuration to the centre of the campus covered by your facility data. The
picker requests the nearby campus facilities and allows manual selection if GPS
is unavailable. The standalone Planner UI preview uses labelled sample places
and in-memory entries.

From Tasks, tap the add button. Create a deadline with a date and time, select
a facility, attach a JPEG or PNG up to 5 MB, choose 15 or 30 minutes and save.
Open the task again to verify its location and protected photo. Edit the
reminder, then complete and delete the task. Confirm that the pending reminder
is updated or removed in Alerts. Test permission denial, choosing no photo, and
notification tapping on Android. Allow notifications and exact alarms to test
delivery. A due alert describes its scheduled time and does not confirm Android
delivered it.

The current backend contract does not store category or priority, so those
choices last only for the current app session. Planner offline access is
read-only for entries already loaded in that session. The shared SQLite Planner
cache is a separate integration pending from the team. Configure real Firebase,
MySQL and campus data before Android acceptance.
