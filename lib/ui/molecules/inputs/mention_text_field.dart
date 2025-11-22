import 'package:flutter/material.dart';
import 'mention_text_controller.dart';
import 'mention_overlay.dart';

/// TextField customizado que suporta menções (@username) com formatação visual
///
/// SOLUÇÃO DEFINITIVA para o problema do cursor:
/// - Quando EDITANDO (com foco): mostra @[Nome](id) - cursor funciona perfeitamente
/// - Quando NÃO EDITANDO (sem foco): mostra @Nome - fica bonito
///
/// Esta é a única solução que funciona corretamente no Flutter sem criar
/// um RenderObject completamente customizado.
class MentionTextField extends StatefulWidget {
  final String initialText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final ValueChanged<List<String>>? onMentionsChanged;

  const MentionTextField({
    super.key,
    this.initialText = '',
    this.controller,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.enabled = true,
    this.maxLines,
    this.minLines,
    this.style,
    this.decoration,
    this.validator,
    this.onMentionsChanged,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  late MentionTextEditingController _internalController;
  late FocusNode _internalFocusNode;
  MentionOverlay? _overlay;
  MentionTextFieldHelper? _helper;
  String? _errorText;
  bool _controllerCreatedInternally = false;
  bool _focusNodeCreatedInternally = false;

  @override
  void initState() {
    super.initState();
    
    // Criar controller interno se não foi fornecido
    if (widget.controller == null) {
      _internalController = MentionTextEditingController(
        text: widget.initialText,
        enableFormatting: true, // Iniciar com formatação habilitada
      );
      _controllerCreatedInternally = true;
    } else {
      // Usar controller externo mas envolver em MentionTextEditingController
      _internalController = MentionTextEditingController(
        text: widget.controller!.text,
        enableFormatting: true,
      );
      _controllerCreatedInternally = true;
      
      // Sincronizar com controller externo
      widget.controller!.addListener(_syncFromExternalController);
    }
    
    // Adicionar listener para notificar mudanças
    _internalController.addListener(_notifyChanges);
    
    // Criar FocusNode interno se não foi fornecido
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
      _focusNodeCreatedInternally = true;
    } else {
      _internalFocusNode = widget.focusNode!;
    }
    
    // Listener para alternar formatação baseado no foco
    _internalFocusNode.addListener(_onFocusChanged);
    
    // Aguardar o primeiro frame para ter acesso ao context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _overlay = MentionOverlay(
        context: context,
        layerLink: _layerLink,
        onUserSelected: _onUserSelected,
      );

      _helper = MentionTextFieldHelper(
        controller: _internalController,
        overlay: _overlay!,
      );

      _overlay!.loadUsers();
    });
  }

  @override
  void dispose() {
    _internalController.removeListener(_notifyChanges);
    _internalFocusNode.removeListener(_onFocusChanged);
    
    if (widget.controller != null) {
      widget.controller!.removeListener(_syncFromExternalController);
    }
    
    _helper?.dispose();
    _overlay?.dispose();
    
    if (_focusNodeCreatedInternally) {
      _internalFocusNode.dispose();
    }
    
    if (_controllerCreatedInternally) {
      _internalController.dispose();
    }
    
    super.dispose();
  }

  void _syncFromExternalController() {
    if (widget.controller!.text != _internalController.text) {
      _internalController.text = widget.controller!.text;
    }
  }

  void _onFocusChanged() {
    setState(() {
      // Quando ganha foco: desabilitar formatação (mostrar texto completo @[Nome](id))
      // Quando perde foco: habilitar formatação (mostrar @Nome)
      _internalController.enableFormatting = !_internalFocusNode.hasFocus;
    });
  }

  void _onUserSelected(Map<String, dynamic> user) {
    _helper?.insertMention(user);

    // Retornar o foco ao TextField após inserir a menção
    _internalFocusNode.requestFocus();
  }

  void _notifyChanges() {
    final text = _internalController.text;
    
    // Atualizar controller externo se fornecido
    if (widget.controller != null && widget.controller!.text != text) {
      widget.controller!.text = text;
    }
    
    // Validar se necessário
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(text);
      });
    }
    
    // Notificar mudanças
    widget.onChanged?.call(text);
    
    // Notificar menções
    if (widget.onMentionsChanged != null) {
      final mentions = _extractMentions(text);
      widget.onMentionsChanged!(mentions);
    }
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
      child: TextField(
        controller: _internalController,
        focusNode: _internalFocusNode,
        onTap: widget.onTap,
        enabled: widget.enabled,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        style: widget.style,
        decoration: (widget.decoration ?? const InputDecoration()).copyWith(
          errorText: _errorText,
        ),
      ),
    );
  }
}

