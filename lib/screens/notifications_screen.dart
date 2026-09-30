import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationsScreen({
    super.key,
    this.onBack,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? notifications;
  Object? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.notifications();

      if (!mounted) return;

      setState(() {
        notifications = result;
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

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null'
        ? fallback
        : text;
  }

  String _dateText(Map<String, dynamic> notification) {
    return _text(
      notification['sent_at'] ??
          notification['created_at'] ??
          notification['updated_at'],
    );
  }

  IconData _icon(Map<String, dynamic> notification) {
    final type = _text(
      notification['type'] ?? notification['category'],
    ).toLowerCase();

    if (type.contains('emergency') || type.contains('alert')) {
      return Icons.warning_amber_rounded;
    }

    if (type.contains('trip')) {
      return Icons.directions_bus;
    }

    if (type.contains('booking') || type.contains('ticket')) {
      return Icons.confirmation_number_outlined;
    }

    return Icons.notifications;
  }

  Color _iconColor(Map<String, dynamic> notification) {
    final type = _text(
      notification['type'] ?? notification['category'],
    ).toLowerCase();

    if (type.contains('emergency') || type.contains('alert')) {
      return Colors.red;
    }

    return const Color(0xFF064BD8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
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
    if (notifications == null && error != null) {
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

    if (notifications == null) {
      return const LoadingView();
    }

    if (notifications!.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            EmptyView('No notifications available.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: notifications!.length,
        itemBuilder: (context, index) {
          final notification = notifications![index];

          final title = _text(
            notification['title'],
            fallback: 'Update',
          );

          final message = _text(
            notification['message'],
            fallback: 'No details available.',
          );

          final date = _dateText(notification);
          final iconColor = _iconColor(notification);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(
                  _icon(notification),
                  color: iconColor,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              date,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}