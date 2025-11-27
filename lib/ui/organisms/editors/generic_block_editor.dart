import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/cache_file_service.dart';

import '../../../services/briefing_image_service.dart';
import '../../atoms/buttons/buttons.dart';
import '../../atoms/inputs/inputs.dart';
import '../../atoms/image_viewer/image_viewer.dart';
import '../../molecules/inputs/mention_platform_textfield.dart';
import '../../molecules/text/mention_text.dart';
import '../lists/reorderable_drag_list.dart';

/// Instância do serviço de imagens (reutiliza o mesmo serviço do briefing)
final _imageService = BriefingImageService();

/// Tipos de blocos suportados
enum BlockType { text, checkbox, image, table }

/// Modelo de bloco para o GenericBlockEditor
class EditorBlock {
  final String id;
  final BlockType type;
  final String content;

  EditorBlock({
    required this.id,
    required this.type,
    required this.content,
  });

  EditorBlock copyWith({String? id, BlockType? type, String? content}) =>
      EditorBlock(
        id: id ?? this.id,
        type: type ?? this.type,
        content: content ?? this.content,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
      };

  static EditorBlock fromJson(Map<String, dynamic> map) {
    final t = (map['type'] ?? 'text').toString();
    final type = BlockType.values.firstWhere(
      (e) => e.name == t,
      orElse: () => BlockType.text,
    );
    return EditorBlock(
      id: (map['id'] ?? UniqueKey().toString()).toString(),
      type: type,
      content: (map['content'] ?? '').toString(),
    );
  }
}

/// GenericBlockEditor
///
/// Um wrapper genérico que expõe exatamente o comportamento do CommentEditor,
/// com uma API reutilizável e um toolbar opcional com os mesmos botões
/// (texto, checkbox, imagem, tabela, emoji).
///
/// Objetivo: permitir reutilização do editor de blocos em outras telas sem
/// duplicação de código, mantendo 100% da experiência atual do comentário.
class GenericBlockEditor extends StatefulWidget {
  final String? initialJson;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  /// Mostra o toolbar padrão (botões) abaixo do editor
  final bool showToolbar;

  /// Widget extra à direita do toolbar (opcional)
  final List<Widget> trailingToolbarActions;

  /// Callback para abrir o seletor de emojis (a UI do picker costuma ser externa)
  final VoidCallback? onOpenEmojiPicker;

  /// Controlador opcional para acionar métodos públicos do editor
  final GenericBlockEditorController? controller;

  /// Quando true (em modo leitura), exibe overlay de "enviando" nos blocos de imagem
  final bool isUploading;

  const GenericBlockEditor({
    super.key,
    this.initialJson,
    this.enabled = true,
    this.onChanged,
    this.hintText,
    this.showToolbar = true,
    this.trailingToolbarActions = const [],
    this.onOpenEmojiPicker,
    this.controller,
    this.isUploading = false,
    this.onImageAdded,
  });

  /// Callback para upload imediato de imagem (retorna URL remota)
  final Future<String?> Function(String localPath, List<int> bytes)?
      onImageAdded;

  @override
  State<GenericBlockEditor> createState() => GenericBlockEditorState();
}

class GenericBlockEditorState extends State<GenericBlockEditor> {
  late final GenericBlockEditorController _controller;

  // Estado interno mínimo (será expandido para paridade total com CommentEditor)
  List<EditorBlock> _blocks = [
    EditorBlock(id: UniqueKey().toString(), type: BlockType.text, content: ''),
  ];
  String? _lastNotifiedJson;
  int? _lastFocusedIndex;
  final Map<int, bool Function(String emoji)> _insertHandlers = {};

  @override
  void didUpdateWidget(covariant GenericBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialJson != oldWidget.initialJson &&
        widget.initialJson != null) {
      try {
        final decoded = jsonDecode(widget.initialJson!);
        if (decoded is Map<String, dynamic> && decoded.containsKey('blocks')) {
          final blocks = decoded['blocks'] as List?;
          if (blocks != null) {
            setState(() {
              _blocks = blocks
                  .map((b) => EditorBlock.fromJson(b as Map<String, dynamic>))
                  .toList();
              _lastFocusedIndex = null;
              _insertHandlers.clear();
            });
            _lastNotifiedJson = null;
            _notifyChange();
          }
        }
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? GenericBlockEditorController();
    _controller._state = this;
    _loadFromJson();
    _lastNotifiedJson = _toJson();
  }

  @override
  void dispose() {
    _controller._state = null;
    super.dispose();
  }

  // ---- Métodos públicos (API) ----
  void clear() {
    setState(() {
      _blocks = [
        EditorBlock(
            id: UniqueKey().toString(), type: BlockType.text, content: '')
      ];
    });
    _notifyChange();
  }

  void setJson(String json) {
    try {
      final map = json.isEmpty ? {} : jsonDecode(json) as Map<String, dynamic>;
      final list = (map['blocks'] as List?) ?? const [];
      setState(() {
        _blocks = list
            .map((e) => EditorBlock.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_blocks.isEmpty) {
          _blocks = [
            EditorBlock(
                id: UniqueKey().toString(), type: BlockType.text, content: '')
          ];
        }
      });
      _notifyChange();
    } catch (_) {
      // se json inválido, mantém estado atual
    }
  }

  void addTextBlock() {
    setState(() {
      _blocks.add(EditorBlock(
          id: UniqueKey().toString(), type: BlockType.text, content: ''));
    });
    _notifyChange();
  }

  void addCheckboxBlock() {
    final content = jsonEncode({'checked': false, 'text': ''});
    setState(() {
      _blocks.add(EditorBlock(
          id: UniqueKey().toString(),
          type: BlockType.checkbox,
          content: content));
    });
    _notifyChange();
  }

  void addTableBlock() {
    // tabela 3x3 básica
    final rows = List.generate(3, (_) => List.generate(3, (_) => ''));
    final content = jsonEncode({'rows': rows});
    setState(() {
      _blocks.add(EditorBlock(
          id: UniqueKey().toString(), type: BlockType.table, content: content));
    });
    _notifyChange();
  }

  Future<void> pickImage() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: false, withData: false);
    if (res == null || res.files.isEmpty) return;
    final filePath = res.files.first.path;
    if (filePath == null) return;
    await addImageFromPath(filePath);
  }

  /// Adiciona uma imagem a partir de um caminho de arquivo (usado por drag & drop)
  Future<void> addImageFromPath(String filePath) async {
    if (!mounted) return;

    // Adicionar imagem imediatamente
    final localUrl =
        filePath.startsWith('file://') ? filePath : 'file://$filePath';
    final blockId = UniqueKey().toString();
    final name = filePath.split(Platform.pathSeparator).last;
    final content =
        jsonEncode({'url': localUrl, 'caption': '', 'filename': name});
    setState(() {
      _blocks.add(
          EditorBlock(id: blockId, type: BlockType.image, content: content));
    });
    _notifyChange();

    // Copiar para cache em background
    CacheFileService.copyToEditorCache(filePath, prefix: 'Editor')
        .then((cached) async {
      if (!mounted) return;
      final cachedUrl = 'file://${cached.path}';
      final cachedContent = jsonEncode({'url': cachedUrl, 'caption': ''});
      final index = _blocks.indexWhere((b) => b.id == blockId);
      if (index != -1) {
        setState(() {
          _blocks[index] = EditorBlock(
              id: blockId, type: BlockType.image, content: cachedContent);
        });
        _notifyChange();
      }

      // Se houver callback de upload, iniciar imediatamente
      if (widget.onImageAdded != null) {
        try {
          final bytes = await File(cached.path).readAsBytes();
          final remoteUrl = await widget.onImageAdded!(cached.path, bytes);
          if (remoteUrl != null && mounted) {
            // Atualizar bloco com URL remota
            final idx = _blocks.indexWhere((b) => b.id == blockId);
            if (idx != -1) {
              final currentContent = _blocks[idx].content;
              String currentCaption = '';
              String? currentFilename;
              try {
                final d = jsonDecode(currentContent);
                currentCaption = d['caption'] ?? '';
                currentFilename = d['filename'];
              } catch (_) {}

              setState(() {
                _blocks[idx] = EditorBlock(
                    id: blockId,
                    type: BlockType.image,
                    content: jsonEncode({
                      'url': remoteUrl,
                      'caption': currentCaption,
                      'filename': currentFilename
                    }));
              });
              _notifyChange();
            }
          }
        } catch (e) {
          // Erro no upload silencioso, mantém local
        }
      }
    }).catchError((_) {
      // Ignora erros - imagem já está visível
    });
  }

  void insertEmoji(String emoji) {
    if (!widget.enabled) return;

    // 1) Tenta inserir no bloco atualmente focado (texto ou legenda de imagem)
    if (_lastFocusedIndex != null) {
      final handler = _insertHandlers[_lastFocusedIndex!];
      final used = handler != null && handler(emoji);
      if (used) {
        _notifyChange();
        setState(() {});
        return;
      }
    }

    // 2) Se o último bloco for imagem, inserir na legenda da última imagem
    if (_blocks.isNotEmpty && _blocks.last.type == BlockType.image) {
      setState(() {
        try {
          final last = _blocks.last;
          String url = last.content;
          String caption = '';
          try {
            final data = jsonDecode(last.content) as Map<String, dynamic>;
            url = (data["url"] as String? ?? '').trim();
            caption = (data["caption"] as String? ?? '').trim();
          } catch (_) {}
          final newCaption = caption + emoji;
          final newContent = jsonEncode({"url": url, "caption": newCaption});
          _blocks[_blocks.length - 1] = last.copyWith(content: newContent);
        } catch (e) {
          // Falha ao anexar na legenda
        }
        _notifyChange();
      });
      return;
    }

    // 3) Caso contrário, anexar ao último bloco de texto existente (nunca criar novo)
    final lastTextIndex =
        _blocks.lastIndexWhere((b) => b.type == BlockType.text);
    if (lastTextIndex >= 0) {
      setState(() {
        final lastText = _blocks[lastTextIndex];
        _blocks[lastTextIndex] =
            lastText.copyWith(content: lastText.content + emoji);
        _notifyChange();
      });
    }
  }

  Future<String> uploadCachedImages({
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    String? subfolderName,
    String? filePrefix,
    String? overrideJson,
  }) async {
    // Normaliza imagens locais: se alguma não estiver no cache da app, copia para {temp}/editor_images
    // antes do upload, para que possamos limpar com segurança depois.
    final rawJson = overrideJson ?? _toJson();

    Map<String, dynamic> map;
    try {
      map = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      map = {'blocks': []};
    }
    final blocks = (map['blocks'] as List?) ?? [];

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (b is! Map<String, dynamic>) continue;
      final typeStr = (b['type'] ?? 'text').toString();
      if (typeStr != 'image') continue;

      final contentStr = (b['content'] ?? '').toString();
      String? url;
      String? caption;
      String? filename;
      try {
        final data = jsonDecode(contentStr) as Map<String, dynamic>;
        url = (data['url'] as String?)?.trim();
        caption = (data['caption'] as String?)?.trim();
        filename = data['filename'] as String?;
      } catch (_) {
        url = contentStr.trim();
        caption = null;
        filename = null;
      }
      if (url == null || url.isEmpty) continue;
      final isHttp = url.startsWith('http://') || url.startsWith('https://');
      if (isHttp) continue;
      final localPath = url.startsWith('file://') ? url.substring(7) : url;
      if (!CacheFileService.isInAppCachePath(localPath)) {
        try {
          final cached = await CacheFileService.copyToEditorCache(localPath,
              prefix: 'Editor');
          final newUrl = 'file://${cached.path}';
          if (caption != null) {
            b['content'] = jsonEncode(
                {'url': newUrl, 'caption': caption, 'filename': filename});
          } else {
            b['content'] = jsonEncode(
                {'url': newUrl, 'caption': '', 'filename': filename});
          }
        } catch (_) {
          // Se a cópia falhar, mantém a URL original e segue
        }
      }
    }

    final updatedJson = jsonEncode(map);

    final uploaded = await _imageService.uploadCachedImages(
      briefingJson: updatedJson,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
      subTaskTitle: subTaskTitle,
      subfolderName: subfolderName,
      filePrefix: filePrefix,
    );
    return uploaded;
  }

  // ---- Build completo (paridade com CommentEditor) ----
  @override
  Widget build(BuildContext context) {
    final bool singleTextOnly =
        _blocks.length == 1 && _blocks.first.type == BlockType.text;

    final core = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: ReorderableDragList<EditorBlock>(
        items: _blocks,
        enabled: widget.enabled,
        padding: EdgeInsets.zero,
        dragHandlePaddingBuilder: (i, item) => item.type == BlockType.checkbox
            ? const EdgeInsets.only(right: 8, top: 4)
            : item.type == BlockType.table
                ? const EdgeInsets.only(right: 8, top: 8)
                : const EdgeInsets.only(right: 8),
        useInternalHandle: (i, item) => singleTextOnly,
        onReorder: _reorderBlocks,
        getKey: (b) => b.id,
        itemBuilder: (context, block, index) {
          final hideInView = !widget.enabled && _isBlockEmptyInView(block);
          if (hideInView) return const SizedBox.shrink();

          return Padding(
            padding:
                EdgeInsets.only(bottom: index < _blocks.length - 1 ? 8 : 0),
            child: _GBBlockWidget(
              key: ValueKey(block.id),
              block: block,
              enabled: widget.enabled,
              hintText: index == 0 ? widget.hintText : null,
              onChanged: (updated) => _updateBlock(index, updated),
              onRemove: widget.enabled && !singleTextOnly && _blocks.length > 1
                  ? () => _removeBlock(index)
                  : null,
              index: index,
              onFocused: (i) => setState(() {
                _lastFocusedIndex = i;
              }),
              registerInsertHandler: (i, handler) {
                _insertHandlers[i] = handler;
              },
              isUploading: widget.isUploading,
            ),
          );
        },
      ),
    );

    if (!widget.showToolbar) return core;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        core,
        const SizedBox(height: 8),
        _Toolbar(
          enabled: widget.enabled,
          controller: _controller,
          onOpenEmojiPicker: widget.onOpenEmojiPicker,
          trailing: widget.trailingToolbarActions,
        ),
      ],
    );
  }

  bool _isBlockEmptyInView(EditorBlock block) {
    try {
      switch (block.type) {
        case BlockType.text:
          return block.content.trim().isEmpty;
        case BlockType.checkbox:
          final data = jsonDecode(block.content) as Map<String, dynamic>;
          final text = (data['text'] as String? ?? '').trim();
          return text.isEmpty;
        case BlockType.image:
          try {
            final data = jsonDecode(block.content) as Map<String, dynamic>;
            final url = (data['url'] as String? ?? '').trim();
            return url.isEmpty;
          } catch (_) {
            final url = block.content.trim();
            return url.isEmpty;
          }
        case BlockType.table:
          final data = jsonDecode(block.content) as Map<String, dynamic>;
          final rows = (data['rows'] as List?) ?? [];
          if (rows.isEmpty) return true;
          for (final r in rows) {
            final row = (r as List?) ?? [];
            for (final c in row) {
              final txt = (c?.toString() ?? '').trim();
              if (txt.isNotEmpty) return false;
            }
          }
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
      _notifyChange();
    });
  }

  void _updateBlock(int index, EditorBlock block) {
    setState(() {
      _blocks[index] = block;
      _notifyChange();
    });
  }

  Future<void> _removeBlock(int index) async {
    final block = _blocks[index];
    if (block.type == BlockType.image && block.content.isNotEmpty) {
      // extrai url
      String url;
      try {
        final data = jsonDecode(block.content) as Map<String, dynamic>;
        url = (data['url'] as String? ?? '');
      } catch (_) {
        url = block.content;
      }
      if (url.startsWith('file://')) {
        try {
          final localPath = url.substring(7);
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      } else if (url.contains('drive.google.com')) {
        await _imageService.deleteImage(url);
      }
    }
    setState(() {
      _blocks.removeAt(index);
      _notifyChange();
    });
  }

  // ---- Helpers ----
  void _loadFromJson() {
    final raw = widget.initialJson;
    if (raw == null || raw.isEmpty) return;
    setState(() {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final items = (map['blocks'] as List?) ?? const [];
        _blocks = items
            .map((e) => EditorBlock.fromJson(e as Map<String, dynamic>))
            .toList();
        if (_blocks.isEmpty) {
          _blocks = [
            EditorBlock(
                id: UniqueKey().toString(), type: BlockType.text, content: '')
          ];
        }
      } catch (_) {
        // ignora
      }
    });
  }

  String _toJson() {
    final data = {'blocks': _blocks.map((e) => e.toJson()).toList()};
    return jsonEncode(data);
  }

  void _notifyChange() {
    final jsonStr = _toJson();
    if (jsonStr != _lastNotifiedJson) {
      _lastNotifiedJson = jsonStr;
      widget.onChanged?.call(jsonStr);
    }
  }
}

/// Widget de bloco individual (versão GenericBlockEditor)
class _GBBlockWidget extends StatefulWidget {
  final EditorBlock block;
  final bool enabled;
  final String? hintText;
  final ValueChanged<EditorBlock> onChanged;
  final VoidCallback? onRemove;
  final int index;
  final void Function(int index)? onFocused;
  final void Function(int index, bool Function(String) handler)?
      registerInsertHandler;
  final bool isUploading;

  const _GBBlockWidget({
    super.key,
    required this.block,
    required this.enabled,
    this.hintText,
    required this.onChanged,
    this.onRemove,
    required this.index,
    this.onFocused,
    this.registerInsertHandler,
    this.isUploading = false,
  });

  @override
  State<_GBBlockWidget> createState() => _GBBlockWidgetState();
}

class _GBBlockWidgetState extends State<_GBBlockWidget> {
  String _currentText = '';
  Timer? _debounceTimer;
  FocusNode? _textFocusNode;

  @override
  void initState() {
    super.initState();
    _currentText = widget.block.content;

    if (widget.block.type == BlockType.text) {
      _textFocusNode = FocusNode();
      _textFocusNode!.addListener(() {
        if (_textFocusNode!.hasFocus) {
          widget.onFocused?.call(widget.index);
        }
      });
      // Note: Emoji insertion for WebView will be handled differently
    }
  }

  void _onTextChanged(String newText) {
    _currentText = newText;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onChanged(widget.block.copyWith(content: newText));
      }
    });
  }

  @override
  void didUpdateWidget(covariant _GBBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content) {
      _currentText = widget.block.content;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBlockContent()),
          if (widget.onRemove != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconOnlyButton(
                icon: Icons.close_rounded,
                iconSize: 18,
                iconColor: const Color(0xFF9AA0A6),
                onPressed: widget.onRemove,
                padding: const EdgeInsets.all(6),
                tooltip: 'Remover',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockContent() {
    switch (widget.block.type) {
      case BlockType.image:
        return _buildImageBlock();
      case BlockType.checkbox:
        return _buildCheckboxBlock();
      case BlockType.table:
        return _buildTableBlock();
      case BlockType.text:
        return _buildTextBlock();
    }
  }

  Widget _buildTextBlock() {
    if (!widget.enabled) {
      final text = _currentText.trim();
      if (text.isEmpty) return const SizedBox.shrink();

      // Renderizar com suporte a menções
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: MentionText(
          text: text,
          style: const TextStyle(
              color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
        ),
      );
    }

    // Usar MentionPlatformTextField SEM estilização de menções
    return MentionPlatformTextField(
      initialText: widget.block.content,
      focusNode: _textFocusNode,
      onTap: () => widget.onFocused?.call(widget.index),
      enabled: widget.enabled,
      maxLines: null,
      height: null,
      style:
          const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
      decoration: const InputDecoration(
        hintText: 'Digite o texto...',
      ),
      onChanged: _onTextChanged,
      renderMentionsAsText: true, // SEM estilo (texto branco normal)
    );
  }

  Widget _buildImageBlock() {
    String url = widget.block.content;
    String caption = '';
    String? filename;
    try {
      final data = jsonDecode(widget.block.content) as Map<String, dynamic>;
      url = (data['url'] as String? ?? '').trim();
      caption = (data['caption'] as String? ?? '').trim();
      filename = data['filename'] as String?;
    } catch (_) {}

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 12, right: 16),
          width: widget.enabled ? 150 : null,
          height: widget.enabled ? 150 : null,
          constraints: widget.enabled
              ? null
              : const BoxConstraints(maxHeight: 300, maxWidth: 300),
          child: GestureDetector(
            onTap: !widget.enabled && url.isNotEmpty
                ? () => ImageViewer.show(
                      context,
                      imageUrl: url,
                      downloadFileName: filename ??
                          'comentario_${DateTime.now().millisecondsSinceEpoch}.jpg',
                    )
                : null,
            child: MouseRegion(
              cursor: !widget.enabled && url.isNotEmpty
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: () {
                      final isHttp = url.startsWith('http://') ||
                          url.startsWith('https://');
                      if (isHttp) {
                        // Se for URL do Google Drive, usar thumbnail para exibição (mais confiável)
                        String displayUrl = url;
                        if (url.contains('drive.google.com')) {
                          try {
                            final uri = Uri.parse(url);
                            final id = uri.queryParameters['id'];
                            if (id != null && id.isNotEmpty) {
                              displayUrl =
                                  'https://drive.google.com/thumbnail?id=$id&sz=w800';
                            }
                          } catch (_) {}
                        }

                        return CachedNetworkImage(
                          imageUrl: displayUrl,
                          fit: widget.enabled ? BoxFit.cover : BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          memCacheWidth: ((widget.enabled ? 150 : 300) *
                                  MediaQuery.of(context).devicePixelRatio)
                              .round(),
                          placeholder: (context, url) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Erro ao carregar imagem',
                                  style: TextStyle(color: Colors.red)),
                            );
                          },
                        );
                      }
                      final localPath =
                          url.startsWith('file://') ? url.substring(7) : url;
                      return Image.file(
                        File(localPath),
                        fit: widget.enabled ? BoxFit.cover : BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        cacheWidth: ((widget.enabled ? 150 : 300) *
                                MediaQuery.of(context).devicePixelRatio)
                            .round(),
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: frame == null
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : child,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Erro ao carregar imagem',
                                style: TextStyle(color: Colors.red)),
                          );
                        },
                      );
                    }(),
                  ),
                  if (!widget.enabled)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconOnlyButton(
                        onPressed: () => _downloadImage(url),
                        icon: Icons.download_rounded,
                        iconColor: Colors.white,
                        iconSize: 20,
                        tooltip: 'Baixar imagem',
                        padding: const EdgeInsets.all(8),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  if (!widget.enabled && widget.isUploading)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 6),
                            Text('Enviando para o Drive...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: SizedBox(
              height: widget.enabled ? 150 : 300,
              child: widget.enabled
                  ? Builder(builder: (context) {
                      widget.registerInsertHandler?.call(widget.index, (emoji) {
                        try {
                          final map = {'url': url, 'caption': caption + emoji};
                          widget.onChanged(
                              widget.block.copyWith(content: jsonEncode(map)));
                          return true;
                        } catch (e) {
                          return false;
                        }
                      });
                      return MentionPlatformTextField(
                        initialText: caption,
                        onTap: () => widget.onFocused?.call(widget.index),
                        maxLines: null,
                        height: 150,
                        style: const TextStyle(
                            color: Color(0xFFEAEAEA),
                            fontSize: 13,
                            height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Adicione uma legenda...',
                        ),
                        onChanged: (newCaption) {
                          final map = {'url': url, 'caption': newCaption};
                          widget.onChanged(
                              widget.block.copyWith(content: jsonEncode(map)));
                        },
                        renderMentionsAsText: true,
                      );
                    })
                  : (caption.trim().isEmpty
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          child: MentionText(
                            text: caption,
                            style: const TextStyle(
                                color: Color(0xFFEAEAEA),
                                fontSize: 13,
                                height: 1.5),
                          ),
                        )),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadImage(String url) async {
    try {
      final isHttp = url.startsWith('http://') || url.startsWith('https://');
      final isFile = url.startsWith('file://') ||
          (!isHttp && (url.contains('\\') || url.contains('/')));

      // Sugerir nome com extensão adequada
      String suggestedName =
          'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (isHttp) {
        final uri = Uri.tryParse(url);
        final last = (uri?.pathSegments.isNotEmpty ?? false)
            ? uri!.pathSegments.last
            : '';
        if (last.isNotEmpty && last.contains('.')) {
          final ext = last.split('.').last;
          suggestedName =
              'image_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
        }
      } else if (isFile) {
        final srcPath = url.startsWith('file://') ? url.substring(7) : url;
        final base = srcPath.split(RegExp(r'[\\/]')).last;
        final ext = base.contains('.') ? base.split('.').last : 'jpg';
        suggestedName = 'image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar imagem',
        fileName: suggestedName,
        type: FileType.any,
      );
      if (outputPath == null) return;

      if (isFile) {
        final srcPath = url.startsWith('file://') ? url.substring(7) : url;
        await File(srcPath).copy(outputPath);
      } else {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await File(outputPath).writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Erro ao baixar imagem: ${response.statusCode}');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Imagem baixada com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao baixar imagem: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Widget _buildCheckboxBlock() {
    try {
      final data = jsonDecode(widget.block.content) as Map<String, dynamic>;
      final checked = data['checked'] as bool? ?? false;
      final text = (data['text'] as String? ?? '').trim();
      if (!widget.enabled && text.isEmpty) return const SizedBox.shrink();

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12),
            child: GenericCheckbox(
              value: checked,
              onChanged: (v) {
                final newData = {'checked': v == true, 'text': text};
                widget.onChanged(
                    widget.block.copyWith(content: jsonEncode(newData)));
              },
              enabled: true,
            ),
          ),
          Expanded(
            child: widget.enabled
                ? MentionPlatformTextField(
                    initialText: text,
                    onChanged: (newText) {
                      final newData = {'checked': checked, 'text': newText};
                      widget.onChanged(
                          widget.block.copyWith(content: jsonEncode(newData)));
                    },
                    enabled: widget.enabled,
                    maxLines: null,
                    height: null,
                    style: const TextStyle(
                        color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Digite o item...',
                    ),
                    renderMentionsAsText: true,
                  )
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: MentionText(
                      text: text,
                      style: TextStyle(
                        color: const Color(0xFFEAEAEA),
                        fontSize: 14,
                        height: 1.5,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: const Color(0xFF9AA0A6),
                      ),
                    ),
                  ),
          ),
        ],
      );
    } catch (e) {
      return Text('Erro ao carregar checkbox: $e');
    }
  }

  Widget _buildTableBlock() {
    try {
      final data = jsonDecode(widget.block.content) as Map<String, dynamic>;
      final rows = (data['rows'] as List?)
              ?.map((r) => (r as List).map((c) => c.toString()).toList())
              .toList() ??
          [
            ['', '']
          ];

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.enabled)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GBTableActionButton(
                          icon: Icons.add_box_outlined,
                          tooltip: 'Adicionar linha',
                          onPressed: () {
                            final newRows =
                                rows.map((r) => List<String>.from(r)).toList();
                            final newRow =
                                List.generate(rows.first.length, (_) => '');
                            newRows.add(newRow);
                            widget.onChanged(widget.block.copyWith(
                                content: jsonEncode({'rows': newRows})));
                          },
                        ),
                        const SizedBox(height: 4),
                        _GBTableActionButton(
                          icon: Icons.view_column_outlined,
                          tooltip: 'Adicionar coluna',
                          onPressed: () {
                            final newRows = rows.map((r) {
                              final newRow = List<String>.from(r);
                              newRow.add('');
                              return newRow;
                            }).toList();
                            widget.onChanged(widget.block.copyWith(
                                content: jsonEncode({'rows': newRows})));
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF2A2A2A), width: 1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: rows.asMap().entries.map((rowEntry) {
                        final rowIndex = rowEntry.key;
                        final row = rowEntry.value;
                        final isLastRow = rowIndex == rows.length - 1;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: row.asMap().entries.map((cellEntry) {
                              final colIndex = cellEntry.key;
                              final cellValue = cellEntry.value;
                              final isLastCol = colIndex == row.length - 1;
                              return Expanded(
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: isLastCol
                                          ? BorderSide.none
                                          : const BorderSide(
                                              color: Color(0xFF2A2A2A),
                                              width: 1),
                                      bottom: isLastRow
                                          ? BorderSide.none
                                          : const BorderSide(
                                              color: Color(0xFF2A2A2A),
                                              width: 1),
                                    ),
                                  ),
                                  child: SizedBox.expand(
                                    child: _GBTableCellField(
                                      initialValue: cellValue,
                                      enabled: widget.enabled,
                                      onChanged: (value) {
                                        final newRows = rows
                                            .map((r) => List<String>.from(r))
                                            .toList();
                                        newRows[rowIndex][colIndex] = value;
                                        widget.onChanged(widget.block.copyWith(
                                            content:
                                                jsonEncode({'rows': newRows})));
                                      },
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (widget.enabled)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GBTableActionButton(
                          icon: Icons.remove_circle_outline,
                          tooltip: 'Remover linha',
                          onPressed: rows.length > 1
                              ? () {
                                  final newRows = rows
                                      .map((r) => List<String>.from(r))
                                      .toList();
                                  newRows.removeLast();
                                  widget.onChanged(widget.block.copyWith(
                                      content: jsonEncode({'rows': newRows})));
                                }
                              : null,
                        ),
                        const SizedBox(height: 4),
                        _GBTableActionButton(
                          icon: Icons.view_column_outlined,
                          tooltip: 'Remover coluna',
                          onPressed: rows.first.length > 1
                              ? () {
                                  final newRows = rows.map((r) {
                                    final newRow = List<String>.from(r);
                                    newRow.removeLast();
                                    return newRow;
                                  }).toList();
                                  widget.onChanged(widget.block.copyWith(
                                      content: jsonEncode({'rows': newRows})));
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      return Text('Erro ao carregar tabela: $e');
    }
  }
}

class _GBTableActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const _GBTableActionButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
  @override
  State<_GBTableActionButton> createState() => _GBTableActionButtonState();
}

class _GBTableActionButtonState extends State<_GBTableActionButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Tooltip desabilitado para evitar erro de múltiplos tickers
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isEnabled
                ? (_isHovered
                    ? primaryColor.withValues(alpha: 0.16)
                    : const Color(0xFF1E1E1E))
                : const Color(0xFF1E1E1E).withValues(alpha: 0.6),
            border: Border.all(color: const Color(0xFF2A2A2A)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: isEnabled
                ? (_isHovered ? primaryColor : const Color(0xFF9AA0A6))
                : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

class _GBTableCellField extends StatefulWidget {
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _GBTableCellField({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });
  @override
  State<_GBTableCellField> createState() => _GBTableCellFieldState();
}

class _GBTableCellFieldState extends State<_GBTableCellField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      widget.onChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant _GBTableCellField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            _controller.text.isEmpty ? '' : _controller.text,
            style: const TextStyle(
                color: Color(0xFFEAEAEA), fontSize: 13, height: 1.5),
          ),
        ),
      );
    }
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: null,
      minLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style:
          const TextStyle(color: Color(0xFFEAEAEA), fontSize: 13, height: 1.5),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        filled: false,
      ),
    );
  }
}

/// Controlador para operar o GenericBlockEditor externamente
/// O próprio editor faz o bind deste controlador em runtime.
class GenericBlockEditorController {
  GenericBlockEditorState? _state;

  // Métodos públicos encaminhados
  void clear() => _state?.clear();
  void setJson(String json) => _state?.setJson(json);
  void addTextBlock() => _state?.addTextBlock();
  void addCheckboxBlock() => _state?.addCheckboxBlock();
  void addTableBlock() => _state?.addTableBlock();
  void pickImage() => _state?.pickImage();
  void insertEmoji(String emoji) => _state?.insertEmoji(emoji);
  Future<void> addImageFromPath(String path) async =>
      await _state?.addImageFromPath(path);

  Future<String> uploadCachedImages({
    required String clientName,
    required String projectName,
    required String taskTitle,
    String? companyName,
    String? subTaskTitle,
    String? subfolderName,
    String? filePrefix,
    String? overrideJson,
  }) async {
    final s = _state;
    if (s == null) return '';
    return s.uploadCachedImages(
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
      subTaskTitle: subTaskTitle,
      subfolderName: subfolderName,
      filePrefix: filePrefix,
      overrideJson: overrideJson,
    );
  }
}

class _Toolbar extends StatelessWidget {
  final bool enabled;
  final GenericBlockEditorController controller;
  final VoidCallback? onOpenEmojiPicker;
  final List<Widget> trailing;

  const _Toolbar({
    required this.enabled,
    required this.controller,
    this.onOpenEmojiPicker,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    // Mesma linguagem visual dos botões existentes (IconOnlyButton)
    return Row(
      children: [
        IconOnlyButton(
          icon: Icons.text_fields,
          tooltip: 'Texto',
          onPressed: controller.addTextBlock,
        ),
        const SizedBox(width: 8),
        IconOnlyButton(
          icon: Icons.check_box_outlined,
          tooltip: 'Checkbox',
          onPressed: controller.addCheckboxBlock,
        ),
        const SizedBox(width: 8),
        IconOnlyButton(
          icon: Icons.image_outlined,
          tooltip: 'Imagem',
          onPressed: controller.pickImage,
        ),
        const SizedBox(width: 8),
        IconOnlyButton(
          icon: Icons.table_chart_outlined,
          tooltip: 'Tabela',
          onPressed: controller.addTableBlock,
        ),
        const SizedBox(width: 8),
        IconOnlyButton(
          icon: Icons.emoji_emotions_outlined,
          tooltip: 'Emoji',
          onPressed: onOpenEmojiPicker,
        ),
        const Spacer(),
        ...trailing,
      ],
    );
  }
}
