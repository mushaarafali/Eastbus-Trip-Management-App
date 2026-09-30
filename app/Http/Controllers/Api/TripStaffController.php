<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class TripStaffController extends Controller
{
    public function dashboard(Request $request)
    {
        $staff = $this->staff($request);

        $trips = DB::table('trips')
            ->join('routes', 'routes.id', '=', 'trips.route_id')
            ->join('buses', 'buses.id', '=', 'trips.bus_id')
            ->where(function ($query) use ($staff) {
                $query->where('trips.driver_id', $staff->id)
                    ->orWhere('trips.conductor_id', $staff->id);
            })
            ->whereIn('trips.status', ['scheduled', 'active'])
            ->select(
                'trips.*',
                'routes.origin',
                'routes.destination',
                'buses.bus_number',
                'buses.bus_name'
            )
            ->orderBy('trips.service_date')
            ->orderBy('trips.departure_time')
            ->get();

        foreach ($trips as $trip) {
            if ($this->isReturnTrip($trip)) {
                $origin = $trip->origin;
                $trip->origin = $trip->destination;
                $trip->destination = $origin;
            }
        }

        return response()->json([
            'success' => true,
            'staff' => $staff,
            'trips' => $trips,
        ]);
    }

    public function trips(Request $request)
    {
        return $this->dashboard($request);
    }

    public function start(Request $request, $id)
    {
        $staff = $this->staff($request);

        $trip = DB::table('trips')
            ->where('id', $id)
            ->where(function ($query) use ($staff) {
                $query->where('driver_id', $staff->id)
                    ->orWhere('conductor_id', $staff->id);
            })
            ->lockForUpdate()
            ->first();

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'Assigned trip not found.',
            ], 404);
        }

        if ($trip->status === 'completed') {
            throw ValidationException::withMessages([
                'trip' => 'Completed trip cannot be started again.',
            ]);
        }

        if ($trip->status === 'active') {
            return response()->json([
                'success' => true,
                'message' => 'Trip is already active.',
                'trip_id' => $trip->id,
                'trip_code' => $trip->trip_code,
                'status' => 'active',
            ]);
        }

        DB::transaction(function () use ($trip) {
            $snapshot = $this->buildSeatSnapshot($trip->id, $trip->bus_id);

            $update = [
                'status' => 'active',
                'started_at' => now(),
                'booking_closed_at' => now(),
                'updated_at' => now(),
            ];

            if (Schema::hasColumn('trips', 'seat_snapshot_json')) {
                $update['seat_snapshot_json'] = json_encode($snapshot);
            }

            if (Schema::hasColumn('trips', 'trip_start_booked_seats')) {
                $update['trip_start_booked_seats'] = collect($snapshot)
                    ->where('status', 'booked')
                    ->count();
            }

            if (Schema::hasColumn('trips', 'trip_start_available_seats')) {
                $update['trip_start_available_seats'] = collect($snapshot)
                    ->where('status', 'available')
                    ->count();
            }

            DB::table('trips')->where('id', $trip->id)->update($update);
        });

        return response()->json([
            'success' => true,
            'message' => 'Trip started. Passenger booking is now closed.',
            'trip_id' => $trip->id,
            'trip_code' => $trip->trip_code,
            'status' => 'active',
            'firebase_path' => 'live_trips/' . $trip->trip_code,
        ]);
    }

    public function location(Request $request, $id)
    {
        $staff = $this->staff($request);

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'speed' => ['nullable', 'numeric', 'min:0'],
            'heading' => ['nullable', 'numeric', 'between:0,360'],
            'accuracy' => ['nullable', 'numeric', 'min:0'],
        ]);

        $trip = DB::table('trips')
            ->where('id', $id)
            ->where(function ($query) use ($staff) {
                $query->where('driver_id', $staff->id)
                    ->orWhere('conductor_id', $staff->id);
            })
            ->first();

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'Assigned trip not found.',
            ], 404);
        }

        if ($trip->status !== 'active') {
            throw ValidationException::withMessages([
                'trip' => 'Start the trip before sharing live location.',
            ]);
        }

        if (Schema::hasTable('live_locations')) {
            DB::table('live_locations')->updateOrInsert(
                ['trip_id' => $trip->id],
                [
                    'latitude' => $data['latitude'],
                    'longitude' => $data['longitude'],
                    'speed' => $data['speed'] ?? null,
                    'heading' => $data['heading'] ?? null,
                    'accuracy' => $data['accuracy'] ?? null,
                    'staff_id' => $staff->id,
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }

        return response()->json([
            'success' => true,
            'firebase_path' => 'live_trips/' . $trip->trip_code,
            'location' => [
                'latitude' => (float) $data['latitude'],
                'longitude' => (float) $data['longitude'],
                'speed' => isset($data['speed']) ? (float) $data['speed'] : null,
                'heading' => isset($data['heading']) ? (float) $data['heading'] : null,
                'accuracy' => isset($data['accuracy']) ? (float) $data['accuracy'] : null,
                'updated_at' => now()->toIso8601String(),
            ],
        ]);
    }

    public function passengers(Request $request, $id)
    {
        $staff = $this->staff($request);
        $trip = $this->assignedTrip($staff->id, $id);

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'Assigned trip not found.',
            ], 404);
        }

        $rows = DB::table('bookings')
            ->join('booking_passengers', 'booking_passengers.booking_id', '=', 'bookings.id')
            ->where('bookings.trip_id', $trip->id)
            ->where('bookings.status', 'confirmed')
            ->where('bookings.payment_status', 'paid')
            ->select(
                'bookings.id as booking_id',
                'bookings.booking_reference',
                'bookings.primary_passenger_name',
                'bookings.primary_passenger_nic',
                'bookings.boarding_stop',
                'bookings.dropoff_stop',
                'booking_passengers.id as booking_passenger_id',
                'booking_passengers.seat_number',
                'booking_passengers.passenger_name',
                'booking_passengers.gender',
                'booking_passengers.checked_in_at'
            )
            ->orderByRaw("CAST(REPLACE(booking_passengers.seat_number, 'S', '') AS UNSIGNED)")
            ->get();

        return response()->json([
            'success' => true,
            'trip_id' => $trip->id,
            'trip_code' => $trip->trip_code,
            'passengers' => $rows,
        ]);
    }

    public function emergency(Request $request, $id)
    {
        $staff = $this->staff($request);
        $trip = $this->assignedTrip($staff->id, $id);

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'Assigned trip not found.',
            ], 404);
        }

        $data = $request->validate([
            'message' => ['required', 'string', 'max:500'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        if (Schema::hasTable('emergency_alerts')) {
            DB::table('emergency_alerts')->insert([
                'trip_id' => $trip->id,
                'staff_id' => $staff->id,
                'message' => $data['message'],
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'status' => 'open',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Emergency alert sent.',
        ]);
    }

    public function end(Request $request, $id)
    {
        $staff = $this->staff($request);
        $trip = $this->assignedTrip($staff->id, $id);

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'Assigned trip not found.',
            ], 404);
        }

        if ($trip->status !== 'active') {
            throw ValidationException::withMessages([
                'trip' => 'Only an active trip can be completed.',
            ]);
        }

        DB::table('trips')->where('id', $trip->id)->update([
            'status' => 'completed',
            'ended_at' => now(),
            'updated_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Trip completed successfully.',
            'trip_id' => $trip->id,
            'trip_code' => $trip->trip_code,
            'status' => 'completed',
        ]);
    }

    public function notifications(Request $request)
    {
        $staff = $this->staff($request);

        if (!Schema::hasTable('notifications')) {
            return response()->json([
                'success' => true,
                'notifications' => [],
            ]);
        }

        $query = DB::table('notifications');

        if (Schema::hasColumn('notifications', 'staff_id')) {
            $query->where('staff_id', $staff->id);
        } else {
            return response()->json([
                'success' => true,
                'notifications' => [],
            ]);
        }

        return response()->json([
            'success' => true,
            'notifications' => $query->orderByDesc('created_at')->get(),
        ]);
    }

    private function staff(Request $request)
    {
        $staff = $request->attributes->get('staff');
        abort_unless($staff, 401, 'Staff authentication required.');
        return $staff;
    }

    private function assignedTrip(int $staffId, int $tripId)
    {
        return DB::table('trips')
            ->where('id', $tripId)
            ->where(function ($query) use ($staffId) {
                $query->where('driver_id', $staffId)
                    ->orWhere('conductor_id', $staffId);
            })
            ->first();
    }

    private function buildSeatSnapshot(int $tripId, int $busId): array
    {
        $booked = DB::table('booking_passengers')
            ->join('bookings', 'bookings.id', '=', 'booking_passengers.booking_id')
            ->where('bookings.trip_id', $tripId)
            ->where('bookings.status', 'confirmed')
            ->where('bookings.payment_status', 'paid')
            ->select(
                'booking_passengers.seat_number',
                'booking_passengers.passenger_name',
                'booking_passengers.gender',
                'bookings.primary_passenger_nic'
            )
            ->get()
            ->keyBy(fn ($row) => $this->normalizeSeatNumber($row->seat_number));

        return DB::table('seats')
            ->where('bus_id', $busId)
            ->orderByRaw("CAST(REPLACE(seat_number, 'S', '') AS UNSIGNED)")
            ->get()
            ->map(function ($seat) use ($booked) {
                $number = $this->normalizeSeatNumber($seat->seat_number);
                $passenger = $booked->get($number);

                if ((bool) ($seat->is_disabled ?? false)) {
                    return [
                        'seat_number' => $number,
                        'status' => 'unavailable',
                    ];
                }

                if ($passenger) {
                    return [
                        'seat_number' => $number,
                        'status' => 'booked',
                        'passenger_name' => $passenger->passenger_name,
                        'gender' => $passenger->gender,
                        'primary_passenger_nic' => $passenger->primary_passenger_nic,
                    ];
                }

                return [
                    'seat_number' => $number,
                    'status' => 'available',
                ];
            })
            ->values()
            ->all();
    }

    private function normalizeSeatNumber($value): string
    {
        $number = preg_replace('/[^0-9]/', '', trim((string) $value));

        return $number === '' ? '' : 'S' . (int) $number;
    }

    private function isReturnTrip($trip): bool
    {
        return strtolower(trim((string) ($trip->trip_type ?? 'starting'))) === 'return';
    }
}
