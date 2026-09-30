import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const TripsScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip>? trips;
  Object? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.trips();

      result.sort((a, b) {
        final aDate = _tripDateTime(a);
        final bDate = _tripDateTime(b);

        if (aDate != null && bDate != null) {
          return aDate.compareTo(bDate);
        }

        if (aDate != null) return -1;
        if (bDate != null) return 1;

        return a.tripCode.compareTo(b.tripCode);
      });

      if (!mounted) return;

      setState(() {
        trips = result;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Future<void> openTrip(Trip trip) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(trip: trip),
      ),
    );

    if (mounted) {
      await loadTrips();
    }
  }

  DateTime? _tripDateTime(Trip trip) {
    try {
      final date = trip.serviceDate.trim();
      final time = trip.departureTime.trim();

      if (date.isEmpty || time.isEmpty) return null;

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
    } catch (_) {
      return null;
    }
  }

  bool _isPastScheduledTrip(Trip trip) {
    if (!trip.isScheduled) return false;

    final scheduled = _tripDateTime(trip);

    if (scheduled == null) return false;

    return DateTime.now().isAfter(
      scheduled.add(const Duration(minutes: 10)),
    );
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'on_trip':
      case 'on trip':
      case 'on-trip':
        return Colors.green;

      case 'completed':
        return Colors.blueGrey;

      case 'cancelled':
        return Colors.red;

      default:
        return const Color(0xFF064BD8);
    }
  }

  String _statusText(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'on_trip':
      case 'on trip':
      case 'on-trip':
        return 'ON TRIP';

      case 'completed':
        return 'COMPLETED';

      case 'cancelled':
        return 'CANCELLED';

      case 'scheduled':
        return 'SCHEDULED';

      default:
        final value = status.trim();
        return value.isEmpty ? 'UNKNOWN' : value.toUpperCase();
    }
  }

  bool _isActive(Trip trip) {
    final status = trip.status.trim().toLowerCase();

    return status == 'active' ||
        status == 'on_trip' ||
        status == 'on trip' ||
        status == 'on-trip';
  }

  String _value(String value) {
    final text = value.trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: widget.onBack,
        ),
        title: const Text("Today's / Upcoming Trips"),
        actions: [
          IconButton(
            onPressed: loading ? null : loadTrips,
            tooltip: 'Refresh',
            icon: loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (trips == null && error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                cleanError(error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: loading ? null : loadTrips,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (trips == null) {
      return const LoadingView();
    }

    if (trips!.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadTrips,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            EmptyView(
              'No trips are currently assigned to this staff account.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadTrips,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        itemCount: trips!.length,
        itemBuilder: (context, index) {
          return _buildTripCard(trips![index]);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final status = trip.status.trim().toLowerCase();
    final statusColor = _statusColor(status);
    final pastScheduled = _isPastScheduledTrip(trip);
    final active = _isActive(trip);

    final origin = _value(trip.origin);
    final destination = _value(trip.destination);
    final routeText = '$origin → $destination';

    final busParts = <String>[
      if (trip.busNumber.trim().isNotEmpty) trip.busNumber.trim(),
      if (trip.busName.trim().isNotEmpty) trip.busName.trim(),
    ];

    final busText = busParts.join(' • ');

    final booked = trip.bookedPassengers < 0
        ? 0
        : trip.bookedPassengers;

    final seats = trip.seatCount < 0
        ? 0
        : trip.seatCount;

    final available = trip.availableSeats < 0
        ? 0
        : trip.availableSeats;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openTrip(trip),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FF),
                child: Icon(
                  Icons.directions_bus,
                  color: Color(0xFF064BD8),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),

                    if (trip.routeName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        trip.routeName.trim(),
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${_value(trip.serviceDate)} • ${_value(trip.departureTime)}',
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (busText.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_bus_outlined,
                            size: 15,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              busText,
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 15,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '$booked/$seats passengers • '
                                '$available seats available',
                            style: const TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (active) ...[
                      const SizedBox(height: 9),
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Live trip in progress',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (pastScheduled) ...[
                      const SizedBox(height: 9),
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Allowed trip start time has passed',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _statusText(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}