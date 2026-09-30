import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/trip_service.dart';

class ScannerScreen extends StatefulWidget {
  final int tripId;

  const ScannerScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController scanner = MobileScannerController();
  final TripService service = TripService();

  bool processing = false;
  String? lastCode;

  static const Color primary = Color(0xFF173F8A);
  static const Color background = Color(0xFFF5F7FB);

  Future<void> verify(String code) async {
    final qrToken = code.trim();

    if (qrToken.isEmpty || processing || qrToken == lastCode) {
      return;
    }

    setState(() {
      processing = true;
      lastCode = qrToken;
    });

    try {
      await scanner.stop();

      final response = await service.verifyTicket(
        widget.tripId,
        qrToken,
      );

      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final ticket = data['ticket'] is Map
          ? Map<String, dynamic>.from(data['ticket'])
          : data;

      final booking = data['booking'] is Map
          ? Map<String, dynamic>.from(data['booking'])
          : <String, dynamic>{};

      final rawPassengers =
          ticket['passengers'] ??
              data['passengers'] ??
              booking['passengers'];

      final passengers = rawPassengers is List
          ? rawPassengers
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TicketSheet(
          tripId: widget.tripId,
          ticket: ticket,
          booking: booking,
          passengers: passengers,
          service: service,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        try {
          await scanner.start();
        } catch (_) {}

        setState(() {
          processing = false;
        });
      }

      Future.delayed(
        const Duration(seconds: 2),
            () => lastCode = null,
      );
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '');
  }

  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Verify Passenger Ticket',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scanner,
            onDetect: (capture) {
              if (capture.barcodes.isEmpty) return;

              final value = capture.barcodes.first.rawValue;

              if (value != null && value.trim().isNotEmpty) {
                verify(value);
              }
            },
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.28),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.48),
                ],
              ),
            ),
          ),

          Align(
            alignment: const Alignment(0, -0.08),
            child: IgnorePointer(
              child: Container(
                width: 270,
                height: 270,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    _corner(
                      top: -2,
                      left: -2,
                      topLeft: true,
                    ),
                    _corner(
                      top: -2,
                      right: -2,
                      topRight: true,
                    ),
                    _corner(
                      bottom: -2,
                      left: -2,
                      bottomLeft: true,
                    ),
                    _corner(
                      bottom: -2,
                      right: -2,
                      bottomRight: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 22,
            right: 22,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.70),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scan Passenger QR Ticket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Place the QR code clearly inside the frame.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (processing)
            Container(
              color: Colors.black.withOpacity(0.62),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Verifying Ticket',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Please wait a moment...',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border(
            top: topLeft || topRight
                ? const BorderSide(
              color: primary,
              width: 6,
            )
                : BorderSide.none,
            bottom: bottomLeft || bottomRight
                ? const BorderSide(
              color: primary,
              width: 6,
            )
                : BorderSide.none,
            left: topLeft || bottomLeft
                ? const BorderSide(
              color: primary,
              width: 6,
            )
                : BorderSide.none,
            right: topRight || bottomRight
                ? const BorderSide(
              color: primary,
              width: 6,
            )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _TicketSheet extends StatefulWidget {
  final int tripId;
  final Map<String, dynamic> ticket;
  final Map<String, dynamic> booking;
  final List<Map<String, dynamic>> passengers;
  final TripService service;

  const _TicketSheet({
    required this.tripId,
    required this.ticket,
    required this.booking,
    required this.passengers,
    required this.service,
  });

  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends State<_TicketSheet> {
  final Set<int> checkingPassengers = {};

  static const Color primary = Color(0xFF173F8A);
  static const Color pageBg = Color(0xFFF5F7FB);
  static const Color textDark = Color(0xFF172033);
  static const Color textMuted = Color(0xFF728096);
  static const Color green = Color(0xFF169B62);

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }

    return text;
  }

  int _passengerId(Map<String, dynamic> passenger) {
    return int.tryParse(
      '${passenger['booking_passenger_id'] ?? passenger['id'] ?? 0}',
    ) ??
        0;
  }

  bool _checkedIn(Map<String, dynamic> passenger) {
    final checkedInAt = passenger['checked_in_at'];

    if (checkedInAt != null &&
        checkedInAt.toString().trim().isNotEmpty &&
        checkedInAt.toString().toLowerCase() != 'null') {
      return true;
    }

    final checked = passenger['checked_in'];

    if (checked == true || checked == 1 || '$checked' == '1') {
      return true;
    }

    final status = _text(
      passenger['status'],
      fallback: '',
    ).toLowerCase();

    return status == 'checked_in' ||
        status == 'checked-in' ||
        status == 'checked in';
  }

  Future<void> _checkIn(
      Map<String, dynamic> passenger,
      ) async {
    final passengerId = _passengerId(passenger);

    if (passengerId <= 0) {
      _showMessage(
        'Passenger ID was not returned by the server.',
        error: true,
      );
      return;
    }

    if (_checkedIn(passenger)) {
      _showMessage(
        'This passenger is already checked in.',
      );
      return;
    }

    if (checkingPassengers.contains(passengerId)) {
      return;
    }

    setState(() {
      checkingPassengers.add(passengerId);
    });

    try {
      final response = await widget.service.checkIn(
        widget.tripId,
        passengerId,
      );

      if (!mounted) return;

      if (response is Map) {
        final data = Map<String, dynamic>.from(response);

        final returnedPassenger = data['passenger'] is Map
            ? Map<String, dynamic>.from(data['passenger'])
            : null;

        if (returnedPassenger != null) {
          passenger.addAll(returnedPassenger);
        }
      }

      setState(() {
        passenger['checked_in'] = true;
        passenger['checked_in_at'] ??=
            DateTime.now().toIso8601String();
      });

      _showMessage(
        'Passenger checked in successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          checkingPassengers.remove(passengerId);
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('ApiException: ', '');
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        error ? Colors.red.shade700 : green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final booking = widget.booking;

    final bookingReference = _text(
      ticket['booking_reference'] ??
          booking['booking_reference'],
    );

    final primaryName = _text(
      ticket['primary_passenger_name'] ??
          booking['primary_passenger_name'],
    );

    final primaryNic = _text(
      ticket['primary_passenger_nic'] ??
          booking['primary_passenger_nic'],
    );

    final boarding = _text(
      ticket['boarding_stop'] ??
          booking['boarding_stop'] ??
          booking['origin'],
    );

    final dropoff = _text(
      ticket['dropoff_stop'] ??
          booking['dropoff_stop'] ??
          booking['destination'],
    );

    final ticketStatus = _text(
      ticket['ticket_status'] ??
          booking['ticket_status'] ??
          ticket['status'],
      fallback: 'VALID',
    );

    final busName = _text(
      ticket['bus_name'] ??
          booking['bus_name'],
    );

    final busNumber = _text(
      ticket['bus_number'] ??
          booking['bus_number'],
    );

    final tripCode = _text(
      ticket['trip_code'] ??
          booking['trip_code'],
    );

    final serviceDate = _text(
      ticket['service_date'] ??
          booking['service_date'],
    );

    final boardingTime = _text(
      ticket['boarding_time'] ??
          booking['boarding_time'],
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD7DBE4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                28,
              ),
              children: [
                _successHeader(ticketStatus),

                const SizedBox(height: 16),

                _sectionTitle(
                  'Booking Information',
                  Icons.confirmation_number_outlined,
                ),

                const SizedBox(height: 10),

                _infoCard(
                  children: [
                    _infoRow(
                      'Booking Reference',
                      bookingReference,
                    ),
                    _divider(),
                    _infoRow(
                      'Primary Passenger',
                      primaryName,
                    ),
                    _divider(),
                    _infoRow(
                      'NIC',
                      primaryNic,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _sectionTitle(
                  'Journey Details',
                  Icons.route_outlined,
                ),

                const SizedBox(height: 10),

                _journeyCard(
                  boarding: boarding,
                  dropoff: dropoff,
                  date: serviceDate,
                  time: boardingTime,
                ),

                const SizedBox(height: 12),

                _infoCard(
                  children: [
                    _infoRow(
                      'Bus',
                      busName,
                    ),
                    _divider(),
                    _infoRow(
                      'Bus Number',
                      busNumber,
                    ),
                    _divider(),
                    _infoRow(
                      'Trip Code',
                      tripCode,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Passengers',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFB),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.passengers.length}',
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (widget.passengers.isEmpty)
                  _emptyPassengers(),

                ...widget.passengers.map(
                      (passenger) =>
                      _passengerCard(passenger),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Close Ticket',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: const BorderSide(
                        color: primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successHeader(String ticketStatus) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F9D67),
            Color(0xFF19B978),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Ticket Verified',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'This EastBus ticket is valid for this trip.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ticketStatus.toUpperCase(),
              style: const TextStyle(
                color: green,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
      String title,
      IconData icon,
      ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE9EDF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _infoRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 11,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      color: Color(0xFFEDF0F5),
    );
  }

  Widget _journeyCard({
    required String boarding,
    required String dropoff,
    required String date,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EDF5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.radio_button_checked,
                color: green,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  boarding,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 28,
                  color: const Color(0xFFD7DEEA),
                ),
              ],
            ),
          ),

          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFE84C4C),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropoff,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 26),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: textMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passengerCard(
      Map<String, dynamic> passenger,
      ) {
    final passengerId = _passengerId(passenger);
    final checkedIn = _checkedIn(passenger);
    final loading =
    checkingPassengers.contains(passengerId);

    final seat = _text(
      passenger['seat_number'],
    );

    final gender = _text(
      passenger['gender'],
    );

    final passengerName = _text(
      passenger['passenger_name'],
      fallback: _text(
        widget.ticket['primary_passenger_name'] ??
            widget.booking['primary_passenger_name'],
        fallback: 'Passenger',
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: checkedIn
              ? const Color(0xFFB9E7D1)
              : const Color(0xFFE7EBF2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checkedIn
                      ? const Color(0xFFE7F7EF)
                      : const Color(0xFFE8EEFB),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Text(
                  seat,
                  style: TextStyle(
                    color:
                    checkedIn ? green : primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gender == '-'
                          ? 'Gender not available'
                          : 'Gender: ${gender.toUpperCase()}',
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (checkedIn)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EF),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: green,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Checked In',
                        style: TextStyle(
                          color: green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (checkedIn &&
              passenger['checked_in_at'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Checked in at ${_formatCheckInTime(passenger['checked_in_at'])}',
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          if (!checkedIn) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: loading
                    ? null
                    : () => _checkIn(passenger),
                icon: loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.how_to_reg_rounded,
                  size: 20,
                ),
                label: Text(
                  loading
                      ? 'Checking In...'
                      : 'Check In Passenger',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyPassengers() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: textMuted,
          ),
          SizedBox(height: 10),
          Text(
            'No passenger details available',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCheckInTime(dynamic raw) {
    final value = raw?.toString().trim() ?? '';

    if (value.isEmpty ||
        value.toLowerCase() == 'null') {
      return '-';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute =
    date.minute.toString().padLeft(2, '0');

    final period =
    date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}