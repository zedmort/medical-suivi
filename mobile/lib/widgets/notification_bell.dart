import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/local_notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  List<Map<String, dynamic>> _notifications = [];
  Timer? _pollTimer;
  final Set<int> _seenNotificationIds = <int>{};
  static const String _seenIdsKey = 'bg_seen_notification_ids';

  @override
  void initState() {
    super.initState();
    LocalNotificationService.initialize();
    _initAndFetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _fetch());
  }

  Future<void> _initAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenIdsKey) ?? <String>[];
    _seenNotificationIds
      ..clear()
      ..addAll(
        seen
            .map((e) => int.tryParse(e))
            .whereType<int>(),
      );
    await _fetch();
  }

  Future<void> _persistSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenIdsKey,
      _seenNotificationIds.map((e) => e.toString()).toList(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService.get('/notifications');
      final incoming = List<Map<String, dynamic>>.from(res['notifications'] ?? []);

      var seenChanged = false;
      for (final n in incoming) {
        final id = _asInt(n['id']);
        if (id == null) continue;
        final isUnread = _isUnread(n['is_read']);
        if (isUnread && !_seenNotificationIds.contains(id)) {
          _seenNotificationIds.add(id);
          seenChanged = true;
          await LocalNotificationService.show(
            id: id,
            title: (n['title']?.toString().isNotEmpty ?? false)
                ? n['title'].toString()
                : 'Nouvelle notification',
            body: (n['body']?.toString().isNotEmpty ?? false)
                ? n['body'].toString()
                : 'Vous avez une nouvelle alerte.',
          );
        }
      }

      if (seenChanged) {
        await _persistSeen();
      }

      if (!mounted) return;
      setState(() {
        _unread = _asInt(res['unread']) ?? 0;
        _notifications = incoming;
      });
    } catch (_) {}
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isUnread(dynamic value) {
    if (value is int) return value == 0;
    if (value is bool) return value == false;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == null || normalized == '0' || normalized == 'false';
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.patch('/notifications/read-all', {});
      setState(() {
        _unread = 0;
        for (final n in _notifications) {
          n['is_read'] = 1;
        }
      });
    } catch (_) {}
  }

  void _open() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationSheet(
        notifications: _notifications,
        onMarkAllRead: _markAllRead,
        onRefresh: _fetch,
      ),
    ).then((_) => _fetch());
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white),
          if (_unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: _open,
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final VoidCallback onMarkAllRead;
  final VoidCallback onRefresh;

  const _NotificationSheet({
    required this.notifications,
    required this.onMarkAllRead,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── handle ──
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // ── header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (notifications.any((n) => n['is_read'] == 0))
                    TextButton(
                      onPressed: onMarkAllRead,
                      child: const Text('Tout lire',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── list ──
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          const Text('Aucune notification',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final n = notifications[i];
                        final unread = n['is_read'] == 0;
                        final type = n['type']?.toString() ?? 'info';
                        return ListTile(
                          tileColor: unread
                              ? const Color(0xFFE3F2FD)
                              : Colors.transparent,
                          leading: CircleAvatar(
                            backgroundColor:
                                _typeColor(type).withAlpha(40),
                            child: Icon(_typeIcon(type),
                                color: _typeColor(type), size: 20),
                          ),
                          title: Text(n['title']?.toString() ?? '',
                              style: TextStyle(
                                  fontWeight: unread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['body']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                _fmtDate(
                                    n['created_at']?.toString()),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'analysis':
        return Colors.blue;
      case 'analysis_due':
        return Colors.deepPurple;
      case 'analysis_result':
        return Colors.green;
      case 'prescription':
        return Colors.orange;
      case 'dispensed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'analysis':
        return Icons.biotech_outlined;
      case 'analysis_due':
        return Icons.event_available_outlined;
      case 'analysis_result':
        return Icons.assignment_turned_in_outlined;
      case 'prescription':
        return Icons.local_pharmacy_outlined;
      case 'dispensed':
        return Icons.delivery_dining;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
