import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../widgets/common.dart';
import 'passenger_list_screen.dart';
import 'scanner_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final TripService service = TripService();
  final LocationService location = LocationService();
  final MapController mapController = MapController();

  late String status;

  bool busy = false;
  bool sharing = false;
  bool retryingGps = false;
  bool sendingEmergency = false;
  bool mapReady = false;

  double? liveLatitude;
  double? liveLongitude;
  double liveSpeed = 0;
  double liveHeading = 0;
  DateTime? liveUpdatedAt;

  Timer? clockTimer;
  StreamSubscription<DatabaseEvent>? liveLocationSubscription;

  @override
  void initState() {
    super.initState();

    status = widget.trip.status.trim().toLowerCase();

    clockTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        if (mounted && status == 'scheduled') {
          setState(() {});
        }
      },
    );

    if (status == 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _listenToLiveLocation();
        await _resumeLocationSharing();
      });
    }
  }

  DateTime? get scheduledDeparture {
    final date = widget.trip.serviceDate.trim();
    final time = widget.trip.departureTime.trim();

    if (date.isEmpty || time.isEmpty) {
      return null;
    }

    final dateParts = date.split('-');
    final timeParts = time.split(':');

    if (dateParts.length != 3 || timeParts.length < 2) {
      return null;
    }

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = timeParts.length > 2
        ? int.tryParse(timeParts[2]) ?? 0
        : 0;

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(
      year,
      month,
      day,
      hour,
      minute,
      second,
    );
  }

  DateTime? get startWindowOpens {
    return scheduledDeparture?.subtract(
      const Duration(minutes: 10),
    );
  }

  DateTime? get startWindowCloses {
    return scheduledDeparture?.add(
      const Duration(minutes: 10),
    );
  }

  bool get canStartTrip {
    if (status != 'scheduled') {
      return false;
    }

    final opens = startWindowOpens;
    final closes = startWindowCloses;

    if (opens == null || closes == null) {
      return false;
    }

    final now = DateTime.now();

    return !now.isBefore(opens) && !now.isAfter(closes);
  }

  bool get hasLiveLocation {
    return liveLatitude != null && liveLongitude != null;
  }

  LatLng? get livePoint {
    if (!hasLiveLocation) {
      return null;
    }

    return LatLng(
      liveLatitude!,
      liveLongitude!,
    );
  }

  String get startMessage {
    final departure = scheduledDeparture;
    final opens = startWindowOpens;
    final closes = startWindowCloses;

    if (departure == null ||
        opens == null ||
        closes == null) {
      return 'Scheduled departure time is not available.';
    }

    final now = DateTime.now();

    if (now.isBefore(opens)) {
      return 'Trip can be started from ${_formatDateTimeTime(opens)}. '
          'Scheduled departure is ${_formatDateTimeTime(departure)}.';
    }

    if (now.isAfter(closes)) {
      return 'The allowed start time ended at ${_formatDateTimeTime(closes)}.';
    }

    return 'Trip can be started now. Allowed time: '
        '${_formatDateTimeTime(opens)} - ${_formatDateTimeTime(closes)}.';
  }

  String _formatDateTimeTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatLiveUpdatedAt(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute:$second $period';
  }

  void _listenToLiveLocation() {
    liveLocationSubscription?.cancel();

    final tripCode = widget.trip.tripCode.trim();

    if (tripCode.isEmpty) {
      return;
    }

    final reference = FirebaseDatabase.instance
        .ref()
        .child('live_trips')
        .child(tripCode);

    liveLocationSubscription = reference.onValue.listen(
          (event) {
        final value = event.snapshot.value;

        if (value is! Map) {
          return;
        }

        final data = Map<dynamic, dynamic>.from(value);

        final latitude = _toDouble(
          data['latitude'] ?? data['lat'],
        );
        final longitude = _toDouble(
          data['longitude'] ?? data['lng'] ?? data['lon'],
        );

        if (!_validCoordinates(latitude, longitude)) {
          return;
        }

        final speed = _toDouble(
          data['speed_kmh'] ?? data['speed'],
        ) ??
            0;
        final heading = _toDouble(
          data['heading'] ?? data['bearing'],
        ) ??
            0;

        final timestamp = _toTimestamp(
          data['location_updated_at'] ??
              data['recorded_at'] ??
              data['updated_at'] ??
              data['timestamp'],
        );

        final updatedAt = timestamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
          timestamp,
        ).toLocal();

        if (!mounted) {
          return;
        }

        setState(() {
          liveLatitude = latitude;
          liveLongitude = longitude;
          liveSpeed = speed;
          liveHeading = heading;
          liveUpdatedAt = updatedAt;
        });

        _moveMapToLiveLocation();
      },
      onError: (error) {
        debugPrint(
          'EastBus live Firebase location read failed: $error',
        );
      },
    );
  }

  void _moveMapToLiveLocation() {
    final point = livePoint;

    if (!mapReady || point == null) {
      return;
    }

    try {
      mapController.move(
        point,
        15.5,
      );
    } catch (_) {}
  }

  Future<void> _resumeLocationSharing() async {
    if (retryingGps ||
        sharing ||
        status != 'active') {
      return;
    }

    setState(() {
      retryingGps = true;
    });

    try {
      await location.startSharing(
        widget.trip,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        sharing = location.isSharing;
      });

      if (!sharing) {
        throw Exception(
          'Live GPS sharing could not be started.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        sharing = false;
      });

      snack(
        context,
        'GPS sharing failed: ${cleanError(error)}',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          retryingGps = false;
        });
      }
    }
  }

  Future<void> start() async {
    if (busy) {
      return;
    }

    if (!canStartTrip) {
      snack(
        context,
        startMessage,
        error: true,
      );
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await service.start(
        widget.trip.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        status = 'active';
      });

      _listenToLiveLocation();

      try {
        await FirebaseService.markTripStatus(
          widget.trip,
          'active',
        );
      } catch (error) {
        debugPrint(
          'EastBus Firebase status update failed: $error',
        );
      }

      try {
        await location.startSharing(
          widget.trip,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          sharing = location.isSharing;
        });

        if (!sharing) {
          throw Exception(
            'Live GPS sharing could not be started.',
          );
        }

        snack(
          context,
          'Trip started. Live GPS sharing is active.',
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          sharing = false;
        });

        snack(
          context,
          'Trip started, but GPS could not start: '
              '${cleanError(error)}',
          error: true,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      snack(
        context,
        cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> end() async {
    if (busy || status != 'active') {
      return;
    }

    final confirmed = await _confirmEndTrip();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      await service.end(
        widget.trip.id,
      );

      await location.stop();
      await liveLocationSubscription?.cancel();
      liveLocationSubscription = null;

      try {
        await FirebaseService.markTripStatus(
          widget.trip,
          'completed',
        );
      } catch (error) {
        debugPrint(
          'EastBus Firebase completed status failed: $error',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        status = 'completed';
        sharing = false;
      });

      snack(
        context,
        'Trip completed. Live location sharing stopped.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      snack(
        context,
        cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<bool> _confirmEndTrip() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.stop_circle_outlined,
            size: 46,
            color: Colors.red,
          ),
          title: const Text(
            'End Trip?',
          ),
          content: const Text(
            'Live GPS sharing will stop and this trip will be marked as completed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'End Trip',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> emergency() async {
    if (sendingEmergency ||
        status != 'active') {
      return;
    }

    setState(() {
      sendingEmergency = true;
    });

    try {
      final position = await location.current();

      await service.emergency(
        widget.trip.id,
        'Emergency assistance required',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      try {
        await FirebaseService.emergency(
          trip: widget.trip,
          latitude: position?.latitude,
          longitude: position?.longitude,
          message: 'Emergency assistance required',
        );
      } catch (error) {
        debugPrint(
          'EastBus Firebase emergency alert failed: $error',
        );
      }

      if (!mounted) {
        return;
      }

      snack(
        context,
        'Emergency alert sent.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      snack(
        context,
        cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          sendingEmergency = false;
        });
      }
    }
  }

  void _openPassengerList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerListScreen(
          tripId: widget.trip.id,
        ),
      ),
    );
  }

  void _openScanner() {
    if (status != 'active') {
      snack(
        context,
        'QR scanning is available only during an active trip.',
        error: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          tripId: widget.trip.id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    liveLocationSubscription?.cancel();
    location.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = status == 'scheduled';
    final active = status == 'active';
    final completed = status == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          widget.trip.tripCode.trim().isEmpty
              ? 'Trip Details'
              : widget.trip.tripCode,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _tripHeader(),
            const SizedBox(height: 18),
            if (scheduled) _scheduledSection(),
            if (active) _activeSection(),
            if (completed) _completedSection(),
            if (!scheduled &&
                !active &&
                !completed)
              _unknownStatusSection(),
          ],
        ),
      ),
    );
  }

  Widget _tripHeader() {
    final bus = widget.trip.busNumber.trim().isEmpty
        ? '-'
        : widget.trip.busNumber;

    final origin = widget.trip.origin.trim().isEmpty
        ? '-'
        : widget.trip.origin;

    final destination =
    widget.trip.destination.trim().isEmpty
        ? '-'
        : widget.trip.destination;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A2D7A),
            Color(0xFF174CA5),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF173F8A,
            ).withValues(
              alpha: 0.20,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white12,
                child: Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$origin → $destination',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                widget.trip.serviceDate,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                widget.trip.departureTime,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _statusChip(),
        ],
      ),
    );
  }

  Widget _statusChip() {
    Color background;
    Color foreground;
    IconData icon;
    String text;

    switch (status) {
      case 'active':
        background = const Color(0xFFDFF7E6);
        foreground = Colors.green;
        icon = Icons.radio_button_checked_rounded;
        text = 'ON TRIP';
        break;

      case 'completed':
        background = const Color(0xFFE8F5E9);
        foreground = Colors.green;
        icon = Icons.check_circle_rounded;
        text = 'COMPLETED';
        break;

      case 'cancelled':
        background = const Color(0xFFFFE8E8);
        foreground = Colors.red;
        icon = Icons.cancel_rounded;
        text = 'CANCELLED';
        break;

      default:
        background = const Color(0xFFFFF3D7);
        foreground = const Color(0xFF9A6700);
        icon = Icons.schedule_rounded;
        text = status.toUpperCase();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduledSection() {
    final enabled = canStartTrip;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: enabled
                      ? const Color(0xFFE6F7EA)
                      : const Color(0xFFEAF0FF),
                  child: Icon(
                    enabled
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    color: enabled
                        ? Colors.green
                        : const Color(0xFF173F8A),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled
                            ? 'Trip Ready to Start'
                            : 'Start Time Restriction',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        startMessage,
                        style: const TextStyle(
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The trip can only be started within 10 minutes before or 10 minutes after the scheduled departure.',
                        style: TextStyle(
                          color: Color(0xFF6B7890),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy || !enabled
                ? null
                : start,
            icon: busy
                ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.play_arrow_rounded,
            ),
            label: Text(
              busy
                  ? 'Starting Trip...'
                  : enabled
                  ? 'Start Trip'
                  : 'Start Trip Not Available',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openPassengerList,
            icon: const Icon(
              Icons.people_alt_rounded,
            ),
            label: const Text(
              'View Passenger List',
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeSection() {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: sharing
                  ? const Color(0xFFE6F7EA)
                  : const Color(0xFFFFF1DC),
              child: Icon(
                sharing
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                color: sharing
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            title: Text(
              sharing
                  ? 'Live GPS Sharing Active'
                  : 'Trip Active • GPS Not Sharing',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              sharing
                  ? 'The same live bus location is available to passengers and staff.'
                  : 'GPS sharing is not active. Retry location sharing.',
            ),
          ),
        ),

        const SizedBox(height: 12),

        _liveTrackingCard(),

        if (!sharing) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: retryingGps
                  ? null
                  : _resumeLocationSharing,
              icon: retryingGps
                  ? const SizedBox(
                width: 19,
                height: 19,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.my_location_rounded,
              ),
              label: Text(
                retryingGps
                    ? 'Connecting GPS...'
                    : 'Retry GPS Sharing',
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        _actionButton(
          icon: Icons.people_alt_rounded,
          title: 'Passenger List',
          subtitle:
          'View booked passengers and check-in status.',
          onPressed: _openPassengerList,
        ),

        _actionButton(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan Passenger QR',
          subtitle:
          'Verify tickets and check passengers in.',
          onPressed: _openScanner,
        ),

        Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: OutlinedButton.icon(
            onPressed: sendingEmergency
                ? null
                : emergency,
            icon: sendingEmergency
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.warning_amber_rounded,
            ),
            label: Text(
              sendingEmergency
                  ? 'Sending Alert...'
                  : 'Send Emergency Alert',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize:
              const Size.fromHeight(52),
            ),
          ),
        ),

        const SizedBox(height: 5),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : end,
            icon: const Icon(
              Icons.stop_circle_outlined,
            ),
            label: Text(
              busy
                  ? 'Completing Trip...'
                  : 'End Trip',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(
                0xFFB3261E,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveTrackingCard() {
    final point = livePoint;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              12,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Trip Tracking',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Current bus location from Firebase',
                        style: TextStyle(
                          color:
                          Color(0xFF6B7890),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                  'Center current location',
                  onPressed: point == null
                      ? null
                      : _moveMapToLiveLocation,
                  icon: const Icon(
                    Icons.my_location_rounded,
                  ),
                ),
              ],
            ),
          ),

          if (point == null)
            Container(
              height: 230,
              width: double.infinity,
              color: const Color(0xFFF0F3F8),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_searching_rounded,
                      size: 46,
                      color:
                      Color(0xFF6B7890),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Waiting for live GPS location...',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'The map will appear when Firebase receives the first GPS update.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color:
                        Color(0xFF6B7890),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15.5,
                  minZoom: 4,
                  maxZoom: 19,
                  onMapReady: () {
                    mapReady = true;
                    _moveMapToLiveLocation();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                    'lk.eastbus.tripmanagement',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 72,
                        height: 72,
                        child: Transform.rotate(
                          angle: liveHeading *
                              0.017453292519943295,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF173F8A,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.22),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: const [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Padding(
            padding:
            const EdgeInsets.all(16),
            child: Column(
              children: [
                _trackingInfoRow(
                  'GPS Status',
                  sharing
                      ? 'SHARING'
                      : 'NOT SHARING',
                  sharing
                      ? Colors.green
                      : Colors.orange,
                ),
                _trackingInfoRow(
                  'Latitude',
                  liveLatitude == null
                      ? '-'
                      : liveLatitude!
                      .toStringAsFixed(6),
                ),
                _trackingInfoRow(
                  'Longitude',
                  liveLongitude == null
                      ? '-'
                      : liveLongitude!
                      .toStringAsFixed(6),
                ),
                _trackingInfoRow(
                  'Speed',
                  '${liveSpeed.toStringAsFixed(1)} km/h',
                ),
                _trackingInfoRow(
                  'Last Updated',
                  _formatLiveUpdatedAt(
                    liveUpdatedAt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingInfoRow(
      String label,
      String value, [
        Color? valueColor,
      ]) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color:
                Color(0xFF6B7890),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight:
              FontWeight.w800,
              fontSize: 12,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 58,
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            const Text(
              'Trip Completed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Live location sharing has stopped and this trip has been completed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7890),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openPassengerList,
                icon: const Icon(
                  Icons.people_alt_rounded,
                ),
                label: const Text(
                  'View Passenger List',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unknownStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 10),
            Text(
              'Trip status: ${status.toUpperCase()}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This trip cannot be started from the Trip Management App.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Card(
        child: ListTile(
          onTap: onPressed,
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color:
              const Color(0xFFEAF0FF),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color:
              const Color(0xFF173F8A),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
          ),
        ),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().trim(),
    );
  }
  bool _validCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return false;
    }

    if (lat < -90 || lat > 90) {
      return false;
    }

    if (lng < -180 || lng > 180) {
      return false;
    }

    return true;
  }

  int? _toTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final number = value.toInt();
      return number < 100000000000
          ? number * 1000
          : number;
    }

    final text = value.toString().trim();
    final number = int.tryParse(text);

    if (number != null) {
      return number < 100000000000
          ? number * 1000
          : number;
    }

    return DateTime.tryParse(text)
        ?.millisecondsSinceEpoch;
  }

}