import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../modules/notifications/module.dart';

/// Badge que exibe o contador de notificações não lidas
/// Atualiza em tempo real quando novas notificações chegam
class NotificationBadge extends StatefulWidget {
  final Widget child;
  final bool showZero;

  const NotificationBadge({
    super.key,
    required this.child,
    this.showZero = false,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;
  RealtimeChannel? _realtimeChannel;
  // Cache para rastrear o estado anterior das notificações
  final Map<String, bool> _notificationReadStatus = {};

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToRealtime();
    _subscribeToLocalEvents();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    notificationEventBus.events.removeListener(_handleLocalEvent);
    super.dispose();
  }

  void _subscribeToLocalEvents() {
    notificationEventBus.events.addListener(_handleLocalEvent);
  }

  void _handleLocalEvent() {
    final event = notificationEventBus.events.value;
    if (event == null || !mounted) return;

    switch (event.type) {
      case NotificationEventType.markedAsRead:
        setState(() {
          if (_unreadCount > 0) _unreadCount--;
        });
        break;

      case NotificationEventType.markedAllAsRead:
        setState(() {
          _unreadCount = 0;
        });
        break;

      case NotificationEventType.deleted:
        if (event.count != null && event.count! > 0) {
          setState(() {
            if (_unreadCount > 0) _unreadCount--;
          });
        }
        break;

      case NotificationEventType.created:
        if (event.count != null && event.count! > 0) {
          setState(() {
            _unreadCount++;
          });
        }
        break;
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      // Carregar todas as notificações para popular o cache de status
      final notifications = await notificationsModule.getNotifications(limit: 100);
      final count = await notificationsModule.getUnreadCount();

      if (mounted) {
        // Popular o cache com o estado atual
        for (final notification in notifications) {
          _notificationReadStatus[notification.id] = notification.isRead;
        }

        setState(() => _unreadCount = count);
      }
    } catch (e) {
      debugPrint('Erro ao carregar contador de notificações: $e');
    }
  }

  void _subscribeToRealtime() {
    try {
      _realtimeChannel = notificationsModule.subscribeToNotifications(
        onInsert: (notification) {
          if (mounted) {
            _notificationReadStatus[notification.id] = notification.isRead;
            if (!notification.isRead) {
              setState(() => _unreadCount++);
            }
          }
        },
        onUpdate: (notification) {
          if (mounted) {
            final wasRead = _notificationReadStatus[notification.id];
            _notificationReadStatus[notification.id] = notification.isRead;

            // Se mudou de não lida para lida, decrementar
            if (wasRead == false && notification.isRead) {
              setState(() {
                if (_unreadCount > 0) _unreadCount--;
              });
            }
            // Se mudou de lida para não lida, incrementar
            else if (wasRead == true && !notification.isRead) {
              setState(() => _unreadCount++);
            }
          }
        },
        onDelete: (notification) {
          if (mounted) {
            final wasRead = _notificationReadStatus[notification.id];
            _notificationReadStatus.remove(notification.id);

            if (wasRead == false) {
              setState(() {
                if (_unreadCount > 0) _unreadCount--;
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Erro ao se inscrever em notificações: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldShow = _unreadCount > 0 || widget.showZero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (shouldShow)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF151515),
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

