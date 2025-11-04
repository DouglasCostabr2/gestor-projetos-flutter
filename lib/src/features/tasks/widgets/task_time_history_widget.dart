import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../modules/time_tracking/module.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/task_timer_service.dart';
import '../../../../services/timer_error_handler.dart';

/// Widget para exibir histórico de tempo de uma tarefa
///
/// Características:
/// - Lista de sessões de tempo
/// - Exibição de tempo total
/// - Informações de usuário e data
/// - Opção de deletar sessões (apenas próprias)
/// - Atualização automática quando timer é parado
///
/// Uso:
/// ```dart
/// TaskTimeHistoryWidget(
///   taskId: task['id'],
/// )
/// ```
class TaskTimeHistoryWidget extends StatefulWidget {
  final String taskId;

  const TaskTimeHistoryWidget({
    super.key,
    required this.taskId,
  });

  @override
  State<TaskTimeHistoryWidget> createState() => _TaskTimeHistoryWidgetState();
}

class _TaskTimeHistoryWidgetState extends State<TaskTimeHistoryWidget> {
  late Future<List<Map<String, dynamic>>> _timeLogsFuture;
  late Future<int> _totalTimeFuture;
  String? _lastActiveTimeLogId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _lastActiveTimeLogId = taskTimerService.activeTimeLogId;
    // Escutar mudanças no timer service para atualizar quando timer for parado
    taskTimerService.addListener(_onTimerChanged);
  }

  @override
  void dispose() {
    taskTimerService.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() {
    // Só recarregar quando o timer for parado (activeTimeLogId muda de algo para null)
    final currentActiveTimeLogId = taskTimerService.activeTimeLogId;

    if (_lastActiveTimeLogId != null && currentActiveTimeLogId == null) {
      // Timer foi parado
      if (mounted) {
        _refresh();
      }
    }

    _lastActiveTimeLogId = currentActiveTimeLogId;
  }

  void _loadData() {
    _timeLogsFuture = timeTrackingModule.getTaskTimeLogs(taskId: widget.taskId);
    _totalTimeFuture = timeTrackingModule.getTotalTimeSpent(taskId: widget.taskId);
  }

  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  Future<void> _deleteTimeLog(String timeLogId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Registro'),
        content: const Text('Deseja realmente deletar este registro de tempo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await timeTrackingModule.deleteTimeLog(timeLogId: timeLogId);
      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successEntryDeleted);
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorDeleteEntry,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> _updateDescription(String timeLogId, String? newDescription) async {
    try {
      await timeTrackingModule.updateTimeLog(
        timeLogId: timeLogId,
        description: newDescription?.isEmpty ?? true ? null : newDescription,
      );

      if (mounted) {
        TimerErrorHandler.showSuccess(context, TimerErrorHandler.successDescriptionUpdated);
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        TimerErrorHandler.showError(
          context,
          TimerErrorHandler.errorUpdateDescription,
          details: e.toString(),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Histórico',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              // Tempo total
              FutureBuilder<int>(
                future: _totalTimeFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final totalSeconds = snapshot.data ?? 0;
                  if (totalSeconds == 0) return const SizedBox.shrink();

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(totalSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6), // Espaço para alinhar com os botões abaixo
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de sessões
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _timeLogsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Erro ao carregar histórico',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  ),
                );
              }

              final timeLogs = snapshot.data ?? [];

              if (timeLogs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Nenhum registro ainda',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: timeLogs.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.withValues(alpha: 0.1),
                  height: 1,
                  indent: 40,
                ),
                itemBuilder: (context, index) {
                  final log = timeLogs[index];
                  return _TimeLogItem(
                    log: log,
                    onDelete: () => _deleteTimeLog(log['id'] as String),
                    onUpdateDescription: (newDescription) => _updateDescription(
                      log['id'] as String,
                      newDescription,
                    ),
                    formatDuration: _formatDuration,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Item individual de registro de tempo
class _TimeLogItem extends StatefulWidget {
  final Map<String, dynamic> log;
  final VoidCallback onDelete;
  final Function(String?) onUpdateDescription;
  final String Function(int) formatDuration;

  const _TimeLogItem({
    required this.log,
    required this.onDelete,
    required this.onUpdateDescription,
    required this.formatDuration,
  });

  @override
  State<_TimeLogItem> createState() => _TimeLogItemState();
}

class _TimeLogItemState extends State<_TimeLogItem> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final description = widget.log['description'] as String?;
    _controller = TextEditingController(text: description ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      final description = widget.log['description'] as String?;
      _controller.text = description ?? '';
    });
  }

  void _saveEditing() {
    widget.onUpdateDescription(_controller.text.trim());
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = widget.log['user_id'] == currentUserId;
    final user = widget.log['user'] as Map<String, dynamic>?;
    final userName = user?['full_name'] ?? user?['email'] ?? 'Usuário';
    final avatarUrl = user?['avatar_url'] as String?;
    final startTime = DateTime.parse(widget.log['start_time'] as String);
    final endTime = widget.log['end_time'] != null ? DateTime.parse(widget.log['end_time'] as String) : null;
    final durationSeconds = widget.log['duration_seconds'] as int?;
    final isActive = endTime == null;
    final description = widget.log['description'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Avatar
          CircleAvatar(
            radius: 10,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    userName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  )
                : null,
          ),
          const SizedBox(width: 8),

          // Nome do usuário
          Text(
            userName,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),

          // Data e hora (compacto)
          Text(
            '${DateFormat('dd/MM').format(startTime)} ${DateFormat('HH:mm').format(startTime)}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),

          const Spacer(),

          // Duração
          if (durationSeconds != null && !isActive)
            Text(
              widget.formatDuration(durationSeconds),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

          // Botão deletar (apenas para o dono, mais discreto)
          if (isOwner && !isActive) ...[
            const SizedBox(width: 8),
            _HoverIconButton(
              icon: Icons.close,
              size: 14,
              color: Colors.grey[600]!,
              hoverColor: Colors.white,
              onTap: widget.onDelete,
            ),
          ],
            ],
          ),

          // Descrição (editável para o dono)
          if (isOwner && !isActive) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _controller,
                          autofocus: true,
                          maxLines: 1,
                          maxLength: 500,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
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
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 29,
                              width: 85,
                              child: TextButton(
                                onPressed: _cancelEditing,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 29,
                              width: 85,
                              child: TextButton(
                                onPressed: _saveEditing,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                child: Text(
                                  'Salvar',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            description != null && description.isNotEmpty
                                ? description
                                : 'Sem descrição',
                            style: TextStyle(
                              color: description != null && description.isNotEmpty
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _HoverIconButton(
                          icon: Icons.edit,
                          size: 14,
                          color: Colors.grey[600]!,
                          hoverColor: Colors.white,
                          onTap: _startEditing,
                        ),
                      ],
                    ),
            ),
          ] else if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Botão de ícone com efeito hover
class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: _isHovering ? widget.hoverColor : widget.color,
          ),
        ),
      ),
    );
  }
}

