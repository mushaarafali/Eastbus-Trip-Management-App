# Operator -> Firebase synchronization patch

The main database remains MySQL. Firebase is the realtime mirror used by the Trip Management App.

## 1. Add to `.env`

FIREBASE_DATABASE_URL=https://eastbus-smart-transport-default-rtdb.asia-southeast1.firebasedatabase.app

Then run:

php artisan optimize:clear

## 2. Copy service

Copy `app/Services/FirebaseSyncService.php` into your Laravel project at the same path.

## 3. OperatorController imports

Add:

use App\Services\FirebaseSyncService;

## 4. Add this helper inside OperatorController

```php
private function syncTripToFirebase(Trip $trip): void
{
    $trip->load(['route.stops','bus','driver','conductor','operator']);
    $payload = [
        'id' => $trip->id,
        'trip_id' => $trip->id,
        'trip_code' => $trip->trip_code,
        'operator_id' => $trip->operator_id,
        'company_name' => $trip->operator?->company_name,
        'bus_number' => $trip->bus?->bus_number,
        'bus_name' => $trip->bus?->bus_name,
        'seat_count' => $trip->bus?->seat_count ?? 0,
        'route_name' => $trip->route?->name,
        'origin' => $trip->route?->origin,
        'destination' => $trip->route?->destination,
        'service_date' => (string)$trip->service_date,
        'departure_time' => (string)$trip->departure_time,
        'status' => $trip->status,
        'driver_id' => $trip->driver_id,
        'driver_login_id' => $trip->driver?->login_id,
        'driver_name' => $trip->driver?->full_name,
        'conductor_id' => $trip->conductor_id,
        'conductor_login_id' => $trip->conductor?->login_id,
        'conductor_name' => $trip->conductor?->full_name,
        'stops' => $trip->route?->stops?->map(fn($s)=>[
            'name'=>$s->name,
            'stop_order'=>$s->stop_order,
            'latitude'=>$s->latitude,
            'longitude'=>$s->longitude,
            'boarding_allowed'=>(bool)$s->boarding_allowed,
            'dropoff_allowed'=>(bool)$s->dropoff_allowed,
        ])->values()->all() ?? [],
        'updated_at' => now()->timestamp * 1000,
    ];

    $firebase = app(FirebaseSyncService::class);
    foreach (array_filter([$trip->driver?->login_id, $trip->conductor?->login_id]) as $loginId) {
        $firebase->set("assigned_trips/{$loginId}/{$trip->trip_code}", $payload);
    }
}
```

## 5. In storeTrip(), immediately after creating `$trip`

```php
$this->syncTripToFirebase($trip);
```

## 6. Whenever a trip assignment/schedule/status is edited

After `$trip->update(...)` call:

```php
$this->syncTripToFirebase($trip->fresh());
```

This produces:

assigned_trips/
  EBK-DRV-0001/
    TRP2608230002/...
  EBK-CON-0001/
    TRP2608230002/...

The Flutter app reads this data after Laravel authenticates the staff member.
