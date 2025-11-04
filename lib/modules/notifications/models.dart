// Modelos de dados do módulo de notificações

/// Tipos de notificação disponíveis no sistema
enum NotificationType {
  taskAssigned('task_assigned', 'Tarefa Atribuída'),
  taskDueSoon('task_due_soon', 'Tarefa Vence em Breve'),
  taskOverdue('task_overdue', 'Tarefa Vencida'),
  taskUpdated('task_updated', 'Tarefa Atualizada'),
  taskComment('task_comment', 'Novo Comentário'),
  taskStatusChanged('task_status_changed', 'Status Alterado'),
  taskCreated('task_created', 'Nova Tarefa'),
  projectAdded('project_added', 'Adicionado a Projeto'),
  projectUpdated('project_updated', 'Projeto Atualizado'),
  mention('mention', 'Menção'),
  paymentReceived('payment_received', 'Pagamento Recebido'),
  clientCreated('client_created', 'Novo Cliente'),
  companyCreated('company_created', 'Nova Empresa'),
  organizationInviteReceived('organization_invite_received', 'Convite de Organização'),
  organizationRoleChanged('organization_role_changed', 'Role Alterado'),
  organizationMemberAdded('organization_member_added', 'Novo Membro');

  final String value;
  final String label;

  const NotificationType(this.value, this.label);

  /// Converte string para NotificationType
  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.taskUpdated,
    );
  }

  /// Retorna ícone apropriado para o tipo de notificação
  String get iconName {
    switch (this) {
      case NotificationType.taskAssigned:
        return 'assignment_ind';
      case NotificationType.taskDueSoon:
        return 'schedule';
      case NotificationType.taskOverdue:
        return 'warning';
      case NotificationType.taskUpdated:
        return 'update';
      case NotificationType.taskComment:
        return 'comment';
      case NotificationType.taskStatusChanged:
        return 'swap_horiz';
      case NotificationType.taskCreated:
        return 'add_task';
      case NotificationType.projectAdded:
        return 'folder_shared';
      case NotificationType.projectUpdated:
        return 'folder';
      case NotificationType.mention:
        return 'alternate_email';
      case NotificationType.paymentReceived:
        return 'payments';
      case NotificationType.clientCreated:
        return 'person_add';
      case NotificationType.companyCreated:
        return 'business';
      case NotificationType.organizationInviteReceived:
        return 'mail';
      case NotificationType.organizationRoleChanged:
        return 'admin_panel_settings';
      case NotificationType.organizationMemberAdded:
        return 'group_add';
    }
  }

  /// Retorna cor apropriada para o tipo de notificação
  int get colorValue {
    switch (this) {
      case NotificationType.taskAssigned:
        return 0xFF7AB6FF; // Azul
      case NotificationType.taskDueSoon:
        return 0xFFFFA726; // Laranja
      case NotificationType.taskOverdue:
        return 0xFFFF4D4D; // Vermelho
      case NotificationType.taskUpdated:
        return 0xFF7AB6FF; // Azul
      case NotificationType.taskComment:
        return 0xFF9C27B0; // Roxo
      case NotificationType.taskStatusChanged:
        return 0xFF7AB6FF; // Azul
      case NotificationType.taskCreated:
        return 0xFF4CAF50; // Verde
      case NotificationType.projectAdded:
        return 0xFF4CAF50; // Verde
      case NotificationType.projectUpdated:
        return 0xFF7AB6FF; // Azul
      case NotificationType.mention:
        return 0xFFFFD700; // Dourado
      case NotificationType.paymentReceived:
        return 0xFF4CAF50; // Verde
      case NotificationType.clientCreated:
        return 0xFF4CAF50; // Verde
      case NotificationType.companyCreated:
        return 0xFF4CAF50; // Verde
      case NotificationType.organizationInviteReceived:
        return 0xFF7AB6FF; // Azul
      case NotificationType.organizationRoleChanged:
        return 0xFFFFA726; // Laranja
      case NotificationType.organizationMemberAdded:
        return 0xFF4CAF50; // Verde
    }
  }
}

/// Tipos de entidade que podem estar relacionadas a uma notificação
enum NotificationEntityType {
  task('task'),
  project('project'),
  comment('comment'),
  payment('payment'),
  mention('mention'),
  client('client'),
  company('company'),
  organization('organization');

  final String value;

  const NotificationEntityType(this.value);

  static NotificationEntityType? fromString(String? value) {
    if (value == null) return null;
    return NotificationEntityType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationEntityType.task,
    );
  }
}

/// Modelo de uma notificação
class Notification {
  final String id;
  final String userId;
  final String organizationId;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationEntityType? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  const Notification({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.type,
    required this.title,
    required this.message,
    this.entityType,
    this.entityId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata = const {},
  });

  /// Cria uma notificação a partir de um JSON do Supabase
  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      organizationId: json['organization_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      entityType: NotificationEntityType.fromString(json['entity_type'] as String?),
      entityId: json['entity_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converte a notificação para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'organization_id': organizationId,
      'type': type.value,
      'title': title,
      'message': message,
      'entity_type': entityType?.value,
      'entity_id': entityId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Cria uma cópia da notificação com campos atualizados
  Notification copyWith({
    String? id,
    String? userId,
    String? organizationId,
    NotificationType? type,
    String? title,
    String? message,
    NotificationEntityType? entityType,
    String? entityId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      organizationId: organizationId ?? this.organizationId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Retorna uma descrição amigável do tempo decorrido
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'} atrás';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hora' : 'horas'} atrás';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'dia' : 'dias'} atrás';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'semana' : 'semanas'} atrás';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'mês' : 'meses'} atrás';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'ano' : 'anos'} atrás';
    }
  }

  @override
  String toString() {
    return 'Notification(id: $id, type: ${type.value}, title: $title, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Estatísticas de notificações
class NotificationStats {
  final int total;
  final int unread;
  final Map<NotificationType, int> byType;

  const NotificationStats({
    required this.total,
    required this.unread,
    required this.byType,
  });

  factory NotificationStats.empty() {
    return const NotificationStats(
      total: 0,
      unread: 0,
      byType: {},
    );
  }

  factory NotificationStats.fromNotifications(List<Notification> notifications) {
    final byType = <NotificationType, int>{};
    
    for (final notification in notifications) {
      byType[notification.type] = (byType[notification.type] ?? 0) + 1;
    }

    return NotificationStats(
      total: notifications.length,
      unread: notifications.where((n) => !n.isRead).length,
      byType: byType,
    );
  }

  @override
  String toString() {
    return 'NotificationStats(total: $total, unread: $unread)';
  }
}

