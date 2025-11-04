import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'chat_briefing.dart';
import '../../atoms/buttons/buttons.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';

/// Widget de campo de texto com barra de ferramentas na parte inferior
///
/// Exibe um editor rico (Quill) com botões de ação na parte inferior,
/// similar ao estilo de aplicativos de mensagens.
///
/// Suporta inserir imagens diretamente dentro do texto.
///
/// Uso:
/// ```dart
/// TextFieldWithToolbar(
///   controller: _quillController,
///   labelText: 'Descrição',
///   enabled: !_saving,
///   onImageAdded: (path) {
///     // Caminho da imagem adicionada
///   },
/// )
/// ```
class TextFieldWithToolbar extends StatefulWidget {
  final quill.QuillController controller;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final void Function(String path)? onImageAdded;
  final void Function(String src)? onImageRemoved;

  const TextFieldWithToolbar({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.onImageAdded,
    this.onImageRemoved,
  });

  @override
  State<TextFieldWithToolbar> createState() => _TextFieldWithToolbarState();
}

class _TextFieldWithToolbarState extends State<TextFieldWithToolbar> {
  bool _showEmojiPicker = false;
  List<Map<String, dynamic>> _allUsers = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(res);
          _loadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar usuários: $e');
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<String> _writeTempImage(Uint8List bytes, String ext, {String? originalName}) async {
    final dir = await Directory.systemTemp.createTemp('description_');
    String filename;
    if (originalName != null && originalName.isNotEmpty) {
      filename = originalName;
      if (!filename.toLowerCase().endsWith('.$ext')) {
        filename = '$filename.$ext';
      }
    } else {
      filename = 'image_${DateTime.now().millisecondsSinceEpoch}.$ext';
    }
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _insertImages() async {
    if (!widget.enabled) return;

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (res == null || !mounted) return;

    for (final f in res.files.where((f) => f.bytes != null)) {
      final bytes = f.bytes!;
      final extFromName = f.extension ?? '';
      final ext = extFromName.isNotEmpty
          ? extFromName
          : ((mime.lookupMimeType(f.name) ?? 'image/png').split('/').last);
      final tmpPath = await _writeTempImage(bytes, ext, originalName: f.name);

      final index = widget.controller.selection.baseOffset < 0
          ? widget.controller.document.length
          : widget.controller.selection.baseOffset;

      widget.controller.replaceText(
        index,
        0,
        quill.BlockEmbed.image(tmpPath),
        TextSelection.collapsed(offset: index + 1),
      );

      widget.onImageAdded?.call(tmpPath);
    }

    if (mounted) setState(() {});
  }

  void _removeImage(String src) {
    widget.onImageRemoved?.call(src);
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _insertEmoji(Emoji emoji) {
    final index = widget.controller.selection.baseOffset < 0
        ? widget.controller.document.length
        : widget.controller.selection.baseOffset;

    widget.controller.replaceText(
      index,
      0,
      emoji.emoji,
      TextSelection.collapsed(offset: index + emoji.emoji.length),
    );
  }

  void _toggleFormat(quill.Attribute attribute) {
    final selection = widget.controller.selection;
    if (selection.baseOffset < 0) return;

    // Verificar se a formatação já está aplicada
    final currentStyle = widget.controller.getSelectionStyle();
    final isActive = currentStyle.attributes.containsKey(attribute.key);

    if (isActive) {
      // Se já está ativo, remover a formatação
      widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      // Se não está ativo, aplicar a formatação
      widget.controller.formatSelection(attribute);
    }
  }





  void _showAddMenu(BuildContext context) async {
    if (!widget.enabled) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    final buttonY = position.dy;
    final fieldX = position.dx - renderBox.size.width;

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: fieldX,
            bottom: overlay.size.height - buttonY + 8,
            child: Material(
              color: Colors.transparent,
              child: _AddMenu(
                onInsertChecklist: () {
                  Navigator.of(context).pop();
                  _insertChecklist();
                },
                onInsertSectionBreak: () {
                  Navigator.of(context).pop();
                  _insertSectionBreak();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertChecklist() {
    final selection = widget.controller.selection;
    final index = selection.baseOffset;

    // Inserir uma linha de checklist (lista não marcada)
    widget.controller.formatText(index, 0, quill.Attribute.unchecked);
  }

  void _insertSectionBreak() {
    final selection = widget.controller.selection;
    final index = selection.baseOffset;

    // Salvar o texto atual para reconstruir sem propagação de formatação
    final currentText = widget.controller.document.toPlainText();

    // Dividir o texto na posição do cursor
    final beforeCursor = currentText.substring(0, index);
    final afterCursor = currentText.substring(index);

    // Construir o novo texto com a quebra de seção
    const dividerText = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    final newText = '$beforeCursor\n$dividerText\n$afterCursor';

    // Substituir todo o conteúdo
    final docLength = widget.controller.document.length;
    widget.controller.replaceText(0, docLength - 1, newText, null);

    // Aplicar cor branca com 30% de transparência APENAS na linha divisória
    final dividerStart = beforeCursor.length + 1; // +1 para pular o \n
    widget.controller.formatText(
      dividerStart,
      dividerText.length,
      quill.Attribute.fromKeyValue(
        'color',
        '#4DFFFFFF', // Branco com 30% de opacidade
      ),
    );

    // Posicionar cursor após a quebra de seção
    final newPosition = dividerStart + dividerText.length + 1; // +1 para pular o \n após o divider
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: newPosition),
      quill.ChangeSource.local,
    );
  }

  void _showFormattingMenu(BuildContext context) async {
    if (!widget.enabled) return;

    // Obter a posição do campo de texto
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    // Calcular posição: acima do botão, alinhado à esquerda do campo
    final buttonY = position.dy;
    final fieldX = position.dx - renderBox.size.width; // Voltar para o início do campo

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Barreira invisível para fechar ao clicar fora
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu de formatação posicionado
          Positioned(
            left: fieldX,
            bottom: overlay.size.height - buttonY + 8, // 8px acima do botão
            child: Material(
              color: Colors.transparent,
              child: _FormattingToolbar(
                onFormat: (attribute) {
                  _toggleFormat(attribute);
                  Navigator.of(context).pop();
                },
                onInsertLink: () {
                  Navigator.of(context).pop();
                  _showLinkDialog(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLinkDialog(BuildContext context) async {
    final urlController = TextEditingController();
    final textController = TextEditingController();

    // Pegar texto selecionado, se houver
    final selection = widget.controller.selection;
    if (selection.baseOffset >= 0 && selection.extentOffset > selection.baseOffset) {
      final selectedText = widget.controller.document
          .toPlainText()
          .substring(selection.baseOffset, selection.extentOffset);
      textController.text = selectedText;
    }

    final result = await DialogHelper.show<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inserir Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Texto do link',
                hintText: 'Digite o texto que será exibido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://exemplo.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'text': textController.text.isEmpty ? urlController.text : textController.text,
                  'url': urlController.text,
                });
              }
            },
            child: const Text('Inserir'),
          ),
        ],
      ),
    );

    if (result != null) {
      final index = widget.controller.selection.baseOffset < 0
          ? widget.controller.document.length
          : widget.controller.selection.baseOffset;

      final length = widget.controller.selection.extentOffset - widget.controller.selection.baseOffset;

      // Se há texto selecionado, substituir; senão, inserir
      if (length > 0) {
        widget.controller.replaceText(
          index,
          length,
          result['text']!,
          TextSelection.collapsed(offset: index),
        );
      } else {
        widget.controller.replaceText(
          index,
          0,
          result['text']!,
          TextSelection.collapsed(offset: index),
        );
      }

      // Aplicar o link ao texto inserido
      widget.controller.formatText(
        index,
        result['text']!.length,
        quill.LinkAttribute(result['url']!),
      );
    }

    urlController.dispose();
    textController.dispose();
  }

  Future<void> _showMentionPicker() async {
    if (!widget.enabled || _loadingUsers) return;

    final selected = await DialogHelper.show<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MentionPickerDialog(users: _allUsers),
    );

    if (selected != null && mounted) {
      final name = selected['full_name'] as String? ?? 'Usuário';
      final mention = '@$name ';

      final index = widget.controller.selection.baseOffset < 0
          ? widget.controller.document.length
          : widget.controller.selection.baseOffset;

      widget.controller.replaceText(
        index,
        0,
        mention,
        TextSelection.collapsed(offset: index + mention.length),
      );
    }
  }

  ImageProvider? _quillImageProvider(BuildContext context, String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('file://')) {
      final path = Uri.parse(src).toFilePath();
      return FileImage(File(path));
    }
    if (File(src).existsSync()) {
      return FileImage(File(src));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label (se fornecido)
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Container com borda arredondada
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Editor Quill
              Container(
                constraints: const BoxConstraints(minHeight: 150),
                padding: const EdgeInsets.all(8),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: quill.QuillEditor.basic(
                    controller: widget.controller,
                    config: quill.QuillEditorConfig(
                      placeholder: widget.hintText ?? '',
                      customStyles: chatDefaultStyles(context),
                      embedBuilders: [
                        ChatImageEmbedBuilder(
                          imageProviderBuilder: (src) => _quillImageProvider(context, src),
                          onRemove: (_, src) => _removeImage(src),
                          onDownload: (_, src) {},
                        ),
                        ...FlutterQuillEmbeds.editorBuilders(
                          imageEmbedConfig: QuillEditorImageEmbedConfig(
                            onImageClicked: (_) {},
                            imageProviderBuilder: _quillImageProvider,
                          ),
                        ).where((b) => b.key != 'image'),
                      ],
                    ),
                  ),
                ),
              ),

              // Barra de ferramentas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Botão adicionar (+) - Checklist e Quebra de Seção
                    Builder(
                      builder: (btnContext) => IconOnlyButton(
                        icon: Icons.add_circle_outline,
                        iconSize: 20,
                        iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        onPressed: widget.enabled ? () {
                          _showAddMenu(btnContext);
                        } : null,
                        tooltip: 'Adicionar',
                        padding: const EdgeInsets.all(8),
                      ),
                    ),

                    // Botão texto/formatação
                    Builder(
                      builder: (btnContext) => IconOnlyButton(
                        icon: Icons.text_fields,
                        iconSize: 20,
                        iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        onPressed: widget.enabled ? () => _showFormattingMenu(btnContext) : null,
                        tooltip: 'Formatação de texto',
                        padding: const EdgeInsets.all(8),
                      ),
                    ),

                    // Botão emoji
                    IconOnlyButton(
                      icon: _showEmojiPicker ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
                      iconSize: 20,
                      iconColor: _showEmojiPicker
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      onPressed: widget.enabled ? _toggleEmojiPicker : null,
                      tooltip: 'Emoji',
                      padding: const EdgeInsets.all(8),
                    ),

                    // Botão @menção
                    IconOnlyButton(
                      icon: Icons.alternate_email,
                      iconSize: 20,
                      iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      onPressed: widget.enabled ? _showMentionPicker : null,
                      tooltip: 'Mencionar usuário',
                      padding: const EdgeInsets.all(8),
                    ),

                    // Botão clipe/anexo de imagem
                    IconOnlyButton(
                      icon: Icons.attach_file,
                      iconSize: 20,
                      iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      onPressed: widget.enabled ? _insertImages : null,
                      tooltip: 'Inserir imagem',
                      padding: const EdgeInsets.all(8),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Emoji Picker
        if (_showEmojiPicker) ...[
          const SizedBox(height: 8),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _insertEmoji(emoji);
              },
              config: Config(
                height: 250,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: theme.colorScheme.surface,
                  columns: 7,
                  buttonMode: ButtonMode.MATERIAL,
                ),
                skinToneConfig: SkinToneConfig(
                  enabled: true,
                  dialogBackgroundColor: theme.colorScheme.surface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                  iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  iconColorSelected: theme.colorScheme.primary,
                  indicatorColor: theme.colorScheme.primary,
                  backspaceColor: theme.colorScheme.primary,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  buttonColor: theme.colorScheme.surfaceContainerHighest,
                  buttonIconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                  buttonIconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Toolbar de formatação de texto
class _FormattingToolbar extends StatelessWidget {
  final void Function(quill.Attribute) onFormat;
  final VoidCallback onInsertLink;

  const _FormattingToolbar({
    required this.onFormat,
    required this.onInsertLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.8);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.start,
          children: [
          // Negrito (B)
          IconOnlyButton(
            icon: Icons.format_bold,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.bold),
            tooltip: 'Negrito',
            padding: const EdgeInsets.all(8),
          ),

          // Itálico (I)
          IconOnlyButton(
            icon: Icons.format_italic,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.italic),
            tooltip: 'Itálico',
            padding: const EdgeInsets.all(8),
          ),

          // Sublinhado (U)
          IconOnlyButton(
            icon: Icons.format_underline,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.underline),
            tooltip: 'Sublinhado',
            padding: const EdgeInsets.all(8),
          ),

          // Tachado (S)
          IconOnlyButton(
            icon: Icons.format_strikethrough,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.strikeThrough),
            tooltip: 'Tachado',
            padding: const EdgeInsets.all(8),
          ),

          // Lista com marcadores
          IconOnlyButton(
            icon: Icons.format_list_bulleted,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.ul),
            tooltip: 'Lista com marcadores',
            padding: const EdgeInsets.all(8),
          ),

          // Lista numerada
          IconOnlyButton(
            icon: Icons.format_list_numbered,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.ol),
            tooltip: 'Lista numerada',
            padding: const EdgeInsets.all(8),
          ),

          // Citação
          IconOnlyButton(
            icon: Icons.format_quote,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: () => onFormat(quill.Attribute.blockQuote),
            tooltip: 'Citação',
            padding: const EdgeInsets.all(8),
          ),

          // Link
          IconOnlyButton(
            icon: Icons.link,
            iconSize: 20,
            iconColor: iconColor,
            onPressed: onInsertLink,
            tooltip: 'Inserir link',
            padding: const EdgeInsets.all(8),
          ),


        ],
      ),
      ),
    );
  }
}

/// Diálogo para selecionar um usuário para mencionar
class _MentionPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> users;

  const _MentionPickerDialog({required this.users});

  @override
  State<_MentionPickerDialog> createState() => _MentionPickerDialogState();
}

class _MentionPickerDialogState extends State<_MentionPickerDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.users;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredUsers = widget.users.where((user) {
          final name = (user['full_name'] as String? ?? '').toLowerCase();
          final email = (user['email'] as String? ?? '').toLowerCase();
          return name.contains(lowerQuery) || email.contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Icon(Icons.alternate_email, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mencionar usuário',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                IconOnlyButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fechar',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _filterUsers,
            ),
            const SizedBox(height: 16),

            // Lista de usuários
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum usuário encontrado',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final name = user['full_name'] as String? ?? 'Usuário';
                        final email = user['email'] as String? ?? '';
                        final avatarUrl = user['avatar_url'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                                : null,
                          ),
                          title: Text(name),
                          subtitle: email.isNotEmpty ? Text(email) : null,
                          onTap: () => Navigator.of(context).pop(user),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu de adicionar (Checklist e Quebra de Seção)
class _AddMenu extends StatelessWidget {
  final VoidCallback onInsertChecklist;
  final VoidCallback onInsertSectionBreak;

  const _AddMenu({
    required this.onInsertChecklist,
    required this.onInsertSectionBreak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checklist
            ListTile(
              dense: true,
              leading: Icon(
                Icons.check_box_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              title: Text(
                'Checklist',
                style: theme.textTheme.bodyMedium,
              ),
              onTap: onInsertChecklist,
            ),

            // Quebra de Seção
            ListTile(
              dense: true,
              leading: Icon(
                Icons.horizontal_rule,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              title: Text(
                'Quebra de Seção',
                style: theme.textTheme.bodyMedium,
              ),
              onTap: onInsertSectionBreak,
            ),
          ],
        ),
      ),
    );
  }
}

