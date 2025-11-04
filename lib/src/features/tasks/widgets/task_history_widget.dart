import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskHistoryWidget extends StatefulWidget {
  final String taskId;

  const TaskHistoryWidget({super.key, required this.taskId});

  @override
  State<TaskHistoryWidget> createState() => _TaskHistoryWidgetState();
}

class _TaskHistoryWidgetState extends State<TaskHistoryWidget> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;
  final Map<String, String> _userNamesCache = {}; // Cache de IDs de usuário -> nomes

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try to load with profiles join first
      List<Map<String, dynamic>> history;
      try {
        final response = await Supabase.instance.client
            .from('task_history')
            .select('''
              *,
              user_profile:profiles!task_history_user_id_fkey (
                full_name,
                email
              )
            ''')
            .eq('task_id', widget.taskId)
            .order('created_at', ascending: false);
        history = List<Map<String, dynamic>>.from(response);
      } catch (e) {
        // Fallback: load without join and enrich manually
        debugPrint('task_history: Could not join profiles, using fallback: $e');
        final response = await Supabase.instance.client
            .from('task_history')
            .select('*')
            .eq('task_id', widget.taskId)
            .order('created_at', ascending: false);
        history = List<Map<String, dynamic>>.from(response);

        // Enrich with profiles in a second query
        final userIds = history
            .map((h) => h['user_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        if (userIds.isNotEmpty) {
          try {
            final profiles = await Supabase.instance.client
                .from('profiles')
                .select('id, full_name, email')
                .inFilter('id', userIds);

            final profilesById = <String, Map<String, dynamic>>{
              for (final p in profiles) (p['id'] as String): Map<String, dynamic>.from(p)
            };

            for (final h in history) {
              final userId = h['user_id'] as String?;
              if (userId != null && profilesById.containsKey(userId)) {
                h['user_profile'] = {
                  'full_name': profilesById[userId]!['full_name'],
                  'email': profilesById[userId]!['email'],
                };
                // Cache user name
                final fullName = profilesById[userId]!['full_name'] as String?;
                final email = profilesById[userId]!['email'] as String?;
                _userNamesCache[userId] = fullName ?? email ?? userId;
              }
            }
          } catch (e) {
            debugPrint('task_history: Could not load profiles: $e');
          }
        }
      }

      // Load user names for assigned_to changes
      final assignedToIds = <String>{};
      for (final h in history) {
        if (h['field_name'] == 'assigned_to') {
          final oldValue = h['old_value'] as String?;
          final newValue = h['new_value'] as String?;
          if (oldValue != null && oldValue.length == 36 && oldValue.contains('-')) {
            assignedToIds.add(oldValue);
          }
          if (newValue != null && newValue.length == 36 && newValue.contains('-')) {
            assignedToIds.add(newValue);
          }
        }
      }

      if (assignedToIds.isNotEmpty) {
        try {
          final profiles = await Supabase.instance.client
              .from('profiles')
              .select('id, full_name, email')
              .inFilter('id', assignedToIds.toList());

          for (final p in profiles) {
            final id = p['id'] as String;
            final fullName = p['full_name'] as String?;
            final email = p['email'] as String?;
            _userNamesCache[id] = fullName ?? email ?? id;
          }
        } catch (e) {
          debugPrint('task_history: Could not load assigned_to profiles: $e');
        }
      }

      if (mounted) {
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _formatFieldName(String? fieldName) {
    if (fieldName == null) return '';
    switch (fieldName) {
      case 'title':
        return 'Título';
      case 'description':
        return 'Briefing';
      case 'status':
        return 'Status';
      case 'priority':
        return 'Prioridade';
      case 'assigned_to':
        return 'Responsável';
      case 'due_date':
        return 'Data de conclusão';
      case 'task':
        return 'Tarefa';
      case 'product_unlinked':
        return 'Produto';
      case 'product_linked':
        return 'Produto';
      default:
        return fieldName;
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return '';
    switch (status) {
      case 'todo':
        return 'A Fazer';
      case 'in_progress':
        return 'Em Progresso';
      case 'review':
        return 'Revisão';
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  String _formatPriority(String? priority) {
    if (priority == null) return '';
    switch (priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return priority;
    }
  }

  String _formatValue(String? fieldName, String? value) {
    if (value == null || value.isEmpty) return '';

    if (fieldName == 'status') {
      return _formatStatus(value);
    } else if (fieldName == 'priority') {
      return _formatPriority(value);
    } else if (fieldName == 'due_date' && value != 'sem prazo') {
      try {
        final date = DateTime.parse(value);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {
        return value;
      }
    } else if (fieldName == 'assigned_to') {
      // Se for um UUID, buscar no cache
      if (value.length == 36 && value.contains('-')) {
        return _userNamesCache[value] ?? value;
      }
      // Se for "não atribuído" ou outro texto
      if (value == 'não atribuído') {
        return 'não atribuído';
      }
      return value;
    }

    return value;
  }

  String _buildChangeMessage(Map<String, dynamic> entry) {
    final action = entry['action'] as String?;
    final fieldName = entry['field_name'] as String?;
    final oldValue = entry['old_value'] as String?;
    final newValue = entry['new_value'] as String?;

    if (action == 'created') {
      return 'criou a tarefa';
    } else if (action == 'deleted') {
      return 'excluiu a tarefa';
    } else if (action == 'updated' && fieldName != null) {
      final field = _formatFieldName(fieldName);

      // Para descrição/briefing, apenas informar que foi alterado
      if (fieldName == 'description') {
        return 'alterou o $field';
      }

      // Para desvinculação de produto
      if (fieldName == 'product_unlinked') {
        return 'desvinculou o produto "$oldValue"';
      }

      // Para vinculação de produto
      if (fieldName == 'product_linked') {
        return 'vinculou o produto "$newValue"';
      }

      final oldFormatted = _formatValue(fieldName, oldValue);
      final newFormatted = _formatValue(fieldName, newValue);

      if (oldFormatted.isNotEmpty && newFormatted.isNotEmpty) {
        return 'alterou $field de "$oldFormatted" para "$newFormatted"';
      } else if (newFormatted.isNotEmpty) {
        return 'definiu $field como "$newFormatted"';
      } else if (oldFormatted.isNotEmpty) {
        return 'removeu $field (era "$oldFormatted")';
      }
    }

    return 'fez uma alteração';
  }

  IconData _getActionIcon(String? action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'deleted':
        return Icons.delete_outline;
      default:
        return Icons.history;
    }
  }

  Color _getActionColor(BuildContext context, String? action) {
    final cs = Theme.of(context).colorScheme;
    switch (action) {
      case 'created':
        return cs.tertiary;
      case 'updated':
        return cs.primary;
      case 'deleted':
        return cs.error;
      default:
        return cs.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Erro ao carregar histórico: $_error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Nenhuma alteração registrada',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _history[index];
        final action = entry['action'] as String?;
        final createdAt = entry['created_at'] as String?;
        final profile = entry['user_profile'] as Map<String, dynamic>?;
        final userName = profile?['full_name'] as String? ??
                        profile?['email'] as String? ??
                        'Usuário desconhecido';

        DateTime? timestamp;
        if (createdAt != null) {
          try {
            timestamp = DateTime.parse(createdAt);
          } catch (_) {}
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getActionColor(context, action).withValues(alpha: 0.1),
            child: Icon(
              _getActionIcon(action),
              color: _getActionColor(context, action),
              size: 20,
            ),
          ),
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' '),
                TextSpan(text: _buildChangeMessage(entry)),
              ],
            ),
          ),
          subtitle: timestamp != null
              ? Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                )
              : null,
        );
      },
    );
  }
}

