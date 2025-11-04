import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/task_timer_service.dart';
import '../../../../services/timer_error_handler.dart';

/// Widget de cronômetro para rastreamento de tempo em tarefas
///
/// Características:
/// - Display do tempo no formato HH:MM:SS
/// - Botões Play/Pause/Stop
/// - Verificação de permissões (apenas responsáveis pela tarefa)
/// - Tema dark integrado
/// - Sincronização automática com banco
///
/// Uso:
/// ```dart
/// TaskTimerWidget(
///   taskId: task['id'],
///   assignedTo: task['assigned_to'],
///   assigneeUserIds: task['assignee_user_ids'],
/// )
/// ```
class TaskTimerWidget extends StatefulWidget {
  final String taskId;
  final String? assignedTo;
  final List<String>? assigneeUserIds;

  const TaskTimerWidget({
    super.key,
    required this.taskId,
    this.assignedTo,
    this.assigneeUserIds,
  });

  @override
  State<TaskTimerWidget> createState() => _TaskTimerWidgetState();
}

class _TaskTimerWidgetState extends State<TaskTimerWidget> {
  bool _loading = false;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Escutar mudanças no timer
    taskTimerService.addListener(_onTimerChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    taskTimerService.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canUseTimer {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    // Verificar se o usuário é um dos responsáveis pela tarefa
    // Pode ser via assigned_to (responsável principal) ou assignee_user_ids (múltiplos responsáveis)
    final isAssignedTo = widget.assignedTo == currentUser.id;
    final isInAssigneeList = widget.assigneeUserIds?.contains(currentUser.id) ?? false;

    return isAssignedTo || isInAssigneeList;
  }

  bool get _isActiveForThisTask {
    return taskTimerService.activeTaskId == widget.taskId;
  }

  Future<void> _handleStart() async {
    if (!_canUseTimer) {
      TimerErrorHandler.showWarning(
        context,
        'Apenas os responsáveis pela tarefa podem iniciar o cronômetro',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await taskTimerService.start(widget.taskId);
      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successTimerStarted);
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorStartTimer,
          details: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handlePause() async {
    setState(() => _loading = true);
    try {
      await taskTimerService.pause();
      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successTimerPaused);
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorPauseTimer,
          details: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleResume() async {
    setState(() => _loading = true);
    try {
      await taskTimerService.resume();
      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successTimerResumed);
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorResumeTimer,
          details: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleStop() async {
    setState(() => _loading = true);
    try {
      // Pegar a descrição do campo de texto
      final description = _descriptionController.text.trim();
      await taskTimerService.stop(description: description.isEmpty ? null : description);

      // Limpar o campo após salvar
      _descriptionController.clear();

      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successTimerStopped);
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorStopTimer,
          details: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canUseTimer) {
      return const SizedBox.shrink();
    }

    final isRunning = taskTimerService.isRunning && _isActiveForThisTask;
    final hasActiveTimer = _isActiveForThisTask && taskTimerService.activeTimeLogId != null;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha do timer (ícone, campo de texto, tempo, botões)
          Row(
            children: [
              // Ícone
              Icon(
                Icons.timer_outlined,
                color: Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 12),

              // Campo de descrição (inline, sempre visível e editável, à esquerda)
              Expanded(
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 1,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Descrição da atividade (opcional)',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    counterText: '', // Esconder contador de caracteres
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Display do tempo (à direita)
              Text(
                hasActiveTimer ? taskTimerService.getFormattedTime() : '00:00:00',
                style: TextStyle(
                  color: isRunning ? Colors.green.withValues(alpha: 0.9) : Colors.grey[400],
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),

              const SizedBox(width: 12),

              // Botões de controle (compactos)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasActiveTimer) ...[
                    // Botão Start (compacto)
                    _CompactTimerButton(
                      icon: Icons.play_arrow,
                      tooltip: 'Iniciar',
                      color: Colors.green.withValues(alpha: 0.7),
                      onPressed: _loading ? null : _handleStart,
                      loading: _loading,
                    ),
                  ] else ...[
                    // Botão Play/Pause (compacto)
                    _CompactTimerButton(
                      icon: isRunning ? Icons.pause : Icons.play_arrow,
                      tooltip: isRunning ? 'Pausar' : 'Retomar',
                      color: isRunning ? Colors.orange.withValues(alpha: 0.7) : Colors.green.withValues(alpha: 0.7),
                      onPressed: _loading ? null : (isRunning ? _handlePause : _handleResume),
                      loading: _loading,
                    ),
                    const SizedBox(width: 8),
                    // Botão Stop (compacto)
                    _CompactTimerButton(
                      icon: Icons.stop,
                      tooltip: 'Parar',
                      color: Colors.red.withValues(alpha: 0.7),
                      onPressed: _loading ? null : _handleStop,
                      loading: _loading,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botão compacto para controles do timer
class _CompactTimerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _CompactTimerButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Tooltip desabilitado para evitar erro de múltiplos tickers
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        iconSize: 16,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        color: Colors.grey[400],
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

