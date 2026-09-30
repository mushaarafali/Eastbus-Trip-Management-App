# EastBus Trip Management - Firebase-first realtime build

Architecture:

Bus Operator Portal -> Laravel -> MySQL (source of truth) -> Firebase assigned_trips
Driver/Conductor Login -> Laravel API authentication
Assigned Trips -> Firebase
Start/End Trip -> Laravel status + Firebase status
GPS -> Firebase live_trips every ~10 seconds + Laravel live_locations history
QR verification/check-in -> Laravel/MySQL
Emergency -> Firebase realtime + Laravel/MySQL

## Firebase structure

assigned_trips/{STAFF_LOGIN_ID}/{TRIP_CODE}
live_trips/{TRIP_CODE}
emergency_alerts/{PUSH_ID}

## First run

1. Ensure `android/app/google-services.json` exists (included for the EastBus Firebase project).
2. Firebase Realtime Database -> Rules: use `FIREBASE_RULES_TEST_ONLY.json` only during development.
3. Apply `backend_firebase_patch` to Laravel so operator trip assignments are mirrored to Firebase.
4. Laravel: `php artisan serve --host=0.0.0.0 --port=8000`
5. Flutter: `flutter clean` then `flutter pub get`.
6. Emulator: `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000/api`
7. Physical phone on same Wi-Fi: use your PC LAN IP, e.g. `flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://192.168.8.112:8000/api`

For a production APK, host Laravel on HTTPS and replace the API_BASE_URL with the public API URL. Do not keep the test Firebase rules in production.
