EastBus Trip Management App Update

This package is the next integration patch.

BACKEND FILES
-------------
1. app/Http/Controllers/Api/TripStaffController.php
2. app/Http/Controllers/Api/TicketValidationController.php

FLUTTER FILES
-------------
1. lib/services/api_service.dart
2. lib/services/trip_service.dart
3. lib/models/trip_passenger.dart
4. lib/screens/scanner_screen.dart
5. lib/screens/trip_detail_screen.dart

FEATURES
--------
- Starting / return trip direction supported.
- Only assigned driver/conductor can control trip.
- Start Trip:
  * status -> active
  * started_at set
  * booking_closed_at set immediately
  * booked/available seat snapshot created
- Passenger app can still show seat availability snapshot after start, but new bookings are closed.
- QR verification checks:
  * correct trip
  * confirmed booking
  * paid booking
  * valid ticket status
- QR result displays:
  * booking reference
  * primary passenger name
  * primary NIC
  * boarding stop
  * drop-off stop
  * passenger name
  * seat
  * gender
- Per-passenger check-in.
- Duplicate check-in rejected.
- End Trip -> completed.
- Live location endpoint only works while trip is active.

IMPORTANT
---------
Your existing routes/api.php already contains:
POST /staff/trips/{id}/start
POST /staff/trips/{id}/location
GET  /staff/trips/{id}/passengers
POST /staff/trips/{id}/end
POST /staff/tickets/verify
POST /staff/tickets/check-in

So no API route rewrite is required if those routes still exist.

After backend replacement:
php artisan optimize:clear

For Flutter:
- Merge these files with your existing Trip Management app.
- Keep your Firebase files, LocationService, login/session code and Android configuration.
- If your shared_preferences key is not "staff_token", change it in api_service.dart.
- For a real phone build use:
  flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000/api
or production HTTPS API.

Recommended final test:
1. Staff login
2. Open assigned scheduled trip
3. Start Trip
4. Confirm operator/passenger booking is closed
5. Scan valid passenger QR
6. Confirm Primary NIC + Name + Gender + Seat
7. Check in passenger
8. Scan/check-in same passenger again -> rejected
9. Send GPS location while active
10. End Trip
11. Location sharing / booking remain closed
