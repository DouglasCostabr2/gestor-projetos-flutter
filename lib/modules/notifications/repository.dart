import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
import 'contract.dart';
import 'models.dart';

/// Implementação do contrato de notificações
///
/// IMPORTANTE: Esta classe é INTERNA ao módulo.
/// O mundo externo deve usar apenas o contrato NotificationsContract.
class NotificationsRepository implements NotificationsContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Notification>> getNotifications({
    int? limit,
    int? offset,
    bool unreadOnly = false,
  }) async {
    final user = authModule.currentUser;
    if (user == null) return [];

    final orgId = OrganizationContext.currentOrganizationId;
    debugPrint('🔔 [NOTIFICATIONS] getNotifications - User ID: ${user.id}');
    debugPrint('🔔 [NOTIFICATIONS] getNotifications - Current Org ID: ${orgId ?? "NULL"}');
    debugPrint('🔔 [NOTIFICATIONS] getNotifications - Unread only: $unreadOnly');

    // Observação: mesmo sem organização ativa, ainda retornamos convites recebidos (organization_invite_received)
    if (orgId == null) {
      debugPrint('🔔 [NOTIFICATIONS] Sem org ativa - buscando apenas convites');
      try {
        var queryBuilder = _client
            .from('notifications')
            .select('*')
            .eq('user_id', user.id)
            .eq('type', NotificationType.organizationInviteReceived.value);

        if (unreadOnly) {
          queryBuilder = queryBuilder.eq('is_read', false);
        }

        var orderedQuery = queryBuilder.order('created_at', ascending: false);

        if (limit != null && offset != null) {
          orderedQuery = orderedQuery.range(offset, offset + limit - 1);
        } else if (limit != null) {
          orderedQuery = orderedQuery.limit(limit);
        }

        final response = await orderedQuery;
        debugPrint('🔔 [NOTIFICATIONS] Convites encontrados (sem org): ${response.length}');
        final notifications = List<Map<String, dynamic>>.from(response)
            .map((json) => Notification.fromJson(json))
            .toList();
        debugPrint('🔔 [NOTIFICATIONS] Retornando ${notifications.length} convites');
        return notifications;
      } catch (e) {
        debugPrint('❌ [NOTIFICATIONS] Erro ao buscar convites de organização: $e');
        return [];
      }
    }

    debugPrint('🔔 [NOTIFICATIONS] Com org ativa - buscando notificações da org + convites');
    try {
      var queryBuilder = _client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .or('organization_id.eq.$orgId,type.eq.organization_invite_received');

      if (unreadOnly) {
        queryBuilder = queryBuilder.eq('is_read', false);
      }

      var orderedQuery = queryBuilder.order('created_at', ascending: false);

      if (limit != null && offset != null) {
        orderedQuery = orderedQuery.range(offset, offset + limit - 1);
      } else if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }

      final response = await orderedQuery;
      debugPrint('🔔 [NOTIFICATIONS] Notificações encontradas (com org): ${response.length}');
      final notifications = List<Map<String, dynamic>>.from(response)
          .map((json) => Notification.fromJson(json))
          .toList();
      debugPrint('🔔 [NOTIFICATIONS] Retornando ${notifications.length} notificações');
      for (var notif in notifications) {
        debugPrint('  - ${notif.type}: ${notif.title} (org: ${notif.organizationId})');
      }
      return notifications;
    } catch (e) {
      debugPrint('❌ [NOTIFICATIONS] Erro ao buscar notificações: $e');
      return [];
    }
  }

  @override
  Future<List<Notification>> getUnreadNotifications() async {
    return getNotifications(unreadOnly: true);
  }

  @override
  Future<Notification?> getNotificationById(String notificationId) async {
    final user = authModule.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('id', notificationId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Notification.fromJson(response);
    } catch (e) {
      debugPrint('❌ Erro ao buscar notificação: $e');
      return null;
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final user = authModule.currentUser;
    if (user == null) return 0;

    final orgId = OrganizationContext.currentOrganizationId;
    debugPrint('🔔 [NOTIFICATIONS] getUnreadCount - User ID: ${user.id}');
    debugPrint('🔔 [NOTIFICATIONS] getUnreadCount - Current Org ID: ${orgId ?? "NULL"}');

    try {
      var query = _client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      if (orgId != null) {
        // Contar notificações da org atual OU convites recebidos de qualquer org
        query = query.or('organization_id.eq.$orgId,type.eq.organization_invite_received');
      } else {
        // Sem org ativa: contar apenas convites recebidos
        query = query.eq('type', NotificationType.organizationInviteReceived.value);
      }

      final response = await query;
      final count = List<Map<String, dynamic>>.from(response).length;
      debugPrint('🔔 [NOTIFICATIONS] Contagem de não lidas: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao contar notificações não lidas: $e');
      return 0;
    }
  }

  @override
  Future<NotificationStats> getStats() async {
    final notifications = await getNotifications();
    return NotificationStats.fromNotifications(notifications);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', user.id);

      debugPrint('✅ Notificação marcada como lida: $notificationId');
    } catch (e) {
      debugPrint('❌ Erro ao marcar notificação como lida: $e');
      rethrow;
    }
  }

  @override
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', notificationIds)
          .eq('user_id', user.id);

      debugPrint('✅ ${notificationIds.length} notificações marcadas como lidas');
    } catch (e) {
      debugPrint('❌ Erro ao marcar notificações como lidas: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('is_read', false);

      debugPrint('✅ Todas as notificações marcadas como lidas');
    } catch (e) {
      debugPrint('❌ Erro ao marcar todas as notificações como lidas: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', user.id);

      debugPrint('✅ Notificação deletada: $notificationId');
    } catch (e) {
      debugPrint('❌ Erro ao deletar notificação: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .delete()
          .inFilter('id', notificationIds)
          .eq('user_id', user.id);

      debugPrint('✅ ${notificationIds.length} notificações deletadas');
    } catch (e) {
      debugPrint('❌ Erro ao deletar notificações: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllRead() async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('is_read', true);

      debugPrint('✅ Todas as notificações lidas foram deletadas');
    } catch (e) {
      debugPrint('❌ Erro ao deletar notificações lidas: $e');
      rethrow;
    }
  }

  @override
  Future<Notification> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    NotificationEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) {
      throw Exception('Nenhuma organização ativa');
    }

    try {
      final response = await _client.rpc('create_notification', params: {
        'p_user_id': userId,
        'p_organization_id': orgId,
        'p_type': type.value,
        'p_title': title,
        'p_message': message,
        'p_entity_type': entityType?.value,
        'p_entity_id': entityId,
        'p_metadata': metadata ?? {},
      });

      final notificationId = response as String;

      // Buscar a notificação criada
      final notification = await getNotificationById(notificationId);
      if (notification == null) {
        throw Exception('Notificação criada mas não encontrada');
      }

      debugPrint('✅ Notificação criada: $notificationId');
      return notification;
    } catch (e) {
      debugPrint('❌ Erro ao criar notificação: $e');
      rethrow;
    }
  }

  @override
  RealtimeChannel subscribeToNotifications({
    required Function(Notification) onInsert,
    required Function(Notification) onUpdate,
    required Function(Notification) onDelete,
  }) {
    final user = authModule.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }

    final channel = _client
        .channel('notifications_channel_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            try {
              final notification = Notification.fromJson(payload.newRecord);
              onInsert(notification);
            } catch (e) {
              debugPrint('❌ Erro ao processar notificação inserida: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            try {
              final notification = Notification.fromJson(payload.newRecord);
              onUpdate(notification);
            } catch (e) {
              debugPrint('❌ Erro ao processar notificação atualizada: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            try {
              final notification = Notification.fromJson(payload.oldRecord);
              onDelete(notification);
            } catch (e) {
              debugPrint('❌ Erro ao processar notificação deletada: $e');
            }
          },
        )
        .subscribe();

    debugPrint('✅ Inscrito em notificações em tempo real');
    return channel;
  }

  @override
  Future<int> checkTasksDueSoon() async {
    try {
      final response = await _client.rpc('notify_tasks_due_soon');
      final count = response as int;
      debugPrint('✅ Verificação de tarefas que vencem em breve: $count notificações criadas');
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao verificar tarefas que vencem em breve: $e');
      return 0;
    }
  }

  @override
  Future<int> checkTasksOverdue() async {
    try {
      final response = await _client.rpc('notify_tasks_overdue');
      final count = response as int;
      debugPrint('✅ Verificação de tarefas vencidas: $count notificações criadas');
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao verificar tarefas vencidas: $e');
      return 0;
    }
  }

  @override
  Future<int> cleanupOldNotifications({int daysToKeep = 90}) async {
    try {
      final response = await _client.rpc('cleanup_old_notifications', params: {
        'days_to_keep': daysToKeep,
      });
      final count = response as int;
      debugPrint('✅ Limpeza de notificações antigas: $count notificações removidas');
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao limpar notificações antigas: $e');
      return 0;
    }
  }
}

/// Instância singleton do repositório de notificações
/// Esta é a ÚNICA instância que deve ser usada em todo o aplicativo
final NotificationsContract notificationsModule = NotificationsRepository();
