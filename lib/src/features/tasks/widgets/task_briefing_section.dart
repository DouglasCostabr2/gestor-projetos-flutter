import 'package:flutter/material.dart';
import 'package:my_business/ui/organisms/editors/generic_block_editor.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/molecules/containers/containers.dart';

/// Reusable Task Briefing Section Widget
///
/// Editor de blocos genérico com suporte a texto, checkboxes, imagens e tabelas.
///
/// Features:
/// - Editor de blocos moderno (mesmo usado nos comentários)
/// - Checkboxes sempre clicáveis (mesmo em modo read-only)
/// - Inserção de imagens
/// - Tabelas editáveis
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
class TaskBriefingSection extends StatefulWidget {
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
  State<TaskBriefingSection> createState() => _TaskBriefingSectionState();
}

class _TaskBriefingSectionState extends State<TaskBriefingSection> {
  late GenericBlockEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GenericBlockEditorController();
  }

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      child: SelectableContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com título e toolbar
            Row(
              children: [
                Text('Briefing', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (widget.enabled) ...[
                  IconOnlyButton(
                    icon: Icons.text_fields,
                    tooltip: 'Adicionar texto',
                    onPressed: () => _controller.addTextBlock(),
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    icon: Icons.check_box_outlined,
                    tooltip: 'Adicionar checkbox',
                    onPressed: () => _controller.addCheckboxBlock(),
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    icon: Icons.image_outlined,
                    tooltip: 'Inserir imagem',
                    onPressed: () => _controller.pickImage(),
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    icon: Icons.table_chart_outlined,
                    tooltip: 'Adicionar tabela',
                    onPressed: () => _controller.addTableBlock(),
                    iconSize: 18,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            const SizedBox(height: 12),

            // Editor
            GenericBlockEditor(
              controller: _controller,
              initialJson: widget.initialJson,
              enabled: widget.enabled,
              onChanged: widget.onJsonChanged,
              showToolbar: false,
            ),
          ],
        ),
      ),
    );
  }
}
