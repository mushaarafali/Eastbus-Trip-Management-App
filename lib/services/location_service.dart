import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip.dart';
import 'api_service.dart';
import 'firebase_service.dart';

class LocationService {
  StreamSubscription<Position>? _subscription;

  bool _sharing = false;
  bool _sending = false;
  int? _activeTripId;

  Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('EastBus GPS service is disabled.');
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('EastBus location permission denied: $permission');
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (error) {
      debugPrint('EastBus location permission error: $error');
      return false;
    }
  }

  Future<Position?> current() async {
    final allowed = await requestPermission();

    if (!allowed) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (error) {
      debugPrint('EastBus current GPS error: $error');
      return null;
    }
  }

  Future<void> startSharing(Trip trip) async {
    if (_sharing &&
        _subscription != null &&
        _activeTripId == trip.id) {
      debugPrint(
        'EastBus GPS sharing is already active for ${trip.tripCode}.',
      );
      return;
    }

    final allowed = await requestPermission();

    if (!allowed) {
      throw Exception(
        'Location permission is required. Please enable GPS and allow location access.',
      );
    }

    await stop();

    _sharing = true;
    _activeTripId = trip.id;

    final firstPosition = await current();

    if (!_sharing || _activeTripId != trip.id) {
      return;
    }

    if (firstPosition != null) {
      await _shareLocation(
        trip,
        firstPosition,
      );
    }

    if (!_sharing || _activeTripId != trip.id) {
      return;
    }

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'EastBus Live Trip',
        notificationText: 'Sharing live bus location',
        enableWakeLock: true,
      ),
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
          (position) {
        if (!_sharing || _activeTripId != trip.id) {
          return;
        }

        _handlePosition(
          trip,
          position,
        );
      },
      onError: (Object error) {
        debugPrint(
          'EastBus GPS stream error: $error',
        );
      },
      cancelOnError: false,
    );

    debugPrint(
      'EastBus GPS sharing started for ${trip.tripCode}.',
    );
  }

  Future<void> _handlePosition(
      Trip trip,
      Position position,
      ) async {
    if (_sending ||
        !_sharing ||
        _activeTripId != trip.id) {
      return;
    }

    _sending = true;

    try {
      await _shareLocation(
        trip,
        position,
      );
    } finally {
      _sending = false;
    }
  }

  Future<void> _shareLocation(
      Trip trip,
      Position position,
      ) async {
    if (!_sharing || _activeTripId != trip.id) {
      return;
    }

    final latitude = position.latitude;
    final longitude = position.longitude;

    final speedKmh = position.speed.isFinite && position.speed > 0
        ? position.speed * 3.6
        : 0.0;

    final heading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : 0.0;

    final accuracy = position.accuracy.isFinite && position.accuracy >= 0
        ? position.accuracy
        : 0.0;

    debugPrint(
      'EastBus GPS -> '
          'Trip: ${trip.tripCode}, '
          'Lat: $latitude, '
          'Lng: $longitude, '
          'Speed: ${speedKmh.toStringAsFixed(2)} km/h, '
          'Heading: ${heading.toStringAsFixed(2)}, '
          'Accuracy: ${accuracy.toStringAsFixed(2)} m',
    );

    try {
      await FirebaseService.updateLiveLocation(
        trip: trip,
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
        heading: heading,
      );

      debugPrint(
        'EastBus Firebase GPS update successful.',
      );
    } catch (error) {
      debugPrint(
        'EastBus Firebase GPS update failed: $error',
      );
    }

    try {
      await ApiService.sendLocation(
        trip.id,
        latitude,
        longitude,
        speedKmh,
        heading: heading,
      );

      debugPrint(
        'EastBus Laravel GPS update successful.',
      );
    } catch (error) {
      debugPrint(
        'EastBus Laravel GPS update failed: $error',
      );
    }
  }

  Future<void> stop() async {
    _sharing = false;
    _activeTripId = null;

    final subscription = _subscription;
    _subscription = null;

    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (error) {
        debugPrint(
          'EastBus GPS subscription stop error: $error',
        );
      }
    }

    _sending = false;

    debugPrint(
      'EastBus GPS sharing stopped.',
    );
  }

  bool get isSharing {
    return _sharing &&
        _subscription != null &&
        _activeTripId != null;
  }

  int? get activeTripId => _activeTripId;
}