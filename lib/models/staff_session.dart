class StaffSession {
  final int id;
  final int operatorId;
  final String fullName;
  final String role;
  final String loginId;
  final String phone;
  final String email;

  const StaffSession({
    required this.id,
    required this.operatorId,
    required this.fullName,
    required this.role,
    required this.loginId,
    required this.phone,
    required this.email,
  });

  factory StaffSession.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] is Map
        ? Map<String, dynamic>.from(json['staff'])
        : json;

    return StaffSession(
      id: _toInt(staff['id']),
      operatorId: _toInt(staff['operator_id']),
      fullName: _text(staff['full_name'] ?? staff['name']),
      role: _normalizeRole(staff['role']),
      loginId: _text(staff['login_id']),
      phone: _text(staff['phone']),
      email: _text(staff['email']),
    );
  }

  bool get isDriver => role.toLowerCase() == 'driver';

  bool get isConductor => role.toLowerCase() == 'conductor';

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (loginId.isNotEmpty) return loginId;
    return 'Staff';
  }

  String get displayRole {
    if (role.isEmpty) return 'Staff';

    return role
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length == 1) return part.toUpperCase();

      return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
    })
        .join(' ');
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  static String _normalizeRole(dynamic value) {
    return _text(value)
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  String toString() {
    return 'StaffSession(id: $id, fullName: $fullName, role: $role, loginId: $loginId, operatorId: $operatorId)';
  }
}