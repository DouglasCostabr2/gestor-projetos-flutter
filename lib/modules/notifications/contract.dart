import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Contrato público do módulo de notificações
/// Define as operações disponíveis para gestão de notificações
///
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de notificações.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class NotificationsContract {
  /// Buscar todas as notificações do usuário atual
  /// 
  /// Parâmetros opcionais:
  /// - [limit]: Quantidade máxima de notificações a retornar
  /// - [offset]: Quantidade de notificações a pular (paginação)
  /// - [unreadOnly]: Se true, retorna apenas notificações não lidas
  Future<List<Notification>> getNotifications({
    int? limit,
    int? offset,
    bool unreadOnly = false,
  });

  /// Buscar notificações não lidas do usuário atual
  Future<List<Notification>> getUnreadNotifications();

  /// Buscar uma notificação específica por ID
  Future<Notification?> getNotificationById(String notificationId);

  /// Contar notificações não lidas do usuário atual
  Future<int> getUnreadCount();

  /// Obter estatísticas de notificações
  Future<NotificationStats> getStats();

  /// Marcar uma notificação como lida
  Future<void> markAsRead(String notificationId);

  /// Marcar múltiplas notificações como lidas
  Future<void> markMultipleAsRead(List<String> notificationIds);

  /// Marcar todas as notificações como lidas
  Future<void> markAllAsRead();

  /// Deletar uma notificação
  Future<void> deleteNotification(String notificationId);

  /// Deletar múltiplas notificações
  Future<void> deleteMultipleNotifications(List<String> notificationIds);

  /// Deletar todas as notificações lidas
  Future<void> deleteAllRead();

  /// Criar uma notificação manualmente (uso interno/admin)
  Future<Notification> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    NotificationEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  });

  /// Inscrever-se para receber atualizações em tempo real de notificações
  /// 
  /// Retorna um RealtimeChannel que deve ser cancelado quando não for mais necessário
  RealtimeChannel subscribeToNotifications({
    required Function(Notification) onInsert,
    required Function(Notification) onUpdate,
    required Function(Notification) onDelete,
  });

  /// Executar verificação de tarefas que vencem em breve
  /// Retorna quantidade de notificações criadas
  Future<int> checkTasksDueSoon();

  /// Executar verificação de tarefas vencidas
  /// Retorna quantidade de notificações criadas
  Future<int> checkTasksOverdue();

  /// Limpar notificações antigas (lidas)
  /// 
  /// [daysToKeep]: Quantidade de dias para manter notificações lidas (padrão: 90)
  /// Retorna quantidade de notificações deletadas
  Future<int> cleanupOldNotifications({int daysToKeep = 90});
}

