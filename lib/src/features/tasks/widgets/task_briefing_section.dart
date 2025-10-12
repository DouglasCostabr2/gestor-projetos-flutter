import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/widgets/custom_briefing_editor.dart';

/// Reusable Task Briefing Section Widget
///
/// Editor customizado simples com suporte a texto, checkboxes e imagens.
///
/// Features:
/// - Editor customizado e simples
/// - Checkboxes sempre clicáveis (mesmo em modo read-only)
/// - Inserção de imagens (upload para Google Drive)
/// - JSON simples e fácil de manter
///
/// Usage:
/// ```dart
/// TaskBriefingSection(
///   initialJson: task['description'],
///   onJsonChanged: (json) {
///     setState(() => _briefingJson = json);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskBriefingSection extends StatelessWidget {
  final String? initialText;
  final String? initialJson;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onJsonChanged;
  final bool enabled;

  // Informações para upload no Google Drive (não mais necessárias aqui)
  final String? taskId;
  final String? taskTitle;
  final String? projectName;
  final String? clientName;

  const TaskBriefingSection({
    super.key,
    this.initialText,
    this.initialJson,
    this.onChanged,
    this.onJsonChanged,
    this.enabled = true,
    this.taskId,
    this.taskTitle,
    this.projectName,
    this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Briefing', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        CustomBriefingEditor(
          initialJson: initialJson,
          enabled: enabled,
          onChanged: onJsonChanged,
        ),
      ],
    );
  }
}
