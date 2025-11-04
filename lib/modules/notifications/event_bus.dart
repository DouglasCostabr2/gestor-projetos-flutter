import 'package:flutter/foundation.dart';

/// Eventos de notificações para sincronização local
enum NotificationEventType {
  markedAsRead,
  markedAllAsRead,
  deleted,
  created,
}

/// Evento de notificação
class NotificationEvent {
  final NotificationEventType type;
  final String? notificationId;
  final int? count;

  const NotificationEvent({
    required this.type,
    this.notificationId,
    this.count,
  });
}

/// Event bus para sincronizar eventos de notificações localmente
/// Isso garante atualização instantânea entre widgets sem depender do realtime
class NotificationEventBus {
  static final NotificationEventBus _instance = NotificationEventBus._internal();
  factory NotificationEventBus() => _instance;
  NotificationEventBus._internal();

  final _eventController = ValueNotifier<NotificationEvent?>(null);

  /// Stream de eventos
  ValueListenable<NotificationEvent?> get events => _eventController;

  /// Emitir evento de notificação marcada como lida
  void emitMarkedAsRead(String notificationId) {
    _eventController.value = NotificationEvent(
      type: NotificationEventType.markedAsRead,
      notificationId: notificationId,
    );
  }

  /// Emitir evento de todas as notificações marcadas como lidas
  void emitMarkedAllAsRead() {
    _eventController.value = const NotificationEvent(
      type: NotificationEventType.markedAllAsRead,
    );
  }

  /// Emitir evento de notificação deletada
  void emitDeleted(String notificationId, bool wasUnread) {
    _eventController.value = NotificationEvent(
      type: NotificationEventType.deleted,
      notificationId: notificationId,
      count: wasUnread ? 1 : 0,
    );
  }

  /// Emitir evento de notificação criada
  void emitCreated(bool isUnread) {
    _eventController.value = NotificationEvent(
      type: NotificationEventType.created,
      count: isUnread ? 1 : 0,
    );
  }

  /// Limpar evento atual
  void clear() {
    _eventController.value = null;
  }

  /// Dispose
  void dispose() {
    _eventController.dispose();
  }
}

/// Instância global do event bus
final notificationEventBus = NotificationEventBus();

