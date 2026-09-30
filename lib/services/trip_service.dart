import 'api_service.dart';

class TripService {
  // Dashboard
  Future<dynamic> dashboard() {
    return ApiService.get('/staff/dashboard');
  }

  // Assigned Trips
  Future<dynamic> trips() {
    return ApiService.get('/staff/trips');
  }

  // Start Trip
  Future<dynamic> start(int tripId) {
    return ApiService.post(
      '/staff/trips/$tripId/start',
      {},
    );
  }

  // Send Live GPS Location
  Future<dynamic> sendLocation(
      int tripId,
      double latitude,
      double longitude, {
        double? speed,
        double? heading,
        double? accuracy,
      }) {
    return ApiService.post(
      '/staff/trips/$tripId/location',
      {
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
  }

  // Trip Passenger List
  Future<dynamic> passengers(int tripId) {
    return ApiService.get(
      '/staff/trips/$tripId/passengers',
    );
  }

  // Verify Passenger QR Ticket
  Future<dynamic> verifyTicket(
      int tripId,
      String qrToken,
      ) {
    return ApiService.post(
      '/staff/tickets/verify',
      {
        'trip_id': tripId,
        'qr_token': qrToken.trim(),
      },
    );
  }

  // Passenger Check-In
  Future<dynamic> checkIn(
      int tripId,
      int bookingPassengerId,
      ) {
    return ApiService.post(
      '/staff/tickets/check-in',
      {
        'trip_id': tripId,
        'booking_passenger_id': bookingPassengerId,
      },
    );
  }

  // Emergency Alert
  Future<dynamic> emergency(
      int tripId,
      String message, {
        double? latitude,
        double? longitude,
      }) {
    return ApiService.post(
      '/staff/trips/$tripId/emergency',
      {
        'message': message.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  // End Trip
  Future<dynamic> end(int tripId) {
    return ApiService.post(
      '/staff/trips/$tripId/end',
      {},
    );
  }
}