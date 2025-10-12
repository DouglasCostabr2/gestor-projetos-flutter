import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/briefing_image_service.dart';
import 'reorderable_drag_list.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

/// Instância do serviço de imagens do briefing
final _briefingImageService = BriefingImageService();

/// Função helper para fazer upload de imagens em cache para o Google Drive (tarefas normais)
Future<String> uploadCustomBriefingCachedImages({
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
  String? companyName,
}) =>
    _briefingImageService.uploadCachedImages(
      briefingJson: briefingJson,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
    );

/// Função helper para fazer upload de imagens em cache de SUBTAREFAS para o Google Drive
Future<String> uploadCustomBriefingCachedImagesForSubTask({
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
  required String subTaskTitle,
  String? companyName,
}) =>
    _briefingImageService.uploadCachedImages(
      briefingJson: briefingJson,
      clientName: clientName,
      projectName: projectName,
      taskTitle: taskTitle,
      companyName: companyName,
      subTaskTitle: subTaskTitle,
    );

/// Editor de briefing customizado e simples
/// Suporta: texto, checkboxes, imagens
class CustomBriefingEditor extends StatefulWidget {
  final String? initialJson;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const CustomBriefingEditor({
    super.key,
    this.initialJson,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<CustomBriefingEditor> createState() => _CustomBriefingEditorState();
}

class _CustomBriefingEditorState extends State<CustomBriefingEditor> {
  List<BriefingBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _loadFromJson();
  }

  void _loadFromJson() {
    if (widget.initialJson == null || widget.initialJson!.isEmpty) {
      _blocks = [];
      return;
    }

    try {
      final data = jsonDecode(widget.initialJson!) as Map<String, dynamic>;

      // Verificar se é o formato novo (nosso custom editor)
      if (data.containsKey('blocks')) {
        final blocks = data['blocks'] as List?;
        if (blocks != null) {
          _blocks = blocks.map((b) => BriefingBlock.fromJson(b)).toList();
        }
      }
      // Verificar se é o formato antigo do AppFlowy Editor
      else if (data.containsKey('document')) {
        debugPrint('🔄 Convertendo formato AppFlowy para formato customizado...');
        _blocks = _convertFromAppFlowyFormat(data);
        debugPrint('✅ Conversão concluída: ${_blocks.length} blocos');
      }
      else {
        debugPrint('⚠️ Formato JSON desconhecido');
        _blocks = [];
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar JSON do briefing: $e');
      _blocks = [];
    }
  }

  /// Converte o formato do AppFlowy Editor para o formato customizado
  List<BriefingBlock> _convertFromAppFlowyFormat(Map<String, dynamic> data) {
    final blocks = <BriefingBlock>[];

    try {
      final document = data['document'] as Map<String, dynamic>?;
      if (document == null) return blocks;

      final children = document['children'] as List?;
      if (children == null) return blocks;

      for (final child in children) {
        if (child is! Map<String, dynamic>) continue;

        final type = child['type'] as String?;
        final childData = child['data'] as Map<String, dynamic>?;

        if (type == 'paragraph' && childData != null) {
          // Parágrafo de texto
          final delta = childData['delta'] as List?;
          if (delta != null && delta.isNotEmpty) {
            final text = _extractTextFromDelta(delta);
            if (text.isNotEmpty) {
              blocks.add(BriefingBlock(type: BlockType.text, content: text));
            }
          }
        } else if (type == 'todo_list' && childData != null) {
          // Checkbox
          final delta = childData['delta'] as List?;
          final checked = childData['checked'] as bool? ?? false;
          if (delta != null && delta.isNotEmpty) {
            final text = _extractTextFromDelta(delta);
            blocks.add(BriefingBlock(
              type: BlockType.checkbox,
              content: text,
              checked: checked,
            ));
          }
        } else if (type == 'image' && childData != null) {
          // Imagem
          final url = childData['url'] as String?;
          if (url != null && url.isNotEmpty) {
            blocks.add(BriefingBlock(type: BlockType.image, content: url));
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao converter formato AppFlowy: $e');
    }

    return blocks;
  }

  /// Extrai texto de um delta do AppFlowy
  String _extractTextFromDelta(List delta) {
    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is Map && op.containsKey('insert')) {
        buffer.write(op['insert']);
      }
    }
    return buffer.toString();
  }

  String _toJson() {
    final data = {
      'blocks': _blocks.map((b) => b.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  void _notifyChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(_toJson());
    }
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final block = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, block);
      _notifyChange();
    });
  }

  void _addTextBlock() {
    setState(() {
      _blocks.add(BriefingBlock(type: BlockType.text, content: ''));
      _notifyChange();
    });
  }

  void _addCheckboxBlock() {
    setState(() {
      _blocks.add(BriefingBlock(type: BlockType.checkbox, content: '', checked: false));
      _notifyChange();
    });
  }

  Future<void> _addImageBlock() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Salvar imagem no cache local
      final cacheDir = await getTemporaryDirectory();
      final briefingCacheDir = Directory(path.join(cacheDir.path, 'briefing_images'));
      if (!await briefingCacheDir.exists()) {
        await briefingCacheDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = pickedFile.path.split('.').last;
      final fileName = 'Briefing_$timestamp.$extension';
      final cachedImagePath = path.join(briefingCacheDir.path, fileName);

      // Copiar imagem para o cache
      final bytes = await File(pickedFile.path).readAsBytes();
      await File(cachedImagePath).writeAsBytes(bytes);

      // Usar URL local (file://) - será substituída por URL do Drive ao salvar
      final imageUrl = 'file://$cachedImagePath';

      setState(() {
        _blocks.add(BriefingBlock(type: BlockType.image, content: imageUrl));
        _notifyChange();
      });

      debugPrint('✅ Imagem adicionada ao briefing (cache): $imageUrl');
    } catch (e) {
      debugPrint('❌ Erro ao adicionar imagem: $e');
    }
  }

  void _addTableBlock() {
    setState(() {
      // Cria uma tabela 3x3 vazia por padrão
      final tableData = List.generate(3, (_) => List.generate(3, (_) => ''));
      _blocks.add(BriefingBlock(
        type: BlockType.table,
        content: '', // Não usado para tabelas
        tableData: tableData,
      ));
      _notifyChange();
    });
  }

  void _removeBlock(int index) {
    setState(() {
      final block = _blocks[index];
      
      // Se for imagem, deletar do cache/drive
      if (block.type == BlockType.image && block.content.isNotEmpty) {
        _deleteImage(block.content);
      }
      
      _blocks.removeAt(index);
      _notifyChange();
    });
  }

  Future<void> _deleteImage(String url) async {
    // Se for imagem local (cache), deletar
    if (url.startsWith('file://')) {
      try {
        final localPath = url.substring(7);
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Imagem local deletada do cache');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao deletar imagem local: $e');
      }
    }
    // Se for imagem do Google Drive, deletar do Drive
    else if (url.contains('drive.google.com')) {
      await _briefingImageService.deleteImage(url);
    }
  }

  void _updateBlock(int index, BriefingBlock block) {
    setState(() {
      _blocks[index] = block;
      _notifyChange();
    });
  }

  void _toggleCheckbox(int index) {
    setState(() {
      final block = _blocks[index];
      if (block.type == BlockType.checkbox) {
        _blocks[index] = block.copyWith(checked: !block.checked);
        _notifyChange();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          if (widget.enabled) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ToolbarButton(
                  icon: Icons.text_fields,
                  label: 'Texto',
                  onPressed: _addTextBlock,
                ),
                _ToolbarButton(
                  icon: Icons.check_box_outlined,
                  label: 'Checkbox',
                  onPressed: _addCheckboxBlock,
                ),
                _ToolbarButton(
                  icon: Icons.image_outlined,
                  label: 'Imagem',
                  onPressed: _addImageBlock,
                ),
                _ToolbarButton(
                  icon: Icons.table_chart_outlined,
                  label: 'Tabela',
                  onPressed: _addTableBlock,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            const SizedBox(height: 16),
          ],

          // Blocos sem scroll (altura hug content)
          GestureDetector(
            onDoubleTap: widget.enabled ? _addTextBlock : null,
            child: Container(
              color: Colors.transparent,
              child: _blocks.isEmpty && widget.enabled
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 48,
                              color: const Color(0xFF9AA0A6).withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Clique duas vezes para adicionar texto',
                              style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ReorderableDragList<BriefingBlock>(
                      items: _blocks,
                      enabled: widget.enabled,
                      padding: const EdgeInsets.only(bottom: 8),
                      onReorder: _reorderBlocks,
                      itemBuilder: (context, block, index) {
                        return _BlockWidget(
                          key: ValueKey('block_${block.hashCode}_$index'),
                          block: block,
                          enabled: widget.enabled,
                          index: index,
                          onChanged: (updated) => _updateBlock(index, updated),
                          onRemove: () => _removeBlock(index),
                          onToggleCheckbox: () => _toggleCheckbox(index),
                        );
                      },
                      getKey: (block) => 'block_${block.hashCode}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tipos de blocos suportados
enum BlockType {
  text,
  checkbox,
  image,
  table,
}

/// Modelo de um bloco de conteúdo
class BriefingBlock {
  final BlockType type;
  final String content;
  final bool checked;
  final String? caption; // Legenda para imagens
  final List<List<String>>? tableData; // Dados da tabela (linhas x colunas)

  BriefingBlock({
    required this.type,
    required this.content,
    this.checked = false,
    this.caption,
    this.tableData,
  });

  factory BriefingBlock.fromJson(Map<String, dynamic> json) {
    List<List<String>>? tableData;
    if (json['tableData'] != null) {
      tableData = (json['tableData'] as List)
          .map((row) => (row as List).map((cell) => cell.toString()).toList())
          .toList();
    }

    return BriefingBlock(
      type: BlockType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BlockType.text,
      ),
      content: json['content'] ?? '',
      checked: json['checked'] ?? false,
      caption: json['caption'],
      tableData: tableData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'content': content,
      if (type == BlockType.checkbox) 'checked': checked,
      if (caption != null && caption!.isNotEmpty) 'caption': caption,
      if (tableData != null && tableData!.isNotEmpty) 'tableData': tableData,
    };
  }

  BriefingBlock copyWith({
    BlockType? type,
    String? content,
    bool? checked,
    String? caption,
    List<List<String>>? tableData,
  }) {
    return BriefingBlock(
      type: type ?? this.type,
      content: content ?? this.content,
      checked: checked ?? this.checked,
      caption: caption ?? this.caption,
      tableData: tableData ?? this.tableData,
    );
  }
}

/// Botão da toolbar (usando IconTextButton genérico)
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconTextButton(
      onPressed: onPressed,
      icon: icon,
      label: label,
      iconSize: 16,
    );
  }
}

/// Widget de um bloco individual
class _BlockWidget extends StatefulWidget {
  final BriefingBlock block;
  final bool enabled;
  final int index;
  final ValueChanged<BriefingBlock> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onToggleCheckbox;

  const _BlockWidget({
    super.key,
    required this.block,
    required this.enabled,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onToggleCheckbox,
  });

  @override
  State<_BlockWidget> createState() => _BlockWidgetState();
}

class _BlockWidgetState extends State<_BlockWidget> {
  late TextEditingController _controller;
  TextEditingController? _captionController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
    // Adiciona listener com debounce para o campo de texto principal
    _controller.addListener(_onContentChanged);

    if (widget.block.type == BlockType.image) {
      _captionController = TextEditingController(text: widget.block.caption ?? '');
      // Adiciona listener com debounce para atualizar apenas após parar de digitar
      _captionController!.addListener(_onCaptionChanged);
    }
  }

  void _onContentChanged() {
    // Cancela o timer anterior se existir
    _debounceTimer?.cancel();
    // Cria um novo timer que só executa após 500ms sem digitação
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onChanged(widget.block.copyWith(content: _controller.text));
      }
    });
  }

  void _onCaptionChanged() {
    // Cancela o timer anterior se existir
    _debounceTimer?.cancel();
    // Cria um novo timer que só executa após 500ms sem digitação
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_captionController != null && mounted) {
        widget.onChanged(widget.block.copyWith(caption: _captionController!.text));
      }
    });
  }

  @override
  void didUpdateWidget(_BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza o controller de conteúdo apenas se o texto mudou externamente
    if (oldWidget.block.content != widget.block.content &&
        _controller.text != widget.block.content) {
      _controller.text = widget.block.content;
    }
    // Atualiza o controller de legenda apenas se o texto mudou externamente
    if (widget.block.type == BlockType.image &&
        oldWidget.block.caption != widget.block.caption &&
        _captionController != null &&
        _captionController!.text != widget.block.caption) {
      _captionController!.text = widget.block.caption ?? '';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _captionController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conteúdo do bloco
          Expanded(
            child: _buildBlockContent(),
          ),

          // Botão remover
          if (widget.enabled)
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
      case BlockType.text:
        return _buildTextBlock();
      case BlockType.checkbox:
        return _buildCheckboxBlock();
      case BlockType.image:
        return _buildImageBlock();
      case BlockType.table:
        return _buildTableBlock();
    }
  }

  Widget _buildTextBlock() {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: null,
      style: const TextStyle(color: Color(0xFFEAEAEA), fontSize: 14, height: 1.5),
      decoration: const InputDecoration(
        hintText: 'Digite o texto...',
        hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        isDense: true,
      ),
      // onChanged removido - atualização via listener com debounce
    );
  }

  Widget _buildCheckboxBlock() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Checkbox sempre clicável
        GestureDetector(
          onTap: widget.onToggleCheckbox,
          child: Container(
            margin: const EdgeInsets.only(left: 12, right: 12),
            padding: const EdgeInsets.all(2),
            child: Icon(
              widget.block.checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: widget.block.checked ? const Color(0xFF7AB6FF) : const Color(0xFF9AA0A6),
            ),
          ),
        ),
        // Texto
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            maxLines: null,
            style: TextStyle(
              color: const Color(0xFFEAEAEA),
              fontSize: 14,
              height: 1.5,
              decoration: widget.block.checked ? TextDecoration.lineThrough : TextDecoration.none,
              decorationColor: const Color(0xFF9AA0A6),
            ),
            decoration: const InputDecoration(
              hintText: 'Digite o item...',
              hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              isDense: true,
            ),
            // onChanged removido - atualização via listener com debounce
          ),
        ),
      ],
    );
  }

  Widget _buildImageBlock() {
    final url = widget.block.content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Imagem
        Container(
          margin: const EdgeInsets.only(left: 12, right: 16),
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url.startsWith('file://')
                ? Image.file(
                    File(url.substring(7)),
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Erro ao carregar imagem',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Campo de texto para legenda ao lado
        Expanded(
          child: SizedBox(
            height: 300,
            child: TextField(
              controller: _captionController!,
              enabled: widget.enabled,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                color: Color(0xFFEAEAEA),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Adicione uma legenda...',
                hintStyle: TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                isDense: true,
              ),
              // onChanged removido - atualização via listener com debounce
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableBlock() {
    final tableData = widget.block.tableData ?? [];
    if (tableData.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botões à esquerda (Adicionar)
          if (widget.enabled)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TableActionButton(
                    icon: Icons.add_box_outlined,
                    tooltip: 'Adicionar linha',
                    color: const Color(0xFF7AB6FF),
                    onPressed: () {
                      final newTableData = tableData.map((r) => List<String>.from(r)).toList();
                      final newRow = List.generate(tableData[0].length, (_) => '');
                      newTableData.add(newRow);
                      widget.onChanged(widget.block.copyWith(tableData: newTableData));
                    },
                  ),
                  const SizedBox(height: 4),
                  _TableActionButton(
                    icon: Icons.view_column_outlined,
                    tooltip: 'Adicionar coluna',
                    color: const Color(0xFFFFA726),
                    onPressed: () {
                      final newTableData = tableData.map((r) {
                        final newRow = List<String>.from(r);
                        newRow.add('');
                        return newRow;
                      }).toList();
                      widget.onChanged(widget.block.copyWith(tableData: newTableData));
                    },
                  ),
                ],
              ),
            ),

          // Tabela customizada com bordas retas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: tableData.asMap().entries.map((rowEntry) {
                  final rowIndex = rowEntry.key;
                  final row = rowEntry.value;
                  final isLastRow = rowIndex == tableData.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: row.asMap().entries.map((cellEntry) {
                        final colIndex = cellEntry.key;
                        final cellValue = cellEntry.value;
                        final isLastCol = colIndex == row.length - 1;

                        return Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.zero,
                              border: Border(
                                right: isLastCol
                                    ? BorderSide.none
                                    : const BorderSide(color: Color(0xFF2A2A2A), width: 1),
                                bottom: isLastRow
                                    ? BorderSide.none
                                    : const BorderSide(color: Color(0xFF2A2A2A), width: 1),
                              ),
                            ),
                            child: SizedBox.expand(
                              child: _TableCellField(
                                initialValue: cellValue,
                                enabled: widget.enabled,
                                onChanged: (value) {
                                  final newTableData = tableData.map((r) => List<String>.from(r)).toList();
                                  newTableData[rowIndex][colIndex] = value;
                                  widget.onChanged(widget.block.copyWith(tableData: newTableData));
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

          // Botões à direita (Remover)
          if (widget.enabled)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TableActionButton(
                    icon: Icons.remove_circle_outline,
                    tooltip: 'Remover linha',
                    color: const Color(0xFFFF6B6B),
                    onPressed: tableData.length > 1 ? () {
                      final newTableData = tableData.map((r) => List<String>.from(r)).toList();
                      newTableData.removeLast();
                      widget.onChanged(widget.block.copyWith(tableData: newTableData));
                    } : null,
                  ),
                  const SizedBox(height: 4),
                  _TableActionButton(
                    icon: Icons.view_column_outlined,
                    tooltip: 'Remover coluna',
                    color: const Color(0xFFFF6B6B),
                    onPressed: tableData[0].length > 1 ? () {
                      final newTableData = tableData.map((r) {
                        final newRow = List<String>.from(r);
                        newRow.removeLast();
                        return newRow;
                      }).toList();
                      widget.onChanged(widget.block.copyWith(tableData: newTableData));
                    } : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Botão de ação da tabela (adicionar/remover linha/coluna)
class _TableActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _TableActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  State<_TableActionButton> createState() => _TableActionButtonState();
}

class _TableActionButtonState extends State<_TableActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered && isEnabled
                  ? Color.lerp(widget.color, Colors.transparent, 0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isEnabled
                    ? (_isHovered ? widget.color : Color.lerp(widget.color, Colors.transparent, 0.5)!)
                    : const Color(0xFF3D3D3D),
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: isEnabled
                  ? widget.color
                  : const Color(0xFF3D3D3D),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget para célula de tabela com controller persistente
class _TableCellField extends StatefulWidget {
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _TableCellField({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_TableCellField> createState() => _TableCellFieldState();
}

class _TableCellFieldState extends State<_TableCellField> {
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
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_TableCellField oldWidget) {
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
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: null,
      minLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        color: Color(0xFFEAEAEA),
        fontSize: 13,
        height: 1.5,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        isDense: true,
      ),
    );
  }
}
