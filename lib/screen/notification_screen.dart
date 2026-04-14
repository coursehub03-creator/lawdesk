import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/notification_db.dart';
import '../model/notification_model.dart';
import 'sessions_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Future<List<AppNotification>>? _future;
  bool _unreadOnly = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = NotificationDB.getAllNotifications(unreadOnly: _unreadOnly);
    });
    final count = await NotificationDB.getUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  Future<void> _deleteNotification(AppNotification n) async {
    if (n.localId != null) {
      await NotificationDB.deleteNotification(n.localId!);
    } else if ((n.firebaseId ?? '').trim().isNotEmpty) {
      await NotificationDB.deleteByFirebaseId(n.firebaseId!.trim());
    }
    await _refresh();
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.localId != null) {
      await NotificationDB.markAsRead(n.localId!);
    }
    await _refresh();
  }

  Future<void> _markAllRead() async {
    await NotificationDB.markAllAsRead();
    await _refresh();
  }

  Future<void> _deleteAll() async {
    await NotificationDB.clearAllNotifications();
    await _refresh();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);

    if (day == today) {
      return 'اليوم • ${DateFormat('HH:mm').format(dt)}';
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return 'أمس • ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('yyyy/MM/dd • HH:mm').format(dt);
  }

  Future<void> _openLinked(AppNotification n) async {
    // Mark read first for better UX
    await _markAsRead(n);

    // If we have a linked case, open its sessions.
    final fc = (n.firebaseCaseId ?? '').trim();
    final localCaseId = n.caseId ?? 0;

    if (fc.isEmpty && localCaseId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الإشعار غير مرتبط بقضية.')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionsScreen(
          caseId: localCaseId,
          caseTitle: 'جلسات القضية',
          firebaseCaseId: fc.isEmpty ? null : fc,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف كل الإشعارات؟'),
        content: const Text('سيتم حذف جميع الإشعارات من الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('الإشعارات'),
            const SizedBox(width: 8),
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'toggle') {
                setState(() => _unreadOnly = !_unreadOnly);
                await _refresh();
                return;
              }
              if (value == 'markAll') {
                await _markAllRead();
                return;
              }
              if (value == 'deleteAll') {
                await _confirmDeleteAll();
                return;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(_unreadOnly ? 'عرض الكل' : 'غير مقروء فقط'),
              ),
              const PopupMenuItem(
                value: 'markAll',
                child: Text('تحديد الكل كمقروء'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'deleteAll',
                child: Text('حذف الكل'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 56, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    _unreadOnly ? 'لا توجد إشعارات غير مقروءة' : 'لا توجد إشعارات',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ستظهر تذكيرات الجلسات هنا تلقائيًا.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final n = data[index];
                final isUnread = !n.isRead;

                return Dismissible(
                  key: ValueKey(n.localId ?? n.firebaseId ?? index),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف الإشعار؟'),
                            content: const Text('هل أنت متأكد من حذف هذا الإشعار؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => _deleteNotification(n),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red.withOpacity(0.85),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      onTap: () => _openLinked(n),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isUnread
                              ? theme.colorScheme.primary.withOpacity(0.18)
                              : theme.dividerColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications,
                          color: isUnread ? theme.colorScheme.primary : theme.hintColor,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(n.timestamp),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'read') {
                            await _markAsRead(n);
                            return;
                          }
                          if (value == 'delete') {
                            await _deleteNotification(n);
                            return;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'read', child: Text('تحديد كمقروء')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
