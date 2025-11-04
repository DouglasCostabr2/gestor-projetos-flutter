import 'package:flutter/material.dart';
import 'package:my_business/modules/modules.dart';
import '../../../../ui/molecules/user_avatar_name.dart';
import '../../../../ui/molecules/table_cells/table_cells.dart';
import '../../tasks/widgets/task_status_badge.dart';
import '../../tasks/widgets/task_priority_badge.dart';

/// Helpers para construir células de tabelas de tarefas
///
/// Centraliza a lógica de renderização de células para reutilização
/// em diferentes tabelas (Tasks, SubTasks, TasksPage, etc.)
///
/// Pode ser usado em qualquer página que exibe tarefas em tabelas
class TaskTableHelpers {
  TaskTableHelpers._(); // Private constructor - utility class

  /// Constrói a célula de título da tarefa
  /// Mostra ícone de ampulheta se a tarefa está aguardando
  static Widget buildTitleCell(Map<String, dynamic> task) {
    final title = task['title'] ?? 'Sem título';
    final status = task['status'] as String?;

    // Se está aguardando, mostrar ícone
    if (tasksModule.isWaitingStatus(status)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 16,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(title)),
        ],
      );
    }

    return Text(title);
  }

  /// Constrói a célula de status da tarefa
  static Widget buildStatusCell(Map<String, dynamic> task) {
    final status = task['status'] ?? 'todo';
    return TaskStatusBadge(status: status);
  }

  /// Constrói a célula de prioridade da tarefa
  static Widget buildPriorityCell(Map<String, dynamic> task) {
    final priority = task['priority'] ?? 'medium';
    return TaskPriorityBadge(priority: priority);
  }

  /// Constrói a célula de data de vencimento
  static Widget buildDueDateCell(Map<String, dynamic> task) {
    return TableCellDueDate(
      dueDate: task['due_date'],
      status: task['status'],
    );
  }

  /// Constrói a célula de responsável (assignee) para tarefas principais
  static Widget buildAssigneeCell(Map<String, dynamic> task) {
    final assignee = task['assignee_profile'] as Map<String, dynamic>?;
    if (assignee == null) return const Text('-');

    final assigneeName = assignee['full_name'] ?? assignee['email'] ?? '-';
    final avatarUrl = assignee['avatar_url'] as String?;

    return UserAvatarName(
      avatarUrl: avatarUrl,
      name: assigneeName as String,
      size: 20,
    );
  }

  /// Constrói a célula de responsáveis (assignees) para subtarefas
  /// Mostra lista de avatares quando há múltiplos responsáveis
  static Widget buildAssigneesListCell(Map<String, dynamic> task) {
    return TableCellAvatarList(
      people: task['assignees_list'] ?? [],
      maxVisible: 3,
      avatarSize: 12,
    );
  }

  /// Constrói a célula de responsável com lógica condicional
  /// - 1 responsável: Mostra avatar + nome (UserAvatarName)
  /// - Múltiplos responsáveis: Mostra apenas avatares (TableCellAvatarList)
  /// - Nenhum responsável: Mostra "-"
  ///
  /// Este é o método recomendado para usar em todas as tabelas de tarefas
  ///
  /// REFATORADO: Agora usa o widget ResponsibleCell para centralizar a lógica
  static Widget buildResponsibleCell(Map<String, dynamic> task) {
    return ResponsibleCell(
      people: task['assignees_list'] as List<dynamic>?,
    );
  }

  /// Constrói a célula de data de criação
  static Widget buildCreatedAtCell(Map<String, dynamic> task) {
    final createdAt = task['created_at'];
    if (createdAt == null) return const Text('-');
    
    try {
      final date = DateTime.parse(createdAt);
      return Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');
    } catch (e) {
      return const Text('-');
    }
  }

  /// Constrói a célula de última atualização
  /// Mostra data + avatar e nome do usuário que atualizou
  static Widget buildUpdatedAtCell(Map<String, dynamic> task) {
    final updatedAt = task['updated_at'];
    final updatedByProfile = task['updated_by_profile'] as Map<String, dynamic>?;

    if (updatedAt == null) return const Text('-');

    try {
      final date = DateTime.parse(updatedAt);
      final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

      // Se não tem informação do usuário, mostra só a data
      if (updatedByProfile == null) {
        return Text(dateStr);
      }

      final userName = updatedByProfile['full_name'] as String? ?? updatedByProfile['email'] as String? ?? 'Usuário';
      final avatarUrl = updatedByProfile['avatar_url'] as String?;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          UserAvatarName(
            avatarUrl: avatarUrl,
            name: userName,
            size: 16,
          ),
        ],
      );
    } catch (e) {
      return const Text('-');
    }
  }

  /// Retorna a lista completa de cell builders para a tabela de tarefas principais
  static List<Widget Function(Map<String, dynamic>)> getTaskCellBuilders() {
    return [
      buildTitleCell,
      buildStatusCell,
      buildPriorityCell,
      buildDueDateCell,
      buildResponsibleCell,  // Usa lógica condicional: 1 responsável = avatar+nome, múltiplos = avatares
      buildCreatedAtCell,
      buildUpdatedAtCell,
    ];
  }

  /// Retorna a lista completa de cell builders para a tabela de subtarefas
  /// Mesma estrutura da tabela de tarefas, sem a coluna de tarefa principal
  static List<Widget Function(Map<String, dynamic>)> getSubTaskCellBuilders(List<Map<String, dynamic>> allTasks) {
    return [
      buildTitleCell,
      buildStatusCell,
      buildPriorityCell,
      buildDueDateCell,
      buildResponsibleCell,  // Usa lógica condicional: 1 responsável = avatar+nome, múltiplos = avatares
      buildCreatedAtCell,
      buildUpdatedAtCell,
    ];
  }

  /// Constrói a célula de tarefa principal (para subtarefas)
  /// Busca a tarefa pai na lista de todas as tarefas
  static Widget buildParentTaskCellWithContext(Map<String, dynamic> task, List<Map<String, dynamic>> allTasks) {
    final parentTaskId = task['parent_task_id'];
    if (parentTaskId == null) return const Text('-');

    // Buscar o título da tarefa principal na lista de todas as tarefas
    final parentTask = allTasks.firstWhere(
      (t) => t['id'] == parentTaskId,
      orElse: () => {'title': 'Tarefa não encontrada'},
    );

    final parentTitle = parentTask['title'] ?? '-';
    return Text(
      parentTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Constrói a célula de projeto
  /// Mostra o nome do projeto associado à tarefa
  static Widget buildProjectCell(Map<String, dynamic> task) {
    final projectName = task['projects']?['name'] ?? '-';
    return Text(
      projectName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Retorna a lista completa de cell builders para a página de tarefas (TasksPage)
  /// Inclui uma célula adicional para mostrar o projeto
  static List<Widget Function(Map<String, dynamic>)> getTasksPageCellBuilders() {
    return [
      buildTitleCell,
      buildProjectCell,  // Célula adicional para TasksPage
      buildStatusCell,
      buildPriorityCell,
      buildDueDateCell,
      buildResponsibleCell,  // Usa lógica condicional: 1 responsável = avatar+nome, múltiplos = avatares
      buildCreatedAtCell,
      buildUpdatedAtCell,
    ];
  }
}

