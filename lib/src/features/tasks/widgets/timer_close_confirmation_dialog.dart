import 'package:flutter/material.dart';
import '../../../../services/task_timer_service.dart';
import '../../../../modules/tasks/module.dart';
import '../task_detail_page.dart';
import '../../../navigation/tab_item.dart';
import '../../../navigation/interfaces/tab_manager_interface.dart';
import '../../../../core/di/service_locator.dart';

/// Diálogo de confirmação ao fechar o programa com timer ativo
///
/// Exibe:
/// - Status do timer (em execução ou pausado)
/// - Nome da tarefa com link clicável
/// - Opções: Cancelar ou Fechar (com parada automática do timer)
class TimerCloseConfirmationDialog extends StatelessWidget {
  final String? taskTitle;
  final String? activeTaskId;

  const TimerCloseConfirmationDialog._internal({
    this.taskTitle,
    this.activeTaskId,
  });

  /// Mostra o diálogo e retorna true se o usuário confirmar o fechamento
  static Future<bool?> show(BuildContext context) async {
    // Buscar informações da tarefa ativa
    String? taskTitle;
    final activeTaskId = taskTimerService.activeTaskId;

    if (activeTaskId != null) {
      try {
        final task = await tasksModule.getTaskById(activeTaskId);
        taskTitle = task?['title'] as String?;
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    }

    if (!context.mounted) return null;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TimerCloseConfirmationDialog._internal(
        taskTitle: taskTitle,
        activeTaskId: activeTaskId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: _buildTitle(),
      content: _buildContent(context),
      actions: _buildActions(context),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange[400],
          size: 28,
        ),
        const SizedBox(width: 12),
        const Text(
          'Timer Ativo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Você possui um timer ${taskTimerService.isRunning ? "em execução" : "pausado"}.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        if (taskTitle != null && activeTaskId != null) ...[
          const SizedBox(height: 12),
          _buildTaskLabel(),
          const SizedBox(height: 4),
          _buildTaskCard(context),
        ],
        const SizedBox(height: 12),
        _buildWarningMessage(),
      ],
    );
  }

  Widget _buildTaskLabel() {
    return Text(
      'Tarefa:',
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop(false);
        _navigateToTask(context, activeTaskId!, taskTitle!);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task,
              color: Colors.blue[300],
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                taskTitle!,
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              color: Colors.blue[300],
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningMessage() {
    return const Text(
      'Deseja realmente fechar o programa? O timer será parado e o tempo registrado será salvo automaticamente.',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          'Cancelar',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor: Colors.orange[700]?.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          'Fechar',
          style: TextStyle(
            color: Colors.orange[400],
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }

  /// Navega para a página de detalhes da tarefa com o timer aberto
  void _navigateToTask(BuildContext context, String taskId, String taskTitle) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final tabManager = serviceLocator.get<ITabManager>();
        final tabId = 'task_$taskId';

        final updatedTab = TabItem(
          id: tabId,
          title: taskTitle,
          icon: Icons.task,
          page: TaskDetailPage(
            key: ValueKey(tabId),
            taskId: taskId,
            openTimerCard: true,
          ),
          canClose: true,
          selectedMenuIndex: 1,
        );

        tabManager.updateTab(tabManager.currentIndex, updatedTab);
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    });
  }
}

