import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/organisms/cards/cards.dart';
import 'package:my_business/ui/molecules/user_avatar_name.dart';
import 'package:my_business/ui/molecules/table_cells/table_cell_avatar_list.dart';
import '../../../navigation/tab_manager_scope.dart';
import '../../../navigation/tab_item.dart';
import '../../projects/project_detail_page.dart';
import '../../clients/client_detail_page.dart';
import 'task_priority_badge.dart';
import 'task_due_date_badge.dart';
import 'task_status_field.dart';

/// Widgets auxiliares para construir os itens dos cards de informações da task

/// Widget para exibir responsáveis com busca de perfis
class _AssigneeContent extends StatefulWidget {
  final Map<String, dynamic> task;

  const _AssigneeContent({required this.task});

  @override
  State<_AssigneeContent> createState() => _AssigneeContentState();
}

class _AssigneeContentState extends State<_AssigneeContent> {
  late Future<Map<String, Map<String, dynamic>>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _loadProfiles();
  }

  Future<Map<String, Map<String, dynamic>>> _loadProfiles() async {
    final assigneeId = widget.task['assigned_to'] as String?;
    final assigneeUserIds = (widget.task['assignee_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];

    // Coletar todos os IDs de responsáveis
    final allAssigneeIds = <String>{
      if (assigneeId != null) assigneeId,
      ...assigneeUserIds,
    };

    if (allAssigneeIds.isEmpty) {
      return {};
    }

    try {
      // Buscar perfis de todos os responsáveis
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .inFilter('id', allAssigneeIds.toList());

      // Converter para mapa para acesso rápido
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profiles) {
        profilesMap[profile['id'] as String] = profile;
      }

      return profilesMap;
    } catch (e) {
      debugPrint('❌ Erro ao buscar perfis dos responsáveis: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigneeId = widget.task['assigned_to'] as String?;
    final assigneeUserIds = (widget.task['assignee_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];

    // Se não há responsáveis
    if (assigneeId == null && assigneeUserIds.isEmpty) {
      return Text(
        'Não atribuído',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Coletar todos os responsáveis
    final allAssigneeIds = <String>{
      if (assigneeId != null) assigneeId,
      ...assigneeUserIds,
    };

    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _profilesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final profilesMap = snapshot.data ?? {};

        // Converter para formato esperado pelo ResponsibleCell
        final peopleList = allAssigneeIds.map((userId) {
          final profile = profilesMap[userId];
          return {
            'id': userId,
            'full_name': profile?['full_name'] ?? profile?['email'] ?? 'Usuário',
            'email': profile?['email'],
            'avatar_url': profile?['avatar_url'],
          };
        }).toList();

        // Se há apenas um responsável - mostra avatar + nome
        if (peopleList.length == 1) {
          final person = peopleList[0];
          return UserAvatarName(
            avatarUrl: person['avatar_url'] as String?,
            name: person['full_name'] as String,
            size: 20,
          );
        }

        // Se há múltiplos responsáveis - mostra apenas avatares lado a lado
        return TableCellAvatarList(
          people: peopleList,
          maxVisible: 5,
          avatarSize: 14,
          spacing: 6,
        );
      },
    );
  }
}

class TaskInfoCardItems {
  TaskInfoCardItems._(); // Private constructor - utility class

  /// Cria o item "Nome da Tarefa"
  static InfoCardItem buildTaskNameItem(BuildContext context, Map<String, dynamic> task) {
    return InfoCardItem(
      label: 'Nome da Tarefa',
      labelContentSpacing: 22,
      content: Text(
        task['title'] ?? 'Sem título',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Cria o item "Responsável"
  static InfoCardItem buildAssigneeItem(BuildContext context, Map<String, dynamic> task) {
    return InfoCardItem(
      label: 'Responsável',
      content: _AssigneeContent(task: task),
    );
  }

  /// Cria o item "Projeto" (clicável)
  static InfoCardItem buildProjectItem(
    BuildContext context,
    String? projectId,
    String projectName,
  ) {
    return InfoCardItem(
      label: 'Projeto',
      labelContentSpacing: 22,
      content: projectId != null
          ? GestureDetector(
              onTap: () => _navigateToProject(context, projectId, projectName),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  projectName,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          : Text(
              projectName,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  /// Cria o item "Cliente" (clicável com avatar)
  ///
  /// [canNavigate] - Se true, permite clicar para navegar à página do cliente
  static InfoCardItem buildClientItem(
    BuildContext context,
    String? clientId,
    String clientName,
    String? clientAvatarUrl, {
    bool canNavigate = true,
  }) {
    // Widget de conteúdo (avatar + nome)
    final contentWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (clientAvatarUrl != null && clientAvatarUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(clientAvatarUrl),
            ),
          ),
        Flexible(
          child: Text(
            clientName,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return InfoCardItem(
      label: 'Cliente',
      labelContentSpacing: 18,
      content: clientId != null && canNavigate
          ? GestureDetector(
              onTap: () => _navigateToClient(context, clientId, clientName),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: contentWidget,
              ),
            )
          : contentWidget,
    );
  }

  /// Cria o item "Prioridade"
  static InfoCardItem buildPriorityItem(Map<String, dynamic> task) {
    return InfoCardItem(
      label: 'Prioridade',
      widthCalculator: (itemsPerRow, adjustedItemWidth) => itemsPerRow >= 4 ? null : adjustedItemWidth,
      content: TaskPriorityBadge(priority: task['priority'] ?? 'medium'),
    );
  }

  /// Cria o item "Vencimento"
  static InfoCardItem buildDueDateItem(BuildContext context, Map<String, dynamic> task) {
    return InfoCardItem(
      label: 'Vencimento',
      widthCalculator: (itemsPerRow, adjustedItemWidth) => itemsPerRow >= 4 ? null : adjustedItemWidth,
      content: Builder(
        builder: (context) {
          final dueDate = task['due_date'] as String?;
          if (dueDate == null) {
            return Text(
              'Sem data',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          }

          final date = DateTime.parse(dueDate);
          final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              TaskDueDateBadge(
                dueDate: dueDate,
                status: task['status'] ?? 'todo',
              ),
            ],
          );
        },
      ),
    );
  }

  /// Cria o item "Status"
  static InfoCardItem buildStatusItem(
    BuildContext context,
    Map<String, dynamic> task,
    String taskId,
    Function(String) onStatusChanged,
  ) {
    return InfoCardItem(
      label: 'Status',
      labelContentSpacing: 8,
      useExpanded: true,
      widthCalculator: (itemsPerRow, adjustedItemWidth) => adjustedItemWidth,
      content: TaskStatusField(
        status: task['status'] ?? 'todo',
        taskId: taskId,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  /// Cria o item "Timer"
  static InfoCardItem buildTimerItem({VoidCallback? onTap}) {
    return InfoCardItem(
      label: 'Timer',
      labelContentSpacing: 12,
      widthCalculator: (itemsPerRow, adjustedItemWidth) => itemsPerRow >= 4 ? null : adjustedItemWidth,
      minWidthCalculator: (itemsPerRow) => itemsPerRow >= 4 ? 0 : 120,
      rightPaddingCalculator: (itemsPerRow) => itemsPerRow >= 4 ? 0 : 20,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      content: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.timer_outlined,
              size: 20,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // MÉTODOS AUXILIARES DE NAVEGAÇÃO
  // ============================================================================

  static void _navigateToProject(BuildContext context, String projectId, String projectName) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager != null) {
      final currentIndex = tabManager.currentIndex;
      final updatedTab = TabItem(
        id: 'project_$projectId',
        title: projectName,
        icon: Icons.folder,
        page: ProjectDetailPage(projectId: projectId),
        canClose: true,
        selectedMenuIndex: 2,
      );
      tabManager.updateTab(currentIndex, updatedTab);
    }
  }

  static void _navigateToClient(BuildContext context, String clientId, String clientName) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager != null) {
      final currentIndex = tabManager.currentIndex;
      final updatedTab = TabItem(
        id: 'client_$clientId',
        title: clientName,
        icon: Icons.person,
        page: ClientDetailPage(clientId: clientId),
        canClose: true,
        selectedMenuIndex: 1,
      );
      tabManager.updateTab(currentIndex, updatedTab);
    }
  }
}

