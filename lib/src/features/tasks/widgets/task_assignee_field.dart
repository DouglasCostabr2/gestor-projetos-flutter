import 'package:flutter/material.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';

/// Widget reutilizável para campo de seleção de responsável (assignee)
///
/// Características:
/// - Dropdown com lista de membros do projeto
/// - Opção "Não atribuído"
/// - Exibe nome completo ou email do usuário
/// - Validação automática de membro válido
/// - Callback para mudanças
///
/// Uso:
/// ```dart
/// TaskAssigneeField(
///   assigneeUserId: _assigneeUserId,
///   members: _members,
///   onAssigneeChanged: (userId) {
///     setState(() => _assigneeUserId = userId);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskAssigneeField extends StatelessWidget {
  final String? assigneeUserId;
  final List<Map<String, dynamic>> members;
  final ValueChanged<String?> onAssigneeChanged;
  final bool enabled;

  const TaskAssigneeField({
    super.key,
    required this.assigneeUserId,
    required this.members,
    required this.onAssigneeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Validate that current assignee is in members list
    final validAssignee = assigneeUserId != null &&
        members.any((m) => m['user_id'] == assigneeUserId)
        ? assigneeUserId
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GenericDropdownField<String?>(
          value: validAssignee,
          items: [
            const DropdownItem<String?>(
              value: null,
              label: 'Não atribuído',
            ),
            ...members.map((m) {
              final userId = m['user_id'] as String;
              final profile = m['profiles'] as Map<String, dynamic>?;
              final name = (profile?['full_name'] ??
                           profile?['email'] ??
                           'Usuário') as String;
              final avatarUrl = profile?['avatar_url'] as String?;

              return DropdownItem<String?>(
                value: userId,
                label: name,
                leadingIcon: CircleAvatar(
                  radius: 12,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 12)) : null,
                ),
              );
            }),
          ],
          onChanged: onAssigneeChanged,
          labelText: 'Responsável',
          enabled: enabled,
          width: constraints.maxWidth,
        );
      },
    );
  }
}

