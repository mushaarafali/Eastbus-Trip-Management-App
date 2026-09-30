import 'package:flutter/material.dart';

import '../models/trip_passenger.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class PassengerListScreen extends StatefulWidget {
  final int tripId;

  const PassengerListScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<PassengerListScreen> createState() => _PassengerListScreenState();
}

class _PassengerListScreenState extends State<PassengerListScreen> {
  List<TripPassenger>? passengers;
  Object? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadPassengers();
  }

  Future<void> loadPassengers() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final response = await ApiService.passengers(widget.tripId);

      final result = response
          .map((item) => TripPassenger.fromJson(
        Map<String, dynamic>.from(item),
      ))
          .toList();

      result.sort((a, b) => _seatOrder(a.seatNumber).compareTo(
        _seatOrder(b.seatNumber),
      ));

      if (!mounted) return;

      setState(() {
        passengers = result;
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

  Future<void> refresh() async {
    await loadPassengers();
  }

  int _seatOrder(String seat) {
    final number = RegExp(r'\d+').firstMatch(seat)?.group(0);
    return int.tryParse(number ?? '') ?? 9999;
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
        title: const Text('Passenger List'),
        actions: [
          IconButton(
            onPressed: loading ? null : refresh,
            tooltip: 'Refresh',
            icon: loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (passengers == null && error != null) {
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (passengers == null) {
      return const LoadingView();
    }

    if (passengers!.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            EmptyView(
              'No confirmed passengers for this trip.',
            ),
          ],
        ),
      );
    }

    final checkedIn = passengers!
        .where((passenger) => passenger.checkedIn)
        .length;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: _summary(
                      'Passengers',
                      '${passengers!.length}',
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summary(
                      'Checked In',
                      '$checkedIn',
                      Icons.verified,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summary(
                      'Remaining',
                      '${passengers!.length - checkedIn}',
                      Icons.schedule,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          ...passengers!.map(
                (passenger) => _passengerCard(passenger),
          ),
        ],
      ),
    );
  }

  Widget _passengerCard(TripPassenger passenger) {
    final name = _value(passenger.passengerName);
    final nic = _value(passenger.nic);
    final seat = _value(passenger.seatNumber);
    final gender = _value(passenger.gender);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEAF0FF),
              child: Text(
                seat,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF173F8A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text('NIC: $nic'),
                  Text('Gender: $gender'),
                  Text('Seat: $seat'),

                  if (passenger.checkedInAt != null)
                    Text(
                      'Checked In: ${_formatDateTime(passenger.checkedInAt!)}',
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        passenger.checkedIn
                            ? Icons.check_circle
                            : Icons.schedule,
                        size: 17,
                        color: passenger.checkedIn
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        passenger.checkedIn
                            ? 'Checked In'
                            : 'Not Checked In',
                        style: TextStyle(
                          color: passenger.checkedIn
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(
      String label,
      String value,
      IconData icon,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF064BD8),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}