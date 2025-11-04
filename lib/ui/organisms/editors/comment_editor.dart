import 'package:flutter/material.dart';
import 'generic_block_editor.dart';

/// Editor de comentários simples (compatibilidade)
/// Wrapper fino do GenericBlockEditor
class CommentEditor extends StatefulWidget {
  final String? initialJson;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  const CommentEditor({
    super.key,
    this.initialJson,
    this.enabled = true,
    this.onChanged,
    this.hintText,
  });

  @override
  State<CommentEditor> createState() => CommentEditorState();
}

class CommentEditorState extends State<CommentEditor> {
  // Delegação para o GenericBlockEditor (fonte de verdade)
  final GenericBlockEditorController _ctl = GenericBlockEditorController();

  // API compatível
  void clear() => _ctl.clear();
  void setJson(String json) => _ctl.setJson(json);
  void addTextBlock() => _ctl.addTextBlock();
  void addCheckboxBlock() => _ctl.addCheckboxBlock();
  void addTableBlock() => _ctl.addTableBlock();
  void pickImage() => _ctl.pickImage();
  void insertEmoji(String emoji) => _ctl.insertEmoji(emoji);
  Future<String> uploadCachedImages({
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subfolderName,
    String? filePrefix,
    String? overrideJson,
  }) => _ctl.uploadCachedImages(
        clientName: clientName,
        projectName: projectName,
        taskTitle: taskTitle,
        companyName: companyName,
        subfolderName: subfolderName,
        filePrefix: filePrefix,
        overrideJson: overrideJson,
      );

  @override
  Widget build(BuildContext context) {
    return GenericBlockEditor(
      controller: _ctl,
      initialJson: widget.initialJson,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      hintText: widget.hintText,
      showToolbar: false,
    );
  }
}

