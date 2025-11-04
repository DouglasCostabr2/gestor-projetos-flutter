import 'package:flutter/material.dart';
import '../../../../modules/notifications/models.dart' as models;

/// Widget para exibir uma notificação individual
class NotificationItem extends StatelessWidget {
  final models.Notification notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;
  final VoidCallback? onAcceptInvite;
  final VoidCallback? onRejectInvite;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
    this.onAcceptInvite,
    this.onRejectInvite,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF151515),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnread
              ? Color(notification.type.colorValue).withValues(alpha: 0.3)
              : const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone da notificação
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(notification.type.colorValue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconData(notification.type.iconName),
                    color: Color(notification.type.colorValue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Conteúdo da notificação
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título e badge de não lida
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                color: const Color(0xFFEAEAEA),
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Color(notification.type.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Mensagem
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9AA0A6),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Botões de aceitar/recusar convite (apenas para convites)
                      if (notification.type == models.NotificationType.organizationInviteReceived &&
                          (onAcceptInvite != null || onRejectInvite != null))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              if (onAcceptInvite != null)
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: onAcceptInvite,
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Aceitar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (onAcceptInvite != null && onRejectInvite != null)
                                const SizedBox(width: 8),
                              if (onRejectInvite != null)
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      onPressed: onRejectInvite,
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Recusar'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFEF4444),
                                        side: const BorderSide(color: Color(0xFFEF4444)),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Tempo e ações
                      Row(
                        children: [
                          // Tempo decorrido
                          Text(
                            notification.timeAgo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),

                          // Botão de marcar como lida (apenas se não lida)
                          if (isUnread && onMarkAsRead != null)
                            InkWell(
                              onTap: onMarkAsRead,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Color(0xFF9AA0A6),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Marcar como lida',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9AA0A6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Botão de deletar
                          if (onDelete != null)
                            InkWell(
                              onTap: onDelete,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'assignment_ind':
        return Icons.assignment_ind;
      case 'schedule':
        return Icons.schedule;
      case 'warning':
        return Icons.warning;
      case 'update':
        return Icons.update;
      case 'comment':
        return Icons.comment;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'folder_shared':
        return Icons.folder_shared;
      case 'folder':
        return Icons.folder;
      case 'alternate_email':
        return Icons.alternate_email;
      case 'payments':
        return Icons.payments;
      default:
        return Icons.notifications;
    }
  }
}

