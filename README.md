# EastBus.lk Trip Management App

Flutter Android application for authorised EastBus bus staff (Driver / Conductor). The project is designed to open in Android Studio as a Flutter project and connect to the EastBus Laravel Admin + Bus Operator system.

## Implemented Working Flow

1. Splash screen
2. Staff login using Driver/Conductor ID, phone number, or email + password
3. Staff dashboard
4. Assigned today/upcoming trips
5. Start Trip
6. GPS location sharing during an active trip
7. QR ticket scanner
8. Server-side ticket verification
9. Mark passenger as Checked In / Used
10. Passenger list for assigned trip
11. Notifications
12. Emergency alert to the relevant Bus Operator
13. End Trip and stop GPS sharing
14. View-only Driver/Conductor profile
15. Logout

Driver and Conductor accounts are NOT publicly registered from this app. They are created and assigned by the Bus Operator Web Portal.

## Project Structure

- `lib/` Flutter application source
- `android/` Android Studio / Android configuration
- `laravel_api_patch/` REST API files required by the previous EastBus Admin + Bus Operator Laravel project
- `SETUP_WINDOWS.bat` basic Flutter setup helper
- `REGENERATE_ANDROID.bat` regenerates Android wrapper/platform files if your Flutter/Gradle environment requires it

## Android Studio Setup

### 1. Requirements

Install:

- Android Studio
- Flutter SDK (stable)
- Flutter plugin for Android Studio
- Dart plugin
- Android SDK

Run in Command Prompt:

```text
flutter doctor
```

Resolve any Android/Flutter issues shown by Flutter Doctor.

### 2. Open the Project

Extract the ZIP and open the **`eastbus_trip_management_app` root folder** in Android Studio. Do not open only the `android` folder.

Then run:

```text
flutter pub get
```

If Android Studio reports missing Gradle wrapper/platform-generated files, run:

```text
REGENERATE_ANDROID.bat
```

This runs `flutter create --platforms=android ...` and keeps the Flutter `lib` source.

### 3. Connect to Laravel API

The API URL is in:

```text
lib/services/api_service.dart
```

Default Android Emulator URL:

```text
http://10.0.2.2:8000/api
```

For a physical Android phone, replace `10.0.2.2` with the Windows PC LAN IP, for example:

```text
http://192.168.1.10:8000/api
```

The phone and PC must normally be connected to the same network and the Laravel server/firewall must allow access.

## Laravel API Patch Installation

This app needs REST endpoints that were not part of the first Admin + Bus Operator package. A compatible API patch is included under `laravel_api_patch/`.

Copy these files into the previous Laravel project:

```text
laravel_api_patch/app/Http/Controllers/Api/StaffAuthController.php
    -> app/Http/Controllers/Api/StaffAuthController.php

laravel_api_patch/app/Http/Controllers/Api/TripStaffController.php
    -> app/Http/Controllers/Api/TripStaffController.php

laravel_api_patch/app/Http/Middleware/StaffApiAuth.php
    -> app/Http/Middleware/StaffApiAuth.php

laravel_api_patch/database/migrations/2026_08_23_000300_create_staff_api_and_ticket_tables.php
    -> database/migrations/2026_08_23_000300_create_staff_api_and_ticket_tables.php

laravel_api_patch/routes/api.php
    -> routes/api.php
```

Apply the middleware alias instructions in:

```text
laravel_api_patch/BOOTSTRAP_PATCH.txt
```

Then run from the Laravel project:

```text
php artisan migrate
php artisan optimize:clear
php artisan serve --host=0.0.0.0 --port=8000
```

## Demo Driver Account

The previous EastBus Admin/Operator seeder creates this driver:

```text
Driver ID: EBK-DRV-0001
Password: Driver@123
Phone: +94771234567
Email: ashraf.driver@email.com
```

The staff login API accepts Driver/Conductor ID, phone, or email in the same login field.

## Optional Demo QR Ticket

After installing the API patch, copy:

```text
laravel_api_patch/database/seeders/TripAppDemoSeeder.php
    -> database/seeders/TripAppDemoSeeder.php
```

Then run:

```text
php artisan db:seed --class=TripAppDemoSeeder
```

The demo QR/ticket value is:

```text
EBK-TICKET-DEMO-001
```

For camera testing, create any QR code containing exactly that text. The scanner sends the secure ticket identifier to the server rather than trusting personal information stored directly in the QR code.

## API Endpoints Used

```text
POST /api/staff/login
GET  /api/staff/me
POST /api/staff/logout
GET  /api/staff/dashboard
GET  /api/staff/trips
POST /api/staff/trips/{id}/start
POST /api/staff/trips/{id}/location
GET  /api/staff/trips/{id}/passengers
POST /api/staff/trips/{id}/emergency
POST /api/staff/trips/{id}/end
POST /api/staff/tickets/verify
POST /api/staff/tickets/check-in
GET  /api/staff/notifications
```

## Important Security / Real-World Rules

- Only active Driver/Conductor accounts can authenticate.
- A staff member can access only trips assigned to them by their own Bus Operator.
- GPS updates are accepted only while an assigned trip is Active.
- QR tickets are verified on the Laravel server.
- Reused/used tickets are rejected.
- Check-in requires a paid booking.
- Emergency alerts are linked to the staff member, trip, operator and current GPS position when available.
- Protected staff profile information is view-only in the app.
- Passwords are not stored as plain text by the app.

## Android Permissions

The Android manifest includes:

- Internet
- Camera (QR scanner)
- Fine / coarse location
- Foreground service location permissions

On Android, the app still asks the user for runtime location/camera permission where required.

## Notes

The package does not include the Flutter SDK, Android SDK, Gradle distribution, or Java SDK. Those are development tools installed on your PC and should not be bundled with a source project.
