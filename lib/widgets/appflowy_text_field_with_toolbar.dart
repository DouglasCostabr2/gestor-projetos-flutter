import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
import '../services/google_drive_oauth_service.dart';

/// Função helper para fazer upload de imagens em cache para o Google Drive
/// Recebe o JSON do briefing e retorna o JSON atualizado com URLs do Drive
Future<String> uploadBriefingCachedImages({
  required String briefingJson,
  required String clientName,
  required String projectName,
  required String taskTitle,
}) async {
  debugPrint('🔄 uploadBriefingCachedImages - INICIANDO');
  debugPrint('📁 Cliente: $clientName, Projeto: $projectName, Tarefa: $taskTitle');

  try {
    final doc = jsonDecode(briefingJson) as Map<String, dynamic>;

    // Percorrer todos os nós do documento
    final docMap = doc['document'] as Map?;
    if (docMap == null) {
      debugPrint('⚠️ docMap é null');
      return briefingJson;
    }

    final nodes = docMap['children'] as List?;
    if (nodes == null) {
      debugPrint('⚠️ nodes é null');
      return briefingJson;
    }

    debugPrint('📋 Total de nós no documento: ${nodes.length}');

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      debugPrint('🔍 Nó $i: tipo = ${node is Map ? node['type'] : 'não é Map'}');

      if (node is Map && node['type'] == 'image') {
        debugPrint('🖼️ Encontrou nó de imagem!');

        // AppFlowy Editor armazena dados em 'data', não em 'attributes'
        final data = node['data'] as Map?;
        debugPrint('📦 Data: $data');

        if (data != null) {
          final url = data['url'] as String?;
          debugPrint('🔗 URL da imagem: $url');

          // Verificar se é uma URL local (cache)
          if (url != null && url.startsWith('file://')) {
            debugPrint('💾 É uma URL local! Iniciando upload...');
            try {
              final localPath = url.substring(7); // Remove 'file://'
              final file = File(localPath);

              debugPrint('📂 Caminho local: $localPath');
              debugPrint('✓ Arquivo existe: ${await file.exists()}');

              if (await file.exists()) {
                // Fazer upload para o Google Drive
                debugPrint('🚀 Iniciando upload para Google Drive...');
                final driveService = GoogleDriveOAuthService();
                final driveClient = await driveService.getAuthedClient();

                final fileName = path.basename(localPath);
                final bytes = await file.readAsBytes();
                final extension = path.extension(localPath).substring(1); // Remove o '.'

                debugPrint('📤 Fazendo upload: $fileName (${bytes.length} bytes)');

                final uploadedFile = await driveService.uploadToTaskSubfolder(
                  client: driveClient,
                  clientName: clientName,
                  projectName: projectName,
                  taskName: taskTitle,
                  subfolderName: 'Briefing',
                  filename: fileName,
                  bytes: bytes,
                  mimeType: 'image/$extension',
                );

                // Atualizar URL no documento
                data['url'] = uploadedFile.publicViewUrl ?? url;

                debugPrint('✅ Imagem do briefing enviada para Google Drive: ${uploadedFile.publicViewUrl}');

                // Deletar arquivo do cache
                try {
                  await file.delete();
                  debugPrint('🗑️ Arquivo de cache deletado');
                } catch (e) {
                  debugPrint('⚠️ Erro ao deletar arquivo de cache: $e');
                }
              }
            } catch (e) {
              debugPrint('❌ Erro ao fazer upload da imagem do briefing: $e');
              debugPrint('Stack trace: ${StackTrace.current}');
              // Manter URL local em caso de erro
            }
          } else {
            debugPrint('🌐 URL não é local (já está no Drive ou é remota)');
          }
        } else {
          debugPrint('⚠️ Data é null!');
        }
      }
    }

    debugPrint('✅ uploadBriefingCachedImages - CONCLUÍDO');
    return jsonEncode(doc);
  } catch (e) {
    debugPrint('❌ Erro ao processar JSON do briefing: $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    return briefingJson;
  }
}

/// Widget de campo de texto rico usando AppFlowy Editor
/// Similar ao Asana com drag and drop, checklists, formatação, etc.
class AppFlowyTextFieldWithToolbar extends StatefulWidget {
  final String? hintText;
  final bool enabled;
  final String? initialText;
  final String? initialJson; // JSON do documento (para carregar do banco)
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onJsonChanged; // Callback com JSON do documento

  // Informações para upload no Google Drive (opcionais)
  final String? taskId;
  final String? taskTitle;
  final String? projectName;
  final String? clientName;

  const AppFlowyTextFieldWithToolbar({
    super.key,
    this.hintText,
    this.enabled = true,
    this.initialText,
    this.initialJson,
    this.onChanged,
    this.onJsonChanged,
    this.taskId,
    this.taskTitle,
    this.projectName,
    this.clientName,
  });

  @override
  State<AppFlowyTextFieldWithToolbar> createState() =>
      _AppFlowyTextFieldWithToolbarState();
}

class _AppFlowyTextFieldWithToolbarState
    extends State<AppFlowyTextFieldWithToolbar> {
  late EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  void _initializeEditor() {
    // Criar estado do editor
    if (widget.initialJson != null && widget.initialJson!.isNotEmpty) {
      // Carregar de JSON (do banco de dados)
      try {
        final json = jsonDecode(widget.initialJson!);
        final document = Document.fromJson(json);
        _editorState = EditorState(document: document);
      } catch (e) {
        // Se falhar, criar editor vazio
        _editorState = EditorState.blank(withInitialText: true);
      }
    } else if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      // Carregar de texto plano
      _editorState = EditorState.blank(withInitialText: false);
      final transaction = _editorState.transaction;
      final lines = widget.initialText!.split('\n');
      for (var i = 0; i < lines.length; i++) {
        transaction.insertNode(
          [i],
          paragraphNode(text: lines[i]),
        );
      }
      _editorState.apply(transaction);
    } else {
      // Editor vazio
      _editorState = EditorState.blank(withInitialText: true);
    }

    // Listener para mudanças
    _editorState.transactionStream.listen((_) {
      _onDocumentChange();
    });
  }

  void _onDocumentChange() {
    // Notificar mudanças em texto plano
    if (widget.onChanged != null) {
      final buffer = StringBuffer();
      for (var node in _editorState.document.root.children) {
        if (node.delta != null) {
          buffer.writeln(node.delta!.toPlainText());
        }
      }
      widget.onChanged!(buffer.toString().trim());
    }

    // Notificar mudanças em JSON
    if (widget.onJsonChanged != null) {
      final json = jsonEncode(_editorState.document.toJson());
      widget.onJsonChanged!(json);
    }
  }

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editor
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AppFlowyEditor(
                editorState: _editorState,
                editable: widget.enabled,
                showMagnifier: true,
                editorStyle: EditorStyle.desktop(
                  padding: const EdgeInsets.all(16),
                  cursorColor: theme.colorScheme.primary,
                  selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                  defaultTextDirection: 'ltr',
                  textStyleConfiguration: TextStyleConfiguration(
                    text: theme.textTheme.bodyMedium!.copyWith(
                      color: Colors.white,
                    ),
                    bold: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    italic: theme.textTheme.bodyMedium!.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
                    underline: theme.textTheme.bodyMedium!.copyWith(
                      decoration: TextDecoration.underline,
                      color: Colors.white,
                    ),
                    strikethrough: theme.textTheme.bodyMedium!.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.white,
                    ),
                    href: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    code: theme.textTheme.bodyMedium!.copyWith(
                      fontFamily: 'monospace',
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: Colors.white,
                    ),
                  ),
                ),
                characterShortcutEvents: standardCharacterShortcutEvents,
                commandShortcutEvents: standardCommandShortcutEvents,
                blockComponentBuilders: {
                  ...standardBlockComponentBuilderMap,
                  ImageBlockKeys.type: CustomImageBlockBuilder(),
                  TodoListBlockKeys.type: CustomTodoListBlockBuilder(),
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Toolbar completa
        _buildToolbar(theme),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Botão Mover para Cima
            _buildToolbarButton(
              icon: Icons.arrow_upward,
              tooltip: 'Mover para Cima',
              onPressed: _moveBlockUp,
              theme: theme,
            ),
            // Botão Mover para Baixo
            _buildToolbarButton(
              icon: Icons.arrow_downward,
              tooltip: 'Mover para Baixo',
              onPressed: _moveBlockDown,
              theme: theme,
            ),
            const SizedBox(width: 8),
            // Botão Adicionar (Menu)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.add_circle_outline,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              tooltip: 'Adicionar',
              enabled: widget.enabled,
              padding: const EdgeInsets.all(8),
              onSelected: (value) {
                if (value == 'checklist') {
                  _insertChecklist();
                } else if (value == 'divider') {
                  _insertDivider();
                } else if (value == 'bullet_list') {
                  _insertBulletList();
                } else if (value == 'numbered_list') {
                  _insertNumberedList();
                } else if (value == 'quote') {
                  _insertQuote();
                } else if (value == 'image') {
                  _insertImage();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'checklist',
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outlined, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Checklist'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'bullet_list',
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Lista com Marcadores'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'numbered_list',
                  child: Row(
                    children: [
                      Icon(Icons.format_list_numbered, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Lista Numerada'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'quote',
                  child: Row(
                    children: [
                      Icon(Icons.format_quote, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Citação'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.image, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Imagem'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'divider',
                  child: Row(
                    children: [
                      Icon(Icons.horizontal_rule, size: 18, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      const Text('Quebra de Seção'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Separador
            Container(width: 1, height: 24, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            // Cabeçalhos
            PopupMenuButton<String>(
              icon: Icon(
                Icons.title,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              tooltip: 'Cabeçalho',
              enabled: widget.enabled,
              padding: const EdgeInsets.all(8),
              onSelected: (value) {
                if (value == 'h1') {
                  _insertHeading(1);
                } else if (value == 'h2') {
                  _insertHeading(2);
                } else if (value == 'h3') {
                  _insertHeading(3);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'h1',
                  child: Text('Cabeçalho 1', style: theme.textTheme.titleLarge),
                ),
                PopupMenuItem(
                  value: 'h2',
                  child: Text('Cabeçalho 2', style: theme.textTheme.titleMedium),
                ),
                PopupMenuItem(
                  value: 'h3',
                  child: Text('Cabeçalho 3', style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Separador
            Container(width: 1, height: 24, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            // Botão Negrito (Ctrl+B)
            _buildToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Negrito (Ctrl+B)',
              onPressed: _toggleBold,
              theme: theme,
            ),
            // Botão Itálico (Ctrl+I)
            _buildToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Itálico (Ctrl+I)',
              onPressed: _toggleItalic,
              theme: theme,
            ),
            // Botão Sublinhado (Ctrl+U)
            _buildToolbarButton(
              icon: Icons.format_underlined,
              tooltip: 'Sublinhado (Ctrl+U)',
              onPressed: _toggleUnderline,
              theme: theme,
            ),
            // Botão Tachado (Ctrl+Shift+S)
            _buildToolbarButton(
              icon: Icons.strikethrough_s,
              tooltip: 'Tachado (Ctrl+Shift+S)',
              onPressed: _toggleStrikethrough,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return IconOnlyButton(
      icon: icon,
      iconSize: 20,
      iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      onPressed: widget.enabled ? onPressed : null,
      tooltip: tooltip,
      padding: const EdgeInsets.all(8),
    );
  }

  // Ações de formatação
  void _toggleBold() {
    _editorState.toggleAttribute(AppFlowyRichTextKeys.bold);
  }

  void _toggleItalic() {
    _editorState.toggleAttribute(AppFlowyRichTextKeys.italic);
  }

  void _toggleUnderline() {
    _editorState.toggleAttribute(AppFlowyRichTextKeys.underline);
  }

  void _toggleStrikethrough() {
    _editorState.toggleAttribute(AppFlowyRichTextKeys.strikethrough);
  }

  // Inserir checklist
  void _insertChecklist() {
    final selection = _editorState.selection;
    if (selection == null) {
      // Se não há seleção, inserir no final
      final transaction = _editorState.transaction;
      final lastPath = [_editorState.document.root.children.length];
      transaction.insertNode(
        lastPath,
        todoListNode(checked: false, text: ''),
      );
      _editorState.apply(transaction);
      return;
    }

    // Inserir após o nó atual
    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = _editorState.transaction;
    final path = selection.end.path.next;
    transaction.insertNode(
      path,
      todoListNode(checked: false, text: ''),
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: path),
    );
    _editorState.apply(transaction);
  }

  // Inserir lista com marcadores
  void _insertBulletList() {
    final selection = _editorState.selection;
    if (selection == null) {
      final transaction = _editorState.transaction;
      final lastPath = [_editorState.document.root.children.length];
      transaction.insertNode(
        lastPath,
        bulletedListNode(text: ''),
      );
      _editorState.apply(transaction);
      return;
    }

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = _editorState.transaction;
    final path = selection.end.path.next;
    transaction.insertNode(
      path,
      bulletedListNode(text: ''),
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: path),
    );
    _editorState.apply(transaction);
  }

  // Inserir lista numerada
  void _insertNumberedList() {
    final selection = _editorState.selection;
    if (selection == null) {
      final transaction = _editorState.transaction;
      final lastPath = [_editorState.document.root.children.length];
      transaction.insertNode(
        lastPath,
        numberedListNode(delta: Delta()..insert('')),
      );
      _editorState.apply(transaction);
      return;
    }

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = _editorState.transaction;
    final path = selection.end.path.next;
    transaction.insertNode(
      path,
      numberedListNode(delta: Delta()..insert('')),
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: path),
    );
    _editorState.apply(transaction);
  }

  // Inserir citação
  void _insertQuote() {
    final selection = _editorState.selection;
    if (selection == null) {
      final transaction = _editorState.transaction;
      final lastPath = [_editorState.document.root.children.length];
      transaction.insertNode(
        lastPath,
        quoteNode(delta: Delta()..insert('')),
      );
      _editorState.apply(transaction);
      return;
    }

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = _editorState.transaction;
    final path = selection.end.path.next;
    transaction.insertNode(
      path,
      quoteNode(delta: Delta()..insert('')),
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: path),
    );
    _editorState.apply(transaction);
  }

  // Inserir cabeçalho
  void _insertHeading(int level) {
    final selection = _editorState.selection;
    if (selection == null) {
      final transaction = _editorState.transaction;
      final lastPath = [_editorState.document.root.children.length];
      transaction.insertNode(
        lastPath,
        headingNode(level: level, text: ''),
      );
      _editorState.apply(transaction);
      return;
    }

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = _editorState.transaction;
    final path = selection.end.path.next;
    transaction.insertNode(
      path,
      headingNode(level: level, text: ''),
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: path),
    );
    _editorState.apply(transaction);
  }

  // Inserir divisor
  void _insertDivider() {
    final selection = _editorState.selection;
    final transaction = _editorState.transaction;

    if (selection == null) {
      // Sem seleção: inserir no final
      final dividerPath = [_editorState.document.root.children.length];
      final paragraphPath = [_editorState.document.root.children.length + 1];

      transaction.insertNode(dividerPath, dividerNode());
      transaction.insertNode(paragraphPath, paragraphNode(text: ''));
      transaction.afterSelection = Selection.collapsed(
        Position(path: paragraphPath),
      );
      _editorState.apply(transaction);
      return;
    }

    // Com seleção: inserir após o nó atual
    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final dividerPath = selection.end.path.next;
    final paragraphPath = dividerPath.next;

    transaction.insertNode(dividerPath, dividerNode());
    transaction.insertNode(paragraphPath, paragraphNode(text: ''));
    transaction.afterSelection = Selection.collapsed(
      Position(path: paragraphPath),
    );
    _editorState.apply(transaction);
  }

  // Mover bloco para cima
  void _moveBlockUp() {
    final selection = _editorState.selection;
    if (selection == null) return;

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final path = selection.end.path;
    if (path.first == 0) return; // Já está no topo

    final transaction = _editorState.transaction;
    final newPath = [path.first - 1];

    // Copiar o nó
    final nodeCopy = node.copyWith();

    // Deletar o nó original
    transaction.deleteNode(node);

    // Inserir na nova posição
    transaction.insertNode(newPath, nodeCopy);

    transaction.afterSelection = Selection.collapsed(
      Position(path: newPath),
    );
    _editorState.apply(transaction);
  }

  // Mover bloco para baixo
  void _moveBlockDown() {
    final selection = _editorState.selection;
    if (selection == null) return;

    final node = _editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final path = selection.end.path;
    final maxIndex = _editorState.document.root.children.length - 1;
    if (path.first >= maxIndex) return; // Já está no final

    final transaction = _editorState.transaction;
    final newPath = [path.first + 2]; // +2 porque move para depois do próximo

    // Copiar o nó
    final nodeCopy = node.copyWith();

    // Deletar o nó original
    transaction.deleteNode(node);

    // Inserir na nova posição
    transaction.insertNode(newPath, nodeCopy);

    transaction.afterSelection = Selection.collapsed(
      Position(path: [newPath.first - 1]),
    );
    _editorState.apply(transaction);
  }

  // Inserir imagem (salva em cache local, upload será feito ao salvar o formulário)
  Future<void> _insertImage() async {
    try {
      // Selecionar imagem do dispositivo
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

      // Inserir imagem no editor
      final selection = _editorState.selection;
      final transaction = _editorState.transaction;

      if (selection == null) {
        // Sem seleção: inserir no final
        final imagePath = [_editorState.document.root.children.length];
        final paragraphPath = [_editorState.document.root.children.length + 1];

        transaction.insertNode(
          imagePath,
          imageNode(url: imageUrl),
        );
        transaction.insertNode(paragraphPath, paragraphNode(text: ''));
        transaction.afterSelection = Selection.collapsed(
          Position(path: paragraphPath),
        );
        _editorState.apply(transaction);
        return;
      }

      // Com seleção: inserir após o nó atual
      final node = _editorState.getNodeAtPath(selection.end.path);
      if (node == null) return;

      final imagePath = selection.end.path.next;
      final paragraphPath = imagePath.next;

      transaction.insertNode(
        imagePath,
        imageNode(url: imageUrl),
      );
      transaction.insertNode(paragraphPath, paragraphNode(text: ''));
      transaction.afterSelection = Selection.collapsed(
        Position(path: paragraphPath),
      );
      _editorState.apply(transaction);
    } catch (e) {
      // Fechar loading se estiver aberto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Mostrar erro
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer upload da imagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Converter documento para JSON (para salvar no banco)
  String toJson() {
    return jsonEncode(_editorState.document.toJson());
  }

  // Fazer upload das imagens em cache para o Google Drive e atualizar URLs
  Future<String> uploadCachedImagesAndGetJson() async {
    // Verificar se temos as informações necessárias
    if (widget.clientName == null || widget.projectName == null || widget.taskTitle == null) {
      debugPrint('⚠️ Informações da tarefa não disponíveis, retornando JSON sem upload');
      return toJson();
    }

    final doc = _editorState.document.toJson();

    // Percorrer todos os nós do documento
    final docMap = doc['document'] as Map?;
    if (docMap == null) return toJson();

    final nodes = docMap['children'] as List?;
    if (nodes == null) return toJson();

    for (var node in nodes) {
      if (node is Map && node['type'] == 'image') {
        final attributes = node['attributes'] as Map?;
        if (attributes != null) {
          final url = attributes['url'] as String?;

          // Verificar se é uma URL local (cache)
          if (url != null && url.startsWith('file://')) {
            try {
              final localPath = url.substring(7); // Remove 'file://'
              final file = File(localPath);

              if (await file.exists()) {
                // Fazer upload para o Google Drive
                final driveService = GoogleDriveOAuthService();
                final driveClient = await driveService.getAuthedClient();

                final fileName = path.basename(localPath);
                final bytes = await file.readAsBytes();
                final extension = path.extension(localPath).substring(1); // Remove o '.'

                final uploadedFile = await driveService.uploadToTaskSubfolder(
                  client: driveClient,
                  clientName: widget.clientName!,
                  projectName: widget.projectName!,
                  taskName: widget.taskTitle!,
                  subfolderName: 'Briefing',
                  filename: fileName,
                  bytes: bytes,
                  mimeType: 'image/$extension',
                );

                // Atualizar URL no documento
                attributes['url'] = uploadedFile.publicViewUrl ?? url;

                debugPrint('✅ Imagem enviada para Google Drive: ${uploadedFile.publicViewUrl}');

                // Deletar arquivo do cache
                try {
                  await file.delete();
                } catch (e) {
                  debugPrint('⚠️ Erro ao deletar arquivo de cache: $e');
                }
              }
            } catch (e) {
              debugPrint('⚠️ Erro ao fazer upload da imagem: $e');
              // Manter URL local em caso de erro
            }
          }
        }
      }
    }

    return jsonEncode(doc);
  }
}

/// Builder customizado para todo_list que permite toggle mesmo em modo read-only
class CustomTodoListBlockBuilder extends TodoListBlockComponentBuilder {
  CustomTodoListBlockBuilder()
      : super(
          configuration: BlockComponentConfiguration(
            padding: (_) => const EdgeInsets.symmetric(vertical: 4),
          ),
        );

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    debugPrint('🔨 CustomTodoListBlockBuilder.build - node: ${node.id}');

    // Retornar widget customizado que permite clicar em read-only
    return _ClickableTodoListBlockWidget(
      key: blockComponentContext.node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
    );
  }
}

/// Widget customizado que permite clicar no checkbox mesmo em modo read-only
class _ClickableTodoListBlockWidget extends TodoListBlockComponentWidget {
  const _ClickableTodoListBlockWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<TodoListBlockComponentWidget> createState() => _ClickableTodoListBlockWidgetState();
}

class _ClickableTodoListBlockWidgetState extends State<_ClickableTodoListBlockWidget> {
  EditorState? get editorState {
    try {
      final appFlowyState = context.findAncestorStateOfType<_AppFlowyTextFieldWithToolbarState>();
      return appFlowyState?._editorState;
    } catch (e) {
      debugPrint('❌ Erro ao obter EditorState: $e');
      return null;
    }
  }

  bool get isReadOnly {
    final state = editorState;
    if (state == null) return true;
    final editable = state.editable;
    debugPrint('📝 isReadOnly check - editable: $editable');
    return !editable;
  }

  bool get isChecked => widget.node.attributes[TodoListBlockKeys.checked] as bool? ?? false;

  @override
  Widget build(BuildContext context) {
    debugPrint('🔨 _ClickableTodoListBlockWidget.build - isReadOnly: $isReadOnly, isChecked: $isChecked');

    final delta = widget.node.delta;
    if (delta == null) {
      return const SizedBox.shrink();
    }

    // Construir o widget do checkbox e texto
    final checkboxWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox
        GestureDetector(
          onTap: isReadOnly ? () {
            debugPrint('🖱️ Checkbox clicado em modo read-only!');
            _toggleCheckbox();
          } : null,
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 2),
            child: Icon(
              isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: isChecked ? Colors.blue : Colors.white70,
            ),
          ),
        ),
        // Texto
        Expanded(
          child: Text(
            delta.toPlainText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: widget.configuration.padding(widget.node),
      child: checkboxWidget,
    );
  }

  void _toggleCheckbox() {
    final state = editorState;
    if (state == null) {
      debugPrint('❌ EditorState é null');
      return;
    }

    debugPrint('🔄 Toggling checkbox: $isChecked -> ${!isChecked}');
    final transaction = state.transaction;
    transaction.updateNode(widget.node, {
      TodoListBlockKeys.checked: !isChecked,
    });
    state.apply(transaction);
    debugPrint('✅ Checkbox toggled! Forçando rebuild...');

    // Forçar rebuild
    if (mounted) {
      setState(() {});
    }
  }
}

/// Builder customizado para imagens com altura máxima de 400px
class CustomImageBlockBuilder extends BlockComponentBuilder {
  CustomImageBlockBuilder()
      : super(
          configuration: BlockComponentConfiguration(
            padding: (_) => const EdgeInsets.symmetric(vertical: 8),
          ),
        );

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;

    return _CustomImageBlockWidget(
      key: blockComponentContext.node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(blockComponentContext, state),
    );
  }
}

/// Widget customizado para exibir imagens com altura máxima
class _CustomImageBlockWidget extends BlockComponentStatefulWidget {
  const _CustomImageBlockWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<_CustomImageBlockWidget> createState() => _CustomImageBlockWidgetState();
}

class _ContentLine {
  String text;
  bool isCheckbox;
  bool isChecked;
  TextEditingController controller;

  _ContentLine({
    required this.text,
    this.isCheckbox = false,
    this.isChecked = false,
  }) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'isCheckbox': isCheckbox,
    'isChecked': isChecked,
  };

  factory _ContentLine.fromJson(Map<String, dynamic> json) => _ContentLine(
    text: json['text'] as String? ?? '',
    isCheckbox: json['isCheckbox'] as bool? ?? false,
    isChecked: json['isChecked'] as bool? ?? false,
  );
}

class _CustomImageBlockWidgetState extends State<_CustomImageBlockWidget>
    with BlockComponentConfigurable, BlockComponentBackgroundColorMixin {

  late TextEditingController _captionController;
  final List<_ContentLine> _contentLines = [];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(
      text: node.attributes['caption'] as String? ?? '',
    );

    // Carregar linhas de conteúdo do nó
    _loadContentLines();
  }

  void _loadContentLines() {
    final linesJson = node.attributes['content_lines'] as List<dynamic>?;
    if (linesJson != null) {
      _contentLines.clear();
      for (var json in linesJson) {
        if (json is Map<String, dynamic>) {
          _contentLines.add(_ContentLine.fromJson(json));
        }
      }
    }

    // Se não houver linhas, adicionar uma vazia
    if (_contentLines.isEmpty) {
      _contentLines.add(_ContentLine(text: '', isCheckbox: false));
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    for (var line in _contentLines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  // Detectar se o editor está em modo read-only
  bool _isReadOnly(BuildContext context) {
    try {
      final appFlowyState = context.findAncestorStateOfType<_AppFlowyTextFieldWithToolbarState>();
      if (appFlowyState != null) {
        return !appFlowyState._editorState.editable;
      }
      // Se não encontrar o estado do AppFlowy, assume que está em modo read-only (visualização)
      return true;
    } catch (_) {
      return true;
    }
  }

  // Construir widget de imagem (local ou remota)
  Widget _buildImage(String url) {
    // Verificar se é uma URL local (cache)
    if (url.startsWith('file://')) {
      final localPath = url.substring(7); // Remove 'file://'
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Erro ao carregar imagem local',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        },
      );
    }

    // URL remota (Google Drive)
    return Image.network(
      url,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox(
          height: 100,
          child: Center(
            child: Text(
              'Erro ao carregar imagem',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = _isReadOnly(context);
    final url = node.attributes[ImageBlockKeys.url] as String?;

    if (url == null || url.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Imagem não encontrada',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem à esquerda
          Flexible(
            flex: 1,
            child: Stack(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 400, // Altura máxima de 400px
                  ),
                  child: _buildImage(url),
                ),
                // Botão X para remover imagem
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => _removeImage(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Editor de conteúdo misto (texto + checkboxes)
          Flexible(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header com botões
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Conteúdo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Botões de adicionar (só no modo de edição)
                        if (!isReadOnly) ...[
                          // Botão adicionar texto
                          IconOnlyButton(
                            icon: Icons.text_fields,
                            iconSize: 18,
                            tooltip: 'Adicionar linha de texto',
                            iconColor: Colors.white70,
                            onPressed: () => _addContentLine(isCheckbox: false),
                            padding: const EdgeInsets.all(4),
                          ),
                          // Botão adicionar checkbox
                          IconOnlyButton(
                            icon: Icons.check_box_outline_blank,
                            iconSize: 18,
                            tooltip: 'Adicionar checkbox',
                            iconColor: Colors.white70,
                            onPressed: () => _addContentLine(isCheckbox: true),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Lista de conteúdo misto
                  Flexible(
                    child: _buildMixedContent(isReadOnly),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeImage(BuildContext context) async {
    // Capturar o EditorState antes de operações async
    final appFlowyState = context.findAncestorStateOfType<_AppFlowyTextFieldWithToolbarState>();

    // Obter URL da imagem antes de remover
    // A URL está diretamente em node.attributes[ImageBlockKeys.url]
    final url = node.attributes[ImageBlockKeys.url] as String?;

    debugPrint('🗑️ Removendo imagem do briefing...');
    debugPrint('   URL: $url');

    // Se for uma URL do Google Drive, deletar do Drive
    if (url != null && url.contains('drive.google.com')) {
      try {
        debugPrint('🔥 Deletando imagem do Google Drive...');

        // Extrair o file ID da URL
        final fileIdMatch = RegExp(r'id=([^&]+)').firstMatch(url);
        if (fileIdMatch != null) {
          final fileId = fileIdMatch.group(1);
          debugPrint('   File ID: $fileId');

          final driveService = GoogleDriveOAuthService();
          final driveClient = await driveService.getAuthedClient();

          // Deletar arquivo do Google Drive
          await driveClient.delete(
            Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
          );

          debugPrint('✅ Imagem deletada do Google Drive com sucesso!');
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao deletar imagem do Google Drive: $e');
        // Continua removendo do editor mesmo se falhar no Drive
      }
    } else if (url != null && url.startsWith('file://')) {
      // Se for uma imagem local (cache), deletar do cache
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

    // Remover do editor (usando o state capturado antes do async)
    if (appFlowyState != null) {
      try {
        final transaction = appFlowyState._editorState.transaction;
        transaction.deleteNode(node);
        appFlowyState._editorState.apply(transaction);
        debugPrint('✅ Imagem removida do editor');
      } catch (e) {
        debugPrint('❌ Erro ao remover imagem do editor: $e');
      }
    }
  }

  Widget _buildMixedContent(bool isReadOnly) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _contentLines.length,
      itemBuilder: (context, index) {
        final line = _contentLines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Checkbox (se for linha de checkbox)
              if (line.isCheckbox)
                Checkbox(
                  value: line.isChecked,
                  onChanged: (value) {
                    setState(() {
                      line.isChecked = value ?? false;
                    });
                    _saveContentLines();
                  },
                  activeColor: Colors.green,
                  checkColor: Colors.white,
                  side: const BorderSide(
                    color: Colors.white70,
                    width: 2,
                  ),
                ),
              // TextField para o texto
              Expanded(
                child: TextField(
                  controller: line.controller,
                  enabled: !isReadOnly, // Desabilitar edição no modo read-only
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: (line.isCheckbox && line.isChecked)
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  ),
                  decoration: InputDecoration(
                    hintText: line.isCheckbox ? 'Digite a tarefa...' : 'Digite o texto...',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: isReadOnly ? null : (value) {
                    line.text = value;
                    _saveContentLines();
                  },
                ),
              ),
              // Botão de remover (só no modo de edição)
              if (!isReadOnly)
                IconOnlyButton(
                  icon: Icons.close,
                  iconSize: 16,
                  tooltip: 'Remover linha',
                  iconColor: Colors.white54,
                  onPressed: () => _removeContentLine(index),
                  padding: const EdgeInsets.all(4),
                ),
            ],
          ),
        );
      },
    );
  }

  void _addContentLine({required bool isCheckbox}) {
    setState(() {
      _contentLines.add(_ContentLine(text: '', isCheckbox: isCheckbox));
    });
    _saveContentLines();
  }

  void _removeContentLine(int index) {
    setState(() {
      _contentLines[index].dispose();
      _contentLines.removeAt(index);
    });
    _saveContentLines();
  }

  void _saveContentLines() {
    // Salvar linhas de conteúdo no nó
    try {
      final appFlowyState = context.findAncestorStateOfType<_AppFlowyTextFieldWithToolbarState>();
      if (appFlowyState != null) {
        final transaction = appFlowyState._editorState.transaction;

        // Converter linhas para JSON
        final linesJson = _contentLines.map((line) => line.toJson()).toList();

        // Atualizar o atributo content_lines do nó
        transaction.updateNode(node, {
          ...node.attributes,
          'content_lines': linesJson,
        });

        appFlowyState._editorState.apply(transaction);
      }
    } catch (e) {
      debugPrint('Erro ao salvar linhas de conteúdo: $e');
    }
  }


}

