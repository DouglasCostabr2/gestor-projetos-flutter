import 'package:flutter/material.dart';
import '../../../modules/notifications/module.dart';
import '../../../modules/notifications/models.dart' as models;
import '../../../modules/organizations/module.dart';
import '../../navigation/tab_item.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../state/app_state_scope.dart';
import '../tasks/task_detail_page.dart';
import '../projects/project_detail_page.dart';
import '../clients/clients_page.dart';
import 'widgets/notification_item.dart';
import '../organization/organization_management_page.dart';

/// Página de notificações do usuário
///
/// IMPORTANTE: Esta página agora depende do NotificationRealtimeService global
/// para receber atualizações em tempo real. Ela escuta eventos locais via
/// NotificationEventBus e recarrega a lista quando necessário.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<models.Notification> _allNotifications = [];
  List<models.Notification> _unreadNotifications = [];
  bool _loading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
    _subscribeToLocalEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    notificationEventBus.events.removeListener(_handleLocalEvent);
    super.dispose();
  }

  void _subscribeToLocalEvents() {
    notificationEventBus.events.addListener(_handleLocalEvent);
  }

  void _handleLocalEvent() {
    final event = notificationEventBus.events.value;
    if (event == null || !mounted) return;

    // Recarregar lista quando houver mudanças
    switch (event.type) {
      case NotificationEventType.created:
      case NotificationEventType.deleted:
        _loadNotifications();
        break;
      case NotificationEventType.markedAsRead:
      case NotificationEventType.markedAllAsRead:
        // Para estes eventos, apenas atualizar o estado local sem recarregar
        break;
    }
  }

  Future<void> _loadNotifications() async {
    debugPrint('🔔 [NOTIFICATIONS PAGE] Carregando notificações...');
    setState(() => _loading = true);
    try {
      final all = await notificationsModule.getNotifications(limit: 100);
      debugPrint('🔔 [NOTIFICATIONS PAGE] Total carregadas: ${all.length}');
      final unread = await notificationsModule.getUnreadNotifications();
      debugPrint('🔔 [NOTIFICATIONS PAGE] Não lidas: ${unread.length}');
      final count = await notificationsModule.getUnreadCount();
      debugPrint('🔔 [NOTIFICATIONS PAGE] Contagem não lidas: $count');

      if (mounted) {
        setState(() {
          _allNotifications = all;
          _unreadNotifications = unread;
          _unreadCount = count;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar notificações: $e')),
        );
      }
    }
  }



  Future<void> _markAsRead(String notificationId) async {
    // Atualização otimista - atualizar UI imediatamente
    if (mounted) {
      setState(() {
        final allIndex = _allNotifications.indexWhere((n) => n.id == notificationId);
        if (allIndex != -1) {
          _allNotifications[allIndex] = _allNotifications[allIndex].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }

        final unreadIndex = _unreadNotifications.indexWhere((n) => n.id == notificationId);
        if (unreadIndex != -1) {
          _unreadNotifications.removeAt(unreadIndex);
          _unreadCount--;
        }
      });

      // Emitir evento local para atualização instantânea do badge
      notificationEventBus.emitMarkedAsRead(notificationId);
    }

    try {
      await notificationsModule.markAsRead(notificationId);
    } catch (e) {
      // Reverter atualização otimista em caso de erro
      if (mounted) {
        setState(() {
          final allIndex = _allNotifications.indexWhere((n) => n.id == notificationId);
          if (allIndex != -1) {
            _allNotifications[allIndex] = _allNotifications[allIndex].copyWith(
              isRead: false,
              readAt: null,
            );
          }
          _loadNotifications(); // Recarregar do servidor
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como lida: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Atualização otimista
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _allNotifications = _allNotifications.map((n) {
          if (!n.isRead) {
            return n.copyWith(isRead: true, readAt: now);
          }
          return n;
        }).toList();
        _unreadNotifications.clear();
        _unreadCount = 0;
      });

      // Emitir evento local para atualização instantânea do badge
      notificationEventBus.emitMarkedAllAsRead();
    }

    try {
      await notificationsModule.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas as notificações marcadas como lidas')),
        );
      }
    } catch (e) {
      // Reverter em caso de erro
      if (mounted) {
        _loadNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar todas como lidas: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvite(models.Notification notification) async {
    final inviteId = notification.metadata['invite_id'];

    if (inviteId == null) {
      debugPrint('❌ Invite ID não encontrado nos metadados da notificação');
      return;
    }

    // Converter para String se necessário
    final inviteIdStr = inviteId.toString();

    // Capturar AppState antes do async gap
    final appState = AppStateScope.of(context);

    try {
      debugPrint('✅ Aceitando convite $inviteIdStr...');
      await organizationsModule.acceptInvite(inviteIdStr);

      // Marcar notificação como lida
      await notificationsModule.markAsRead(notification.id);

      // Recarregar lista de organizações no AppState
      debugPrint('🔄 Atualizando lista de organizações...');
      await appState.refreshOrganizations();

      // Recarregar notificações
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite aceito com sucesso! Você agora faz parte da organização.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao aceitar convite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aceitar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectInvite(models.Notification notification) async {
    final inviteId = notification.metadata['invite_id'];

    if (inviteId == null) {
      debugPrint('❌ Invite ID não encontrado nos metadados da notificação');
      return;
    }

    // Converter para String se necessário
    final inviteIdStr = inviteId.toString();

    try {
      debugPrint('❌ Rejeitando convite $inviteIdStr...');
      await organizationsModule.rejectInvite(inviteIdStr);

      // Marcar notificação como lida e deletar
      await notificationsModule.markAsRead(notification.id);
      await notificationsModule.deleteNotification(notification.id);

      // Recarregar notificações
      await _loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite recusado.'),
            backgroundColor: Color(0xFF6B7280),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao recusar convite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recusar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    // Atualização otimista
    models.Notification? deletedNotification;
    if (mounted) {
      setState(() {
        final allIndex = _allNotifications.indexWhere((n) => n.id == notificationId);
        if (allIndex != -1) {
          deletedNotification = _allNotifications[allIndex];
          _allNotifications.removeAt(allIndex);
        }

        final unreadIndex = _unreadNotifications.indexWhere((n) => n.id == notificationId);
        if (unreadIndex != -1) {
          _unreadNotifications.removeAt(unreadIndex);
          _unreadCount--;
        }
      });
    }

    try {
      await notificationsModule.deleteNotification(notificationId);
    } catch (e) {
      // Reverter em caso de erro
      if (mounted && deletedNotification != null) {
        setState(() {
          _allNotifications.insert(0, deletedNotification!);
          if (!deletedNotification!.isRead) {
            _unreadNotifications.insert(0, deletedNotification!);
            _unreadCount++;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar notificação: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllRead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente deletar todas as notificações lidas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await notificationsModule.deleteAllRead();
        // A atualização será feita via realtime
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notificações lidas deletadas')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao deletar notificações: $e')),
          );
        }
      }
    }
  }

  void _handleNotificationTap(models.Notification notification) {
    // Marcar como lida se não estiver
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Navegar para a entidade relacionada (se houver)
    if (notification.entityType != null && notification.entityId != null) {
      final tabManager = TabManagerScope.maybeOf(context);
      if (tabManager == null) return;

      final currentIndex = tabManager.currentIndex;

      switch (notification.entityType!) {
        case models.NotificationEntityType.task:
          // Navegar para detalhes da tarefa na aba atual
          final taskTab = TabItem(
            id: 'task_${notification.entityId}',
            title: notification.title,
            icon: Icons.task,
            page: TaskDetailPage(taskId: notification.entityId!),
            canClose: true,
            selectedMenuIndex: 4, // Índice do menu de Tarefas
          );
          tabManager.updateTab(currentIndex, taskTab);
          break;

        case models.NotificationEntityType.project:
          // Navegar para detalhes do projeto na aba atual
          final projectTab = TabItem(
            id: 'project_${notification.entityId}',
            title: notification.title,
            icon: Icons.folder,
            page: ProjectDetailPage(projectId: notification.entityId!),
            canClose: true,
            selectedMenuIndex: 2, // Índice do menu de Projetos
          );
          tabManager.updateTab(currentIndex, projectTab);
          break;

        case models.NotificationEntityType.comment:
        case models.NotificationEntityType.mention:
          // Comentários e menções estão vinculados a tarefas, então navegar para a tarefa na aba atual
          if (notification.metadata['task_id'] != null) {
            final taskId = notification.metadata['task_id'] as String;
            final taskTab = TabItem(
              id: 'task_$taskId',
              title: notification.title,
              icon: Icons.task,
              page: TaskDetailPage(taskId: taskId),
              canClose: true,
              selectedMenuIndex: 4,
            );
            tabManager.updateTab(currentIndex, taskTab);
          }
          break;

        case models.NotificationEntityType.payment:
          // Navegação para pagamentos será implementada quando houver página de detalhes
          debugPrint('Notificação de pagamento: ${notification.title}');
          break;

        case models.NotificationEntityType.client:
          // Navegar para a página de clientes na aba atual
          final clientsTab = TabItem(
            id: 'clients',
            title: 'Clientes',
            icon: Icons.people,
            page: const ClientsPage(),
            canClose: true,
            selectedMenuIndex: 1, // Índice do menu de Clientes
          );
          tabManager.updateTab(currentIndex, clientsTab);
          break;

        case models.NotificationEntityType.company:
          // Navegar para a página de clientes (empresas estão dentro de clientes) na aba atual
          final clientsTab = TabItem(
            id: 'clients',
            title: 'Clientes',
            icon: Icons.people,
            page: const ClientsPage(),
            canClose: true,
            selectedMenuIndex: 1, // Índice do menu de Clientes
          );
          tabManager.updateTab(currentIndex, clientsTab);
          break;

        case models.NotificationEntityType.organization:
          // Abrir Gerenciar Organização -> aba Convites
          final orgTab = TabItem(
            id: 'organization_management',
            title: 'Gerenciar Organização',
            icon: Icons.business,
            page: const OrganizationManagementPage(initialTabIndex: 1),
            canClose: true,
            selectedMenuIndex: 11,
          );
          tabManager.updateTab(currentIndex, orgTab);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF2A2A2A),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Notificações',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEAEAEA),
                  ),
                ),
                const Spacer(),
                // Botão de marcar todas como lidas
                if (_unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Marcar todas como lidas'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7AB6FF),
                    ),
                  ),
                const SizedBox(width: 8),
                // Botão de deletar lidas
                IconButton(
                  onPressed: _deleteAllRead,
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Deletar notificações lidas',
                  color: const Color(0xFF9AA0A6),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não lidas'),
                    if (_unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Todas'),
                    if (_allNotifications.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_allNotifications.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNotificationsList(_unreadNotifications),
                      _buildNotificationsList(_allNotifications),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<models.Notification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma notificação',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final isInvite = notification.type == models.NotificationType.organizationInviteReceived;

          return NotificationItem(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
            onMarkAsRead: !notification.isRead
                ? () => _markAsRead(notification.id)
                : null,
            onDelete: () => _deleteNotification(notification.id),
            onAcceptInvite: isInvite ? () => _acceptInvite(notification) : null,
            onRejectInvite: isInvite ? () => _rejectInvite(notification) : null,
          );
        },
      ),
    );
  }
}

