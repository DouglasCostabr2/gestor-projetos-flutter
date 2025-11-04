import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import '../../../../services/google_drive_oauth_service.dart';
import '../../shared/quick_forms.dart';
import '../../../state/app_state.dart';

/// Helpers para criar actions de tabelas de tarefas
///
/// Centraliza a lógica de ações (editar, duplicar, excluir) para reutilização
/// em diferentes tabelas (Tasks, SubTasks, TasksPage, etc.)
///
/// Pode ser usado em qualquer página que exibe tarefas em tabelas
class TaskTableActions {
  TaskTableActions._(); // Private constructor - utility class

  /// Cria a action de editar tarefa
  static DataTableAction<Map<String, dynamic>> createEditAction({
    required BuildContext context,
    required String projectId,
    required AppState appState,
    required VoidCallback onTaskChanged,
  }) {
    return DataTableAction<Map<String, dynamic>>(
      icon: Icons.edit,
      label: 'Editar',
      onPressed: (task) async {
        final changed = await DialogHelper.show<bool>(
          context: context,
          builder: (context) => QuickTaskForm(projectId: projectId, initial: task),
        );
        if (changed == true) onTaskChanged();
      },
      showWhen: (task) {
        final currentId = Supabase.instance.client.auth.currentUser?.id;
        final taskCreatorId = task['created_by'] as String?;
        return appState.permissions.canEditTask(taskCreatorId, currentId);
      },
    );
  }

  /// Cria a action de duplicar tarefa
  static DataTableAction<Map<String, dynamic>> createDuplicateAction({
    required BuildContext context,
    required String projectId,
    required AppState appState,
    required VoidCallback onTaskChanged,
  }) {
    return DataTableAction<Map<String, dynamic>>(
      icon: Icons.content_copy,
      label: 'Duplicar',
      onPressed: (task) async {
        try {
          final formData = Map<String, dynamic>.from(task);
          formData.remove('id');
          formData.remove('created_at');
          formData.remove('updated_at');
          // Remover campos de relacionamento que vêm dos joins
          formData.remove('assignee_profile');
          formData.remove('assigned_to_profile');
          formData.remove('created_by_profile');
          formData.remove('updated_by_profile');
          formData.remove('creator_profile');
          formData.remove('projects');
          formData.remove('parent_task'); // Para subtarefas

          if (formData['title'] != null) {
            formData['title'] = '${formData['title']} (Cópia)';
          }

          // Garantir que project_id está presente
          formData['project_id'] = projectId;

          await Supabase.instance.client.from('tasks').insert(formData);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task duplicada com sucesso')),
            );
            onTaskChanged();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao duplicar: $e')),
            );
          }
        }
      },
      showWhen: (task) {
        final currentId = Supabase.instance.client.auth.currentUser?.id;
        final taskCreatorId = task['created_by'] as String?;
        return appState.permissions.canEditTask(taskCreatorId, currentId);
      },
    );
  }

  /// Cria a action de excluir tarefa
  static DataTableAction<Map<String, dynamic>> createDeleteAction({
    required BuildContext context,
    required AppState appState,
    required VoidCallback onTaskChanged,
  }) {
    return DataTableAction<Map<String, dynamic>>(
      icon: Icons.delete,
      label: 'Excluir',
      onPressed: (task) async {
        final ok = await DialogHelper.show<bool>(
          context: context,
          builder: (_) => const ConfirmDialog(
            title: 'Excluir Tarefa',
            message: 'Tem certeza que deseja excluir esta tarefa?',
            confirmText: 'Excluir',
            isDestructive: true,
          ),
        );

        if (ok == true) {
          // Deletar do banco de dados
          await Supabase.instance.client
              .from('tasks')
              .delete()
              .eq('id', task['id']);

          // Deletar pasta do Google Drive (best-effort)
          try {
            final clientName = (task['projects']?['clients']?['name'] ?? 'Cliente').toString();
            final projectName = (task['projects']?['name'] ?? 'Projeto').toString();
            final taskTitle = (task['title'] ?? 'Tarefa').toString();
            final drive = GoogleDriveOAuthService();
            auth.AuthClient? authed;
            try { authed = await drive.getAuthedClient(); } catch (_) {}
            if (authed != null) {
              await drive.deleteTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: taskTitle,
              );
            }
          } catch (e) {
            // Ignora erros do Google Drive (best-effort)
          }

          if (context.mounted) {
            onTaskChanged();
          }
        }
      },
      showWhen: (task) {
        final currentId = Supabase.instance.client.auth.currentUser?.id;
        final taskCreatorId = task['created_by'] as String?;
        return appState.permissions.canDeleteTask(taskCreatorId, currentId);
      },
    );
  }

  /// Retorna a lista completa de actions para a tabela de tarefas
  static List<DataTableAction<Map<String, dynamic>>> getTaskActions({
    required BuildContext context,
    required String projectId,
    required AppState appState,
    required VoidCallback onTaskChanged,
  }) {
    return [
      createEditAction(
        context: context,
        projectId: projectId,
        appState: appState,
        onTaskChanged: onTaskChanged,
      ),
      createDuplicateAction(
        context: context,
        projectId: projectId,
        appState: appState,
        onTaskChanged: onTaskChanged,
      ),
      createDeleteAction(
        context: context,
        appState: appState,
        onTaskChanged: onTaskChanged,
      ),
    ];
  }
}

