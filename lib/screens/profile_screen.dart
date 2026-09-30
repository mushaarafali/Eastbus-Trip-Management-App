import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfileScreen({
    super.key,
    this.onBack,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? me;
  Object? error;
  bool loading = false;
  bool loggingOut = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final data = await ApiService.me();

      if (!mounted) return;

      setState(() {
        me = data;
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

  Future<void> logout() async {
    if (loggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout from EastBus Trip Management?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => loggingOut = true);

    try {
      await ApiService.logout();
    } catch (_) {
      // ApiService.logout() already clears the local session.
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (_) => false,
    );
  }

  String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    return text;
  }

  Map<String, dynamic> _operator() {
    final operator = me?['operator'];

    if (operator is Map) {
      return Map<String, dynamic>.from(operator);
    }

    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: const Text('Staff Profile'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
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
    if (me == null && error != null) {
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
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (me == null) {
      return const LoadingView();
    }

    final role = _text(me!['role']).toLowerCase();
    final operator = _operator();

    final companyName = _text(
      me!['company_name'] ?? operator['company_name'],
    );

    final isActiveValue = me!['is_active'];
    final isActive = isActiveValue == true ||
        isActiveValue == 1 ||
        isActiveValue?.toString() == '1';

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 48,
              child: Icon(
                Icons.person,
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              _text(me!['full_name']),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Center(
            child: Text(
              role == '-' ? 'STAFF' : role.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF064BD8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Chip(
              avatar: Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: isActive ? Colors.green : Colors.red,
              ),
              label: Text(
                isActive ? 'ACTIVE' : 'INACTIVE',
              ),
            ),
          ),

          const SizedBox(height: 14),

          _profileItem(
            icon: Icons.badge,
            title: 'Login ID',
            value: _text(me!['login_id']),
          ),

          _profileItem(
            icon: Icons.credit_card,
            title: 'NIC',
            value: _text(me!['nic']),
          ),

          _profileItem(
            icon: Icons.phone,
            title: 'Phone',
            value: _text(me!['phone']),
          ),

          _profileItem(
            icon: Icons.email,
            title: 'Email',
            value: _text(me!['email']),
          ),

          if (companyName != '-')
            _profileItem(
              icon: Icons.business,
              title: 'Bus Operator',
              value: companyName,
            ),

          if (role == 'driver')
            _profileItem(
              icon: Icons.drive_eta,
              title: 'Driving Licence',
              value: _text(me!['driving_licence_no']),
            ),

          _profileItem(
            icon: Icons.verified_user,
            title: 'NTC Licence / ID',
            value: _text(me!['ntc_licence_no']),
          ),

          const SizedBox(height: 12),

          const Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Color(0xFF064BD8),
              ),
              title: Text('View-only Profile'),
              subtitle: Text(
                'Protected staff information can only be changed by your Bus Operator.',
              ),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: loggingOut ? null : logout,
            icon: loggingOut
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.logout),
            label: Text(
              loggingOut ? 'Logging out...' : 'Logout',
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF064BD8),
        ),
        title: Text(title),
        subtitle: Text(
          value.trim().isEmpty ? '-' : value,
        ),
      ),
    );
  }
}