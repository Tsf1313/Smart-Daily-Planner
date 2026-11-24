# Smart-Daily-Planner
Smart Daily Planner for University Students — MAD &amp; ITPM Group Project

## Android feature demos

Start an Android emulator, then run the following from the repository root:

```powershell
cd mobile
flutter pub get
flutter devices
```

Run one demo at a time from `mobile`. Replace `emulator-5554` with the Android
device ID shown by `flutter devices` if yours is different.

| Demo | Launch command |
| --- | --- |
| Location Picker | `flutter run -d emulator-5554 -t lib/location_picker_demo.dart` |
| Camera and Gallery | `flutter run -d emulator-5554 -t lib/photo_picker_demo.dart` |
| Reminders and Alerts | `flutter run -d emulator-5554 -t lib/reminder_demo.dart` |

**Sample data:** Library (`sample_library`) and Cafeteria (`sample_cafeteria`)
use test coordinates near the emulator's sample location. The reminder demo
uses the sample deadline **Submit report**.

**Pending integration:** The planner's Add/Edit Entry form, facilities and
attachment APIs, and planner routes.
