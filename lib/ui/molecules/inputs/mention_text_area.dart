import 'package:flutter/material.dart';
import 'mention_overlay.dart';
import 'mention_text_controller.dart';
import 'mention_protection_formatter.dart';

/// Campo de texto multilinha com suporte a menções (@mentions)
///
/// Características:
/// - Detecta quando usuário digita "@"
/// - Mostra dropdown com lista de usuários
/// - Filtra usuários conforme digita
/// - Insere menção formatada ao selecionar
/// - Destaca menções visualmente
/// - Suporta múltiplas linhas
/// - Contador de caracteres opcional
///
/// Exemplo de uso:
/// ```dart
/// MentionTextArea(
///   controller: _controller,
///   labelText: 'Descrição',
///   hintText: 'Digite @ para mencionar alguém...',
///   minLines: 3,
///   maxLines: 8,
///   maxLength: 500,
///   showCounter: true,
///   onMentionsChanged: (mentions) {
///     print('Usuários mencionados: $mentions');
///   },
/// )
/// ```
class MentionTextArea extends StatefulWidget {
  /// Controller do campo (opcional - será criado automaticamente se não fornecido)
  final TextEditingController? controller;
  
  /// Valor inicial (se não usar controller)
  final String? initialValue;
  
  /// Texto do label
  final String? labelText;
  
  /// Texto de hint
  final String? hintText;
  
  /// Texto de ajuda
  final String? helperText;
  
  /// Número mínimo de linhas
  final int minLines;
  
  /// Número máximo de linhas (null = ilimitado)
  final int? maxLines;
  
  /// Comprimento máximo do texto
  final int? maxLength;
  
  /// Mostrar contador de caracteres
  final bool showCounter;
  
  /// Estilo do texto
  final TextStyle? style;
  
  /// Campo habilitado
  final bool enabled;
  
  /// Campo somente leitura
  final bool readOnly;
  
  /// FocusNode customizado
  final FocusNode? focusNode;
  
  /// Callback quando menções mudam
  final ValueChanged<List<String>>? onMentionsChanged;
  
  /// Função de validação
  final String? Function(String?)? validator;
  
  /// Callback quando o texto muda
  final ValueChanged<String>? onChanged;
  
  /// Alinhar label com hint
  final bool alignLabelWithHint;

  const MentionTextArea({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxLength,
    this.showCounter = false,
    this.style,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.onMentionsChanged,
    this.validator,
    this.onChanged,
    this.alignLabelWithHint = true,
  }) : assert(
          controller == null || initialValue == null,
          'Cannot provide both controller and initialValue',
        );

  @override
  State<MentionTextArea> createState() => _MentionTextAreaState();
}

class _MentionTextAreaState extends State<MentionTextArea> {
  final LayerLink _layerLink = LayerLink();
  late FocusNode _focusNode;
  late TextEditingController _controller;
  late MentionOverlay _overlay;
  late MentionTextFieldHelper _helper;
  bool _controllerCreatedInternally = false;

  @override
  void initState() {
    super.initState();


    // Criar controller se não foi fornecido
    if (widget.controller == null) {
      _controller = MentionTextEditingController(text: widget.initialValue ?? '');
      _controllerCreatedInternally = true;
    } else {
      _controller = widget.controller!;
    }

    _focusNode = widget.focusNode ?? FocusNode();

    _overlay = MentionOverlay(
      context: context,
      layerLink: _layerLink,
      onUserSelected: _onUserSelected,
    );

    _helper = MentionTextFieldHelper(
      controller: _controller,
      overlay: _overlay,
    );

    _overlay.loadUsers();
    _controller.addListener(_notifyMentionsChanged);
    _controller.addListener(_notifyTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyMentionsChanged);
    _controller.removeListener(_notifyTextChanged);
    _helper.dispose();
    _overlay.dispose();
    
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    
    if (_controllerCreatedInternally) {
      _controller.dispose();
    }
    
    super.dispose();
  }

  void _onUserSelected(Map<String, dynamic> user) {
    _helper.insertMention(user);
    _notifyMentionsChanged();

    // Retornar o foco ao TextField após inserir a menção
    _focusNode.requestFocus();
  }

  void _notifyMentionsChanged() {
    if (widget.onMentionsChanged == null) return;
    
    final mentions = _extractMentions(_controller.text);
    widget.onMentionsChanged!(mentions);
  }

  void _notifyTextChanged() {
    if (widget.onChanged == null) return;
    widget.onChanged!(_controller.text);
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(2)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        style: widget.style,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          alignLabelWithHint: widget.alignLabelWithHint,
          counterText: widget.showCounter ? null : '', // Esconde contador se showCounter = false
        ),
        validator: widget.validator,
        inputFormatters: [
          MentionProtectionFormatter(),
        ],
      ),
    );
  }
}

