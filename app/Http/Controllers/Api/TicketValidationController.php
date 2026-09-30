<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;

class TicketValidationController extends Controller
{
    public function verify(Request $request)
    {
        $staff = $this->staff($request);

        $data = $request->validate([
            'qr_token' => ['required', 'string', 'max:500'],
            'trip_id' => ['required', 'integer', 'exists:trips,id'],
        ]);

        $trip = $this->assignedTrip($staff->id, (int) $data['trip_id']);

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'This trip is not assigned to the logged-in staff member.',
            ], 403);
        }

        $booking = $this->bookingFromToken($data['qr_token']);

        if (!$booking) {
            return response()->json([
                'success' => false,
                'valid' => false,
                'message' => 'Invalid QR ticket.',
            ], 404);
        }

        if ((int) $booking->trip_id !== (int) $trip->id) {
            return response()->json([
                'success' => false,
                'valid' => false,
                'message' => 'This ticket belongs to a different trip.',
            ], 422);
        }

        if ($booking->payment_status !== 'paid' || $booking->status !== 'confirmed') {
            return response()->json([
                'success' => false,
                'valid' => false,
                'message' => 'Ticket is not active.',
            ], 422);
        }

        if (
            Schema::hasColumn('bookings', 'ticket_status') &&
            !in_array(strtolower((string) $booking->ticket_status), ['valid', 'active'], true)
        ) {
            return response()->json([
                'success' => false,
                'valid' => false,
                'message' => 'Ticket status is not valid.',
            ], 422);
        }

        $passengers = DB::table('booking_passengers')
            ->where('booking_id', $booking->id)
            ->orderByRaw("CAST(REPLACE(seat_number, 'S', '') AS UNSIGNED)")
            ->get();

        return response()->json([
            'success' => true,
            'valid' => true,
            'message' => 'Valid EastBus ticket.',
            'ticket' => [
                'booking_id' => $booking->id,
                'booking_reference' => $booking->booking_reference,
                'trip_id' => $booking->trip_id,
                'trip_code' => $trip->trip_code,
                'primary_passenger_name' => $booking->primary_passenger_name ?? null,
                'primary_passenger_nic' => $booking->primary_passenger_nic ?? null,
                'boarding_stop' => $booking->boarding_stop ?? null,
                'dropoff_stop' => $booking->dropoff_stop ?? null,
                'passengers' => $passengers,
            ],
        ]);
    }

    public function checkIn(Request $request)
    {
        $staff = $this->staff($request);

        $data = $request->validate([
            'booking_passenger_id' => ['required', 'integer', 'exists:booking_passengers,id'],
            'trip_id' => ['required', 'integer', 'exists:trips,id'],
        ]);

        $trip = $this->assignedTrip($staff->id, (int) $data['trip_id']);

        if (!$trip) {
            return response()->json([
                'success' => false,
                'message' => 'This trip is not assigned to the logged-in staff member.',
            ], 403);
        }

        $passenger = DB::table('booking_passengers')
            ->join('bookings', 'bookings.id', '=', 'booking_passengers.booking_id')
            ->where('booking_passengers.id', $data['booking_passenger_id'])
            ->where('bookings.trip_id', $trip->id)
            ->select(
                'booking_passengers.*',
                'bookings.booking_reference',
                'bookings.primary_passenger_nic'
            )
            ->first();

        if (!$passenger) {
            throw ValidationException::withMessages([
                'passenger' => 'Passenger does not belong to this trip.',
            ]);
        }

        if ($passenger->checked_in_at ?? null) {
            return response()->json([
                'success' => false,
                'message' => 'Passenger already checked in.',
                'checked_in_at' => $passenger->checked_in_at,
            ], 422);
        }

        $update = [
            'checked_in_at' => now(),
            'updated_at' => now(),
        ];

        if (Schema::hasColumn('booking_passengers', 'checked_in_by_staff_id')) {
            $update['checked_in_by_staff_id'] = $staff->id;
        }

        DB::table('booking_passengers')
            ->where('id', $passenger->id)
            ->update($update);

        return response()->json([
            'success' => true,
            'message' => 'Passenger checked in successfully.',
            'passenger' => [
                'booking_passenger_id' => $passenger->id,
                'booking_reference' => $passenger->booking_reference,
                'seat_number' => $passenger->seat_number,
                'passenger_name' => $passenger->passenger_name,
                'gender' => $passenger->gender ?? null,
                'primary_passenger_nic' => $passenger->primary_passenger_nic ?? null,
            ],
        ]);
    }

    private function bookingFromToken(string $token)
    {
        if (Schema::hasColumn('bookings', 'ticket_token')) {
            $booking = DB::table('bookings')
                ->where('ticket_token', $token)
                ->first();

            if ($booking) {
                return $booking;
            }
        }

        return DB::table('bookings')
            ->where('booking_reference', $token)
            ->orWhereRaw("CONCAT('TKT-', UPPER(booking_reference)) = ?", [$token])
            ->first();
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
}
