class TripPassenger {
  final int id;
  final String seatNumber;
  final String passengerName;
  final String nic;
  final String gender;
  final bool checkedIn;
  final DateTime? checkedInAt;

  const TripPassenger({
    required this.id,
    required this.seatNumber,
    required this.passengerName,
    required this.nic,
    required this.gender,
    required this.checkedIn,
    this.checkedInAt,
  });

  factory TripPassenger.fromJson(Map<String, dynamic> json) {
    final checkedInValue = json['checked_in_at'];

    return TripPassenger(
      id: _toInt(
        json['booking_passenger_id'] ?? json['id'],
      ),
      seatNumber: _text(
        json['seat_number'],
      ),
      passengerName: _text(
        json['passenger_name'],
      ),
      nic: _text(
        json['nic'],
      ),
      gender: _formatGender(
        json['gender'],
      ),
      checkedIn: checkedInValue != null &&
          checkedInValue.toString().trim().isNotEmpty,
      checkedInAt: checkedInValue != null
          ? DateTime.tryParse(checkedInValue.toString())
          : null,
    );
  }

  static int _toInt(dynamic value) {
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    return text;
  }

  static String _formatGender(dynamic value) {
    final gender = _text(value);

    if (gender == '-') {
      return '-';
    }

    switch (gender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return gender;
    }
  }
}