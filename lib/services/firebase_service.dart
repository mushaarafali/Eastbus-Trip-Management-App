import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

class FirebaseService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  static Future<String> _loginId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_login_id')?.trim() ?? '';
  }

  static String _tripCode(Trip trip) {
    final code = trip.tripCode.trim();

    if (code.isEmpty) {
      throw Exception('Trip code is required for Firebase.');
    }

    return code;
  }

  static String _normalizeStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'on_trip':
      case 'on trip':
        return 'ON_TRIP';

      case 'completed':
        return 'COMPLETED';

      case 'cancelled':
      case 'canceled':
        return 'CANCELLED';

      case 'scheduled':
        return 'SCHEDULED';

      default:
        return status.trim().toUpperCase();
    }
  }

  static Future<List<Trip>> assignedTrips() async {
    final loginId = await _loginId();

    if (loginId.isEmpty) {
      debugPrint('Firebase assignedTrips: staff login ID is empty.');
      return [];
    }

    try {
      final snapshot = await _db.ref('assigned_trips/$loginId').get();

      if (!snapshot.exists || snapshot.value is! Map) {
        return [];
      }

      final rawMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final trips = <Trip>[];

      for (final entry in rawMap.entries) {
        if (entry.value is! Map) continue;

        final rawTrip = Map<String, dynamic>.from(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );

        rawTrip['trip_code'] ??= '${entry.key}';

        try {
          trips.add(Trip.fromJson(rawTrip));
        } catch (e) {
          debugPrint(
            'Firebase assigned trip parse failed for ${entry.key}: $e',
          );
        }
      }

      trips.sort((a, b) {
        final aDate = '${a.serviceDate} ${a.departureTime}';
        final bDate = '${b.serviceDate} ${b.departureTime}';
        return aDate.compareTo(bDate);
      });

      return trips;
    } catch (e) {
      debugPrint('Firebase assignedTrips failed: $e');
      rethrow;
    }
  }

  static Stream<DatabaseEvent> assignedTripsStream(String loginId) {
    final id = loginId.trim();

    if (id.isEmpty) {
      throw Exception(
        'Staff login ID is required for Firebase assigned trips.',
      );
    }

    return _db.ref('assigned_trips/$id').onValue;
  }

  static Future<void> markTripStatus(
      Trip trip,
      String status,
      ) async {
    final loginId = await _loginId();
    final tripCode = _tripCode(trip);

    if (loginId.isEmpty) {
      throw Exception('Staff login session is missing.');
    }

    final firebaseStatus = _normalizeStatus(status);

    await _db.ref('assigned_trips/$loginId/$tripCode').update({
      'status': firebaseStatus.toLowerCase(),
      'updated_at': ServerValue.timestamp,
    });

    await _db.ref('live_trips/$tripCode').update({
      'trip_id': trip.id,
      'trip_code': tripCode,
      'bus_number': trip.busNumber,
      'origin': trip.origin,
      'destination': trip.destination,
      'staff_login_id': loginId,
      'status': firebaseStatus,
      'updated_at': ServerValue.timestamp,
    });

    debugPrint(
      'Firebase trip status: $tripCode -> $firebaseStatus',
    );
  }

  static Future<void> updateLiveLocation({
    required Trip trip,
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double heading,
  }) async {
    final loginId = await _loginId();
    final tripCode = _tripCode(trip);

    if (loginId.isEmpty) {
      throw Exception('Staff login session is missing.');
    }

    if (latitude < -90 || latitude > 90) {
      throw Exception('Invalid GPS latitude.');
    }

    if (longitude < -180 || longitude > 180) {
      throw Exception('Invalid GPS longitude.');
    }

    final speed = speedKmh.isNegative ? 0.0 : speedKmh;
    final normalizedHeading = ((heading % 360) + 360) % 360;

    await _db.ref('live_trips/$tripCode').update({
      'trip_id': trip.id,
      'trip_code': tripCode,
      'bus_number': trip.busNumber,
      'origin': trip.origin,
      'destination': trip.destination,
      'staff_login_id': loginId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': normalizedHeading,
      'status': 'ON_TRIP',
      'location_updated_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });

    debugPrint(
      'Firebase GPS -> '
          '$tripCode | '
          '$latitude, $longitude | '
          '${speed.toStringAsFixed(2)} km/h',
    );
  }

  static Future<Map<String, dynamic>?> getLiveLocation(
      String tripCode,
      ) async {
    final code = tripCode.trim();

    if (code.isEmpty) return null;

    final snapshot = await _db.ref('live_trips/$code').get();

    if (!snapshot.exists || snapshot.value is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(
      Map<dynamic, dynamic>.from(snapshot.value as Map),
    );
  }

  static Stream<DatabaseEvent> liveLocationStream(
      String tripCode,
      ) {
    final code = tripCode.trim();

    if (code.isEmpty) {
      throw Exception(
        'Trip code is required for live location tracking.',
      );
    }

    return _db.ref('live_trips/$code').onValue;
  }

  static Future<void> emergency({
    required Trip trip,
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    final loginId = await _loginId();
    final tripCode = _tripCode(trip);
    final alertMessage = message.trim();

    if (loginId.isEmpty) {
      throw Exception('Staff login session is missing.');
    }

    if (alertMessage.isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }

    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw Exception('Invalid emergency latitude.');
    }

    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw Exception('Invalid emergency longitude.');
    }

    await _db.ref('emergency_alerts').push().set({
      'trip_id': trip.id,
      'trip_code': tripCode,
      'bus_number': trip.busNumber,
      'staff_login_id': loginId,
      'latitude': latitude,
      'longitude': longitude,
      'message': alertMessage,
      'status': 'OPEN',
      'created_at': ServerValue.timestamp,
      'updated_at': ServerValue.timestamp,
    });

    debugPrint(
      'Firebase emergency alert sent for $tripCode.',
    );
  }

  static Future<void> removeLiveTrip(Trip trip) async {
    final tripCode = _tripCode(trip);
    final loginId = await _loginId();

    await _db.ref('live_trips/$tripCode').update({
      'status': 'COMPLETED',
      'updated_at': ServerValue.timestamp,
    });

    if (loginId.isNotEmpty) {
      await _db.ref('assigned_trips/$loginId/$tripCode').update({
        'status': 'completed',
        'updated_at': ServerValue.timestamp,
      });
    }

    debugPrint(
      'Firebase live trip completed: $tripCode',
    );
  }
}