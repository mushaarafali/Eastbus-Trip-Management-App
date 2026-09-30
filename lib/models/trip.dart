class Trip {
  final int id;
  final String tripCode;
  final String routeName;
  final String origin;
  final String destination;
  final String busNumber;
  final String busName;
  final String serviceDate;
  final String departureTime;
  final String arrivalTime;
  final String status;
  final int bookedPassengers;
  final int seatCount;

  const Trip({
    required this.id,
    required this.tripCode,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.busNumber,
    required this.busName,
    required this.serviceDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.status,
    required this.bookedPassengers,
    required this.seatCount,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final route = json['route'] is Map
        ? Map<String, dynamic>.from(json['route'] as Map)
        : <String, dynamic>{};

    final bus = json['bus'] is Map
        ? Map<String, dynamic>.from(json['bus'] as Map)
        : <String, dynamic>{};

    return Trip(
      id: _toInt(json['id'] ?? json['trip_id']),
      tripCode: _text(json['trip_code']),
      routeName: _text(
        json['route_name'] ?? route['name'],
      ),
      origin: _text(
        json['origin'] ?? route['origin'],
      ),
      destination: _text(
        json['destination'] ?? route['destination'],
      ),
      busNumber: _text(
        json['bus_number'] ?? bus['bus_number'],
      ),
      busName: _text(
        json['bus_name'] ?? bus['bus_name'],
      ),
      serviceDate: _date(
        json['service_date'],
      ),
      departureTime: _time(
        json['departure_time'],
      ),
      arrivalTime: _time(
        json['arrival_time'],
      ),
      status: _status(
        json['status'],
      ),
      bookedPassengers: _toInt(
        json['booked_passengers'] ??
            json['booked_passengers_count'] ??
            json['passenger_count'],
      ),
      seatCount: _toInt(
        json['seat_count'] ?? bus['seat_count'],
      ),
    );
  }

  int get availableSeats {
    final available = seatCount - bookedPassengers;
    return available < 0 ? 0 : available;
  }

  bool get isScheduled => status == 'scheduled';

  bool get isActive => status == 'active';

  bool get isCompleted => status == 'completed';

  static int _toInt(dynamic value) {
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  static String _date(dynamic value) {
    final text = _text(value);

    if (text.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(text);

    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
    }

    return text;
  }

  static String _time(dynamic value) {
    final text = _text(value);

    if (text.isEmpty) {
      return '';
    }

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);

    if (match == null) {
      return text;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return text;
    }

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  static String _status(dynamic value) {
    final status = _text(value).toLowerCase();

    if (status.isEmpty) {
      return 'scheduled';
    }

    if (status == 'on_trip' ||
        status == 'on trip' ||
        status == 'on-trip') {
      return 'active';
    }

    return status;
  }
}