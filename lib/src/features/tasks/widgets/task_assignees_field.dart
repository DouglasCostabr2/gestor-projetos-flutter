import 'package:flutter/material.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';

/// Widget reutilizável para campo de seleção de múltiplos responsáveis (assignees)
///
/// Características:
/// - Multi-select dropdown com lista de membros do projeto
/// - Exibe chips dos responsáveis selecionados
/// - Exibe nome completo ou email do usuário
/// - Suporta avatares
/// - Validação automática de membros válidos
/// - Callback para mudanças
///
/// Uso:
/// ```dart
/// TaskAssigneesField(
///   assigneeUserIds: _assigneeUserIds,
///   members: _members,
///   onAssigneesChanged: (userIds) {
///     setState(() => _assigneeUserIds = userIds);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskAssigneesField extends StatelessWidget {
  final List<String> assigneeUserIds;
  final List<Map<String, dynamic>> members;
  final ValueChanged<List<String>> onAssigneesChanged;
  final bool enabled;

  const TaskAssigneesField({
    super.key,
    required this.assigneeUserIds,
    required this.members,
    required this.onAssigneesChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Validate that current assignees are in members list
    final validAssignees = assigneeUserIds
        .where((userId) => members.any((m) => m['user_id'] == userId))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return MultiSelectDropdownField<String>(
          selectedValues: validAssignees,
          items: members.map((m) {
            final userId = m['user_id'] as String;
            final profile = m['profiles'] as Map<String, dynamic>?;
            final name = (profile?['full_name'] ??
                         profile?['email'] ??
                         'Usuário') as String;
            final avatarUrl = profile?['avatar_url'] as String?;

            return MultiSelectDropdownItem<String>(
              value: userId,
              label: name,
              leadingIcon: CircleAvatar(
                radius: 12,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null 
                    ? Text(
                        name[0].toUpperCase(), 
                        style: const TextStyle(fontSize: 12),
                      ) 
                    : null,
              ),
            );
          }).toList(),
          onChanged: onAssigneesChanged,
          labelText: 'Responsáveis',
          hintText: 'Selecione os responsáveis',
          enabled: enabled,
          width: constraints.maxWidth,
        );
      },
    );
  }
}

