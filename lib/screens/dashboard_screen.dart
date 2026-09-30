import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'trip_detail_screen.dart';
import 'trips_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  Object? error;
  bool loading = false;
  int nav = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await ApiService.dashboard();

      if (!mounted) {
        return;
      }

      setState(() {
        data = result;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Map<String, dynamic> get _staff {
    final raw = data?['staff'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Map<String, dynamic> get _stats {
    final raw = data?['stats'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Map<String, dynamic>? get _activeTripMap {
    final raw = data?['active_trip'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }

  Trip? get _activeTrip {
    final raw = _activeTripMap;

    if (raw == null) {
      return null;
    }

    try {
      return Trip.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openActiveTrip() async {
    final trip = _activeTrip;

    if (trip == null || trip.id <= 0) {
      snack(
        context,
        'No active trip is available.',
        error: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(trip: trip),
      ),
    );

    if (mounted) {
      await load();
    }
  }

  Future<void> _openScanner() async {
    final trip = _activeTrip;

    if (trip == null || trip.id <= 0) {
      snack(
        context,
        'Start the assigned trip before scanning tickets.',
        error: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(tripId: trip.id),
      ),
    );

    if (mounted) {
      await load();
    }
  }

  void _setNav(int index) {
    if (index == 2) {
      _openScanner();
      return;
    }

    setState(() {
      nav = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (nav == 1) {
      return TripsScreen(
        onBack: () {
          setState(() {
            nav = 0;
          });
          load();
        },
      );
    }

    if (nav == 3) {
      return NotificationsScreen(
        onBack: () => setState(() => nav = 0),
      );
    }

    if (nav == 4) {
      return ProfileScreen(
        onBack: () => setState(() => nav = 0),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EastBus Trip Management'),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: _setNav,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.route),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (data == null && error != null) {
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

    if (data == null) {
      return const LoadingView();
    }

    final staff = _staff;
    final stats = _stats;
    final activeTrip = _activeTrip;
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$greeting,',
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          Text(
            '${staff['full_name'] ?? 'Staff'}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2D7A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(
                    Icons.person,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${staff['role'] ?? ''}'.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${staff['login_id'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    activeTrip != null ? 'ON TRIP' : 'ON DUTY',
                  ),
                  backgroundColor:
                  activeTrip != null ? Colors.greenAccent : Colors.white,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Trips',
                  value: '${stats['today_trips'] ?? 0}',
                  icon: Icons.route,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Passengers',
                  value: '${stats['passengers'] ?? 0}',
                  icon: Icons.people,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Checked In',
                  value: '${stats['checked_in'] ?? 0}',
                  icon: Icons.verified,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Text(
            "Today's Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _action(
                Icons.route,
                'Trips',
                    () => setState(() => nav = 1),
              ),
              _action(
                Icons.qr_code_scanner,
                'Scan Ticket',
                _openScanner,
              ),
              _action(
                Icons.location_on,
                'Tracking',
                activeTrip != null
                    ? _openActiveTrip
                    : () => setState(() => nav = 1),
              ),
              _action(
                Icons.notifications,
                'Notifications',
                    () => setState(() => nav = 3),
              ),
              _action(
                Icons.warning_amber,
                'Emergency',
                activeTrip != null
                    ? _openActiveTrip
                    : () {
                  snack(
                    context,
                    'No active trip is available.',
                    error: true,
                  );
                },
              ),
              _action(
                Icons.person,
                'Profile',
                    () => setState(() => nav = 4),
              ),
            ],
          ),

          if (activeTrip != null) ...[
            const SizedBox(height: 18),
            const Text(
              'Active Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: InkWell(
                onTap: _openActiveTrip,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF064BD8),
                  ),
                  title: Text(
                    '${activeTrip.origin} → ${activeTrip.destination}',
                  ),
                  subtitle: Text(
                    '${activeTrip.busNumber}'
                        '${activeTrip.tripCode.isNotEmpty ? ' • ${activeTrip.tripCode}' : ''}',
                  ),
                  trailing: const Chip(
                    label: Text('ON TRIP'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action(
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE1E7F3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFF064BD8),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}