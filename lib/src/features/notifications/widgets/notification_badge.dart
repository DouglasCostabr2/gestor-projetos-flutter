import 'package:flutter/material.dart';
import '../../../../modules/notifications/module.dart';

/// Badge que exibe o contador de notificações não lidas
/// Atualiza em tempo real quando novas notificações chegam
///
/// IMPORTANTE: Este widget agora depende do NotificationRealtimeService global
/// para receber atualizações em tempo real. Ele apenas escuta eventos locais
/// via NotificationEventBus.
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

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToLocalEvents();
  }

  @override
  void dispose() {
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
      final count = await notificationsModule.getUnreadCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (e) {
      debugPrint('Erro ao carregar contador de notificações: $e');
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

