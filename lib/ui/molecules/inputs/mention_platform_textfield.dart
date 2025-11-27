import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../modules/modules.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

/// UI Constants for mention dropdown
class _MentionDropdownConstants {
  static const double width = 250;
  static const double maxHeight = 200;
  static const double minSpaceRequired = 220;
  static const double offsetFromField = 8;
  static const double avatarRadius = 16;
  static const double itemPaddingHorizontal = 16;
  static const double itemPaddingVertical = 12;
  static const double avatarSpacing = 12;
  static const double borderRadius = 8;
  static const double borderWidth = 1;

  // Theme colors
  static const Color backgroundColor = Color(0xFF151515);
  static const Color borderColor = Color(0xFF2A2A2A);
  static const Color textColor = Color(0xFFEAEAEA);
  static const Color mentionColor = Color(0xFF0095FF);
  static const Color mentionBackground = Color(0x260095FF);
}

/// Regex pattern for mention markdown: @[Name](uuid)
final _mentionMarkdownPattern = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');

/// Regex pattern for mention text: @Name
final _mentionTextPattern = RegExp(r'@([A-Za-zÀ-ÿ\s]+)');

// ============================================================================
// MAIN WIDGET
// ============================================================================

/// Platform-native text field with mention support
/// Uses native widgets on each platform for perfect cursor positioning
class MentionPlatformTextField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final double? height;
  final bool
      renderMentionsAsText; // Se true, mostra markdown completo sem renderização customizada

  const MentionPlatformTextField({
    super.key,
    this.initialText = '',
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.enabled = true,
    this.maxLines,
    this.style,
    this.decoration,
    this.height,
    this.renderMentionsAsText = false,
  });

  @override
  State<MentionPlatformTextField> createState() =>
      _MentionPlatformTextFieldState();
}

class _MentionPlatformTextFieldState extends State<MentionPlatformTextField> {
  static const MethodChannel _channel =
      MethodChannel('com.mybusiness/mention_textfield');

  int? _viewId;
  List<Map<String, dynamic>> _users = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await usersModule.getAllProfiles();
      setState(() {
        _users = users.map((user) {
          return {
            'id': user['id'] as String,
            'name': (user['full_name'] as String?) ?? (user['email'] as String),
            'avatar_url': user['avatar_url'] as String?,
          };
        }).toList();
      });

      // Send users to native side
      if (_viewId != null) {
        await _channel.invokeMethod('setUsers', {
          'viewId': _viewId,
          'users': _users,
        });
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTextChanged':
        final String text = call.arguments['text'] as String;
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          widget.onChanged?.call(text);
        });
        break;

      case 'onTap':
        widget.onTap?.call();
        break;

      case 'requestUsers':
        return _users;

      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      // When disabled, show read-only formatted text
      return _buildReadOnlyView();
    }

    // Platform-specific native view
    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        child: _buildPlatformView(),
      );
    }
    return _buildPlatformView();
  }

  Widget _buildReadOnlyView() {
    final text = widget.initialText.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: _buildFormattedText(text),
    );
  }

  Widget _buildFormattedText(String text) {
    // Parse mentions from @[Name](id) format and display as @Name
    final spans = <InlineSpan>[];
    final mentionRegex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      // Add text before mention
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // Add mention
      final name = match.group(1)!;
      spans.add(TextSpan(
        text: '@$name',
        style: const TextStyle(
          color: Color(0xFF0095FF),
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return Text.rich(
      TextSpan(
        style: widget.style ??
            const TextStyle(
                color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
        children: spans,
      ),
    );
  }

  Widget _buildPlatformView() {
    final Map<String, dynamic> creationParams = {
      'initialText': widget.initialText,
      'users': _users,
      'textColor': _colorToHex(widget.style?.color ?? const Color(0xFFEAEAEA)),
      'fontSize': widget.style?.fontSize ?? 14,
      'backgroundColor': _colorToHex(const Color(0xFF1E1E1E)),
      'mentionColor': _colorToHex(const Color(0xFF0095FF)),
      'hintText': widget.decoration?.hintText ?? 'Digite o texto...',
      'enabled': widget.enabled,
    };

    // Return platform-specific view
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
        return AndroidView(
          viewType: 'com.mybusiness/mention_textfield',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) {
            _viewId = id;
            _loadUsers(); // Reload users after view is created
          },
        );

      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'com.mybusiness/mention_textfield',
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) {
            _viewId = id;
            _loadUsers(); // Reload users after view is created
          },
        );

      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        // For desktop platforms, use Flutter native TextField with mention support
        return _FlutterMentionTextField(
          initialText: widget.initialText,
          users: _users,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          style: widget.style,
          decoration: widget.decoration,
          renderMentionsAsText: widget.renderMentionsAsText,
        );

      default:
        return const Center(
          child: Text('Platform not supported'),
        );
    }
  }

  String _colorToHex(Color color) {
    // Usar toARGB32() em vez de .value (deprecated)
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

// ============================================================================
// MENTION CONTROLLER
// ============================================================================

/// Controller que gerencia menções com dois textos:
/// - Texto exibido (limpo): "AAAA @Douglas Costa BBBBB"
/// - Texto armazenado (markdown): "AAAA @[Douglas Costa](uuid) BBBBB"
class _MentionBadgeController extends TextEditingController {
  final bool renderAsText;

  // Mapa de menções: {nome: uuid}
  final Map<String, String> _mentions = {};

  _MentionBadgeController({String? text, this.renderAsText = false})
      : super(text: _convertMarkdownToClean(text ?? '')) {
    // Extrair menções do texto markdown inicial
    if (text != null && text.isNotEmpty) {
      _extractMentions(text);
    }
  }

  /// Converte markdown "@[Nome](uuid)" para texto limpo "@Nome"
  static String _convertMarkdownToClean(String markdown) {
    if (markdown.isEmpty) return '';
    return markdown.replaceAllMapped(
        _mentionMarkdownPattern, (match) => '@${match.group(1)!}');
  }

  /// Extrai menções do texto markdown e armazena no mapa
  void _extractMentions(String markdown) {
    final matches = _mentionMarkdownPattern.allMatches(markdown);
    _mentions.clear();
    for (final match in matches) {
      _mentions[match.group(1)!] = match.group(2)!;
    }
  }

  /// Adiciona uma nova menção ao mapa
  void addMention(String name, String uuid) {
    _mentions[name] = uuid;
  }

  /// Obtém o texto completo com markdown para salvar
  String getMarkdownText() {
    String result = text;
    for (final entry in _mentions.entries) {
      result =
          result.replaceAll('@${entry.key}', '@[${entry.key}](${entry.value})');
    }
    return result;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;

    // Se renderAsText=true, mostrar o texto exatamente como está (sem estilização)
    if (renderAsText) {
      return TextSpan(text: text, style: style);
    }

    // Renderizar menções com estilo diferente
    final matches = _mentionTextPattern.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Verificar se é uma menção válida (existe no mapa)
      final name = match.group(1)!.trim();
      if (!_mentions.containsKey(name)) {
        continue; // Não é uma menção válida, pular
      }

      // Adicionar texto antes da menção
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }

      // Adicionar menção estilizada
      spans.add(TextSpan(
        text: '@$name',
        style: (style ?? const TextStyle()).copyWith(
          color: _MentionDropdownConstants.mentionColor,
          fontWeight: FontWeight.w600,
          backgroundColor: _MentionDropdownConstants.mentionBackground,
        ),
      ));

      lastEnd = match.end;
    }

    // Adicionar texto restante
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return TextSpan(children: spans, style: style);
  }
}

/// Flutter-native implementation for desktop platforms
/// Shows @Name as badge but stores @[Name](id) internally
class _FlutterMentionTextField extends StatefulWidget {
  final String initialText;
  final List<Map<String, dynamic>> users;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool renderMentionsAsText;

  const _FlutterMentionTextField({
    required this.initialText,
    required this.users,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.style,
    this.decoration,
    this.renderMentionsAsText = false,
  });

  @override
  State<_FlutterMentionTextField> createState() =>
      _FlutterMentionTextFieldState();
}

class _FlutterMentionTextFieldState extends State<_FlutterMentionTextField> {
  late _MentionBadgeController _controller;
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  int _queryStartPos = -1;
  String _currentQuery = '';
  List<Map<String, dynamic>> _filteredUsers = [];
  final LayerLink _layerLink = LayerLink();
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _controller = _MentionBadgeController(
      text: widget.initialText,
      renderAsText: widget.renderMentionsAsText,
    );
    _focusNode = widget.focusNode ?? FocusNode();
    _previousText = widget.initialText;
    _controller.addListener(_handleTextChanged);

    // Adicionar listener para detectar mudanças de seleção (cliques)
    _controller.addListener(() {
      final selection = _controller.selection;
      if (selection.isCollapsed && _controller.text.isNotEmpty) {
        final pos = selection.baseOffset;
        if (pos > 0 && pos <= _controller.text.length) {}
      }
    });
  }

  @override
  void didUpdateWidget(_FlutterMentionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Converter o initialText (markdown) para texto limpo
    final cleanInitialText =
        _MentionBadgeController._convertMarkdownToClean(widget.initialText);

    // Só atualizar o controller se o initialText mudou E o controller está desatualizado
    // Comparar com o texto LIMPO, não com o markdown
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != cleanInitialText) {
      // Salvar a posição atual do cursor
      final cursorPos = _controller.selection.baseOffset;

      // Atualizar o texto com o texto LIMPO
      _controller.text = cleanInitialText;
      _previousText = cleanInitialText;

      // Extrair menções do markdown e atualizar o mapa
      _controller._extractMentions(widget.initialText);

      // Restaurar a posição do cursor (ou colocar no final se a posição não for mais válida)
      final newCursorPos =
          cursorPos >= 0 && cursorPos <= cleanInitialText.length
              ? cursorPos
              : cleanInitialText.length;
      _controller.selection = TextSelection.collapsed(offset: newCursorPos);
    }
  }

  @override
  void dispose() {
    _hideDropdown();
    _controller.removeListener(_handleTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    // Se o texto não mudou, apenas a seleção mudou - não fazer nada
    if (text == _previousText) {
      return;
    }

    // Proteger menções de edição
    if (_previousText.isNotEmpty && text != _previousText) {
      final protectedText = _protectMentions(text, _previousText, cursorPos);
      if (protectedText != null) {
        _controller.value = protectedText;
        _previousText = protectedText.text;
        widget.onChanged?.call(_controller.getMarkdownText());
        return;
      }
    }

    _previousText = text;
    // Retornar texto markdown completo (não o texto limpo)
    widget.onChanged?.call(_controller.getMarkdownText());

    // Check if we're in mention mode
    if (_queryStartPos >= 0) {
      if (cursorPos > _queryStartPos && cursorPos <= text.length) {
        final query = text.substring(_queryStartPos, cursorPos);

        // Check if query contains space or newline (end of mention)
        if (query.contains(' ') || query.contains('\n')) {
          _hideDropdown();
          _queryStartPos = -1;
          return;
        }

        _currentQuery = query;
        _updateFilteredUsers();
      } else {
        _hideDropdown();
        _queryStartPos = -1;
      }
    } else {
      // Check if @ was just typed
      if (cursorPos > 0 && cursorPos <= text.length) {
        final charBeforeCursor = text.substring(cursorPos - 1, cursorPos);
        if (charBeforeCursor == '@') {
          _queryStartPos = cursorPos;
          _currentQuery = '';
          _updateFilteredUsers();
        }
      }
    }
  }

  /// Protege menções de serem editadas
  /// Retorna null se não houver proteção necessária
  /// AGORA trabalha com texto limpo "@Nome" ao invés de markdown "@[Nome](uuid)"
  TextEditingValue? _protectMentions(
      String newText, String oldText, int cursorPos) {
    // Se o texto não mudou, não há nada para proteger (apenas mudança de seleção)
    if (newText == oldText) {
      return null;
    }

    // Padrão para menções limpas: @Nome (sem UUID)
    final mentionPattern = RegExp(r'@([A-Za-zÀ-ÿ\s]+)');

    // Encontrar todas as menções no texto antigo
    final oldMentions = mentionPattern.allMatches(oldText).toList();

    for (final mention in oldMentions) {
      final mentionName = mention.group(1)!.trim();

      // Verificar se é uma menção válida (existe no mapa)
      if (!_controller._mentions.containsKey(mentionName)) {
        continue; // Não é uma menção válida, pular
      }

      final mentionStart = mention.start;
      final mentionEnd = mention.end;

      // Verificar se o cursor estava dentro ou logo após a menção
      if (cursorPos >= mentionStart && cursorPos <= mentionEnd + 1) {
        // Verificar se a menção foi modificada
        if (newText.length < oldText.length) {
          // Texto foi deletado - verificar se foi dentro da menção
          if (cursorPos >= mentionStart && cursorPos <= mentionEnd) {
            // Deletar a menção inteira E remover do mapa
            _controller._mentions.remove(mentionName);

            final beforeMention = oldText.substring(0, mentionStart);
            final afterMention = oldText.substring(mentionEnd);
            final fixedText = beforeMention + afterMention;

            return TextEditingValue(
              text: fixedText,
              selection: TextSelection.collapsed(offset: mentionStart),
            );
          }
        } else if (newText.length > oldText.length) {
          // Texto foi adicionado - verificar se foi dentro da menção
          if (cursorPos > mentionStart && cursorPos < mentionEnd) {
            // Mover cursor para depois da menção
            return TextEditingValue(
              text: oldText,
              selection: TextSelection.collapsed(offset: mentionEnd),
            );
          }
        }
      }
    }

    return null;
  }

  void _updateFilteredUsers() {
    setState(() {
      if (_currentQuery.isEmpty) {
        _filteredUsers = widget.users;
      } else {
        _filteredUsers = widget.users.where((user) {
          final name = user['name']?.toLowerCase() ?? '';
          return name.contains(_currentQuery.toLowerCase());
        }).toList();
      }
    });

    if (_filteredUsers.isNotEmpty) {
      _showDropdown();
    } else {
      _hideDropdown();
    }
  }

  void _showDropdown() {
    _hideDropdown();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Calcular se deve aparecer acima ou abaixo
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox?;

        bool showAbove = false;
        if (renderBox != null && overlay != null) {
          final position =
              renderBox.localToGlobal(Offset.zero, ancestor: overlay);
          final screenHeight = MediaQuery.of(context).size.height;
          final spaceBelow = screenHeight - position.dy - renderBox.size.height;
          final spaceAbove = position.dy;

          // Se não houver espaço embaixo, mostrar acima
          showAbove = spaceBelow < _MentionDropdownConstants.minSpaceRequired &&
              spaceAbove > spaceBelow;
        }

        return Positioned(
          width: _MentionDropdownConstants.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: showAbove ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor:
                showAbove ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(
                0,
                showAbove
                    ? -_MentionDropdownConstants.offsetFromField
                    : _MentionDropdownConstants.offsetFromField),
            child: Material(
              elevation: 4,
              borderRadius:
                  BorderRadius.circular(_MentionDropdownConstants.borderRadius),
              color: _MentionDropdownConstants.backgroundColor,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                      _MentionDropdownConstants.borderRadius),
                  border: Border.all(
                    color: _MentionDropdownConstants.borderColor,
                    width: _MentionDropdownConstants.borderWidth,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: _MentionDropdownConstants.maxHeight,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final avatarUrl = user['avatar_url'] as String?;
                      final userName = user['name'] ?? '';

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _insertMention(user),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _MentionDropdownConstants
                                  .itemPaddingHorizontal,
                              vertical:
                                  _MentionDropdownConstants.itemPaddingVertical,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _MentionDropdownConstants.borderColor,
                                  width: index < _filteredUsers.length - 1
                                      ? _MentionDropdownConstants.borderWidth
                                      : 0,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius:
                                      _MentionDropdownConstants.avatarRadius,
                                  backgroundColor:
                                      _MentionDropdownConstants.borderColor,
                                  backgroundImage:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                  child: avatarUrl == null || avatarUrl.isEmpty
                                      ? Text(
                                          userName.isNotEmpty
                                              ? userName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: _MentionDropdownConstants
                                                .textColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(
                                    width: _MentionDropdownConstants
                                        .avatarSpacing),
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      color:
                                          _MentionDropdownConstants.textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;

    final userName = user['name'] as String;
    final userId = user['id'] as String;

    // Adicionar menção ao mapa do controller
    _controller.addMention(userName, userId);

    // Calculate positions
    final beforeMention = text.substring(0, _queryStartPos - 1);
    final afterMention =
        cursorPos < text.length ? text.substring(cursorPos) : '';

    // Inserir apenas o nome limpo (sem UUID)
    final mention = '@$userName';

    // Adicionar espaço após a menção se não houver
    final mentionWithSpace =
        afterMention.startsWith(' ') || afterMention.isEmpty
            ? '$mention '
            : '$mention ';

    final newText = beforeMention + mentionWithSpace + afterMention;
    final newCursorPos = beforeMention.length + mentionWithSpace.length;

    // Fechar dropdown primeiro
    _hideDropdown();

    // Atualizar texto e cursor
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    _queryStartPos = -1;
    _currentQuery = '';

    // Garantir foco no próximo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onTap: widget.onTap,
        style: widget.style,
        decoration: widget.decoration,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
