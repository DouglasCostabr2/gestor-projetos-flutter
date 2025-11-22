import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'tag_chip.dart';

/// Dialog for renaming a folder or file
class RenameDialog extends StatefulWidget {
  final String currentName;
  final String title;

  const RenameDialog({
    super.key,
    required this.currentName,
    this.title = 'Renomear',
  });

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Digite o novo nome',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nome não pode estar vazio';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}

/// Dialog for creating a new folder
class CreateFolderDialog extends StatefulWidget {
  final String? parentFolderName;

  const CreateFolderDialog({
    super.key,
    this.parentFolderName,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.parentFolderName != null
          ? 'Nova Subpasta em "${widget.parentFolderName}"'
          : 'Nova Pasta'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da Pasta',
                  hintText: 'Ex: Logos, Fotos, Paleta de Cores',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome não pode estar vazio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Descreva o conteúdo desta pasta',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Criar'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      });
    }
  }
}

/// Dialog for uploading files
class UploadFilesDialog extends StatefulWidget {
  final String? folderName;

  const UploadFilesDialog({
    super.key,
    this.folderName,
  });

  @override
  State<UploadFilesDialog> createState() => _UploadFilesDialogState();
}

class _UploadFilesDialogState extends State<UploadFilesDialog> {
  List<PlatformFile> _selectedFiles = [];
  final Map<int, String> _renamedFiles = {}; // Mapa de índice -> novo nome
  bool _isSelecting = false;

  Future<void> _pickFiles() async {
    setState(() => _isSelecting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files.where((f) => f.bytes != null).toList();
        });
      }
    } finally {
      setState(() => _isSelecting = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _renamedFiles.remove(index);
      // Reajustar índices dos arquivos renomeados
      final newRenamed = <int, String>{};
      _renamedFiles.forEach((key, value) {
        if (key > index) {
          newRenamed[key - 1] = value;
        } else {
          newRenamed[key] = value;
        }
      });
      _renamedFiles.clear();
      _renamedFiles.addAll(newRenamed);
    });
  }

  Future<void> _renameFile(int index) async {
    final file = _selectedFiles[index];
    final currentName = _renamedFiles[index] ?? file.name;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameFileDialog(currentName: currentName),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      setState(() {
        _renamedFiles[index] = newName;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _isImage(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext);
  }

  bool _isVideo(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm'].contains(ext);
  }

  String? _getFileExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filename.length - 1) return null;
    return filename.substring(lastDot + 1);
  }

  List<PlatformFile> _getFilesWithRenames() {
    // Retorna lista de arquivos com nomes atualizados
    return _selectedFiles.asMap().entries.map((entry) {
      final index = entry.key;
      final file = entry.value;
      final newName = _renamedFiles[index];

      if (newName != null) {
        // Garantir que a extensão está presente
        String finalName = newName;
        final originalExt = file.extension;
        final newExt = _getFileExtension(newName);

        // Se o novo nome não tem extensão, adicionar a original
        if (newExt == null && originalExt != null) {
          finalName = '$newName.$originalExt';
        }

        // Criar novo PlatformFile com nome atualizado
        return PlatformFile(
          name: finalName,
          size: file.size,
          bytes: file.bytes,
          path: file.path,
          readStream: file.readStream,
        );
      }
      return file;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.folderName != null
          ? 'Upload para "${widget.folderName}"'
          : 'Upload de Arquivos'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _isSelecting ? null : _pickFiles,
              icon: const Icon(Icons.upload_file),
              label: Text(_isSelecting ? 'Selecionando...' : 'Selecionar Arquivos'),
            ),
            const SizedBox(height: 16),
            if (_selectedFiles.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum arquivo selecionado',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFiles.length} arquivo(s) selecionado(s)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          final displayName = _renamedFiles[index] ?? file.name;

                          // SEMPRE usar a extensão do arquivo ORIGINAL para detectar tipo
                          // (não do nome renomeado, pois pode estar sem extensão)
                          final isImage = _isImage(file.extension);
                          final isVideo = _isVideo(file.extension);

                          // Widget de thumbnail/ícone
                          Widget leadingWidget;
                          if (isImage && file.bytes != null) {
                            // Miniatura 30x30 para imagens
                            leadingWidget = ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.memory(
                                file.bytes!,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image, size: 30);
                                },
                              ),
                            );
                          } else if (isVideo) {
                            leadingWidget = const Icon(Icons.video_file, size: 30);
                          } else {
                            leadingWidget = const Icon(Icons.insert_drive_file, size: 30);
                          }

                          return ListTile(
                            leading: SizedBox(
                              width: 30,
                              height: 30,
                              child: leadingWidget,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Mostrar extensão se foi renomeado sem extensão
                                if (_renamedFiles.containsKey(index) &&
                                    _getFileExtension(displayName) == null &&
                                    file.extension != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      '.${file.extension}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(_formatFileSize(file.size)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botão de renomear
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Renomear',
                                  onPressed: () => _renameFile(index),
                                ),
                                // Botão de remover
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  tooltip: 'Remover',
                                  onPressed: () => _removeFile(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedFiles.isEmpty ? null : () => Navigator.of(context).pop(_getFilesWithRenames()),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}

/// Dialog simples para renomear arquivo
class _RenameFileDialog extends StatefulWidget {
  final String currentName;

  const _RenameFileDialog({required this.currentName});

  @override
  State<_RenameFileDialog> createState() => _RenameFileDialogState();
}

class _RenameFileDialogState extends State<_RenameFileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear Arquivo'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome do arquivo',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            Navigator.of(context).pop(value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty) {
              Navigator.of(context).pop(newName);
            }
          },
          child: const Text('Renomear'),
        ),
      ],
    );
  }
}

/// Dialog for managing tags on a file or folder
class ManageTagsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableTags;
  final List<String> currentTagIds;
  final String itemName;
  final bool isFolder;

  const ManageTagsDialog({
    super.key,
    required this.availableTags,
    required this.currentTagIds,
    required this.itemName,
    this.isFolder = false,
  });

  @override
  State<ManageTagsDialog> createState() => _ManageTagsDialogState();
}

class _ManageTagsDialogState extends State<ManageTagsDialog> {
  late List<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List.from(widget.currentTagIds);
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tags - ${widget.itemName}'),
      content: SizedBox(
        width: 400,
        child: widget.availableTags.isEmpty
            ? const Center(
                child: Text('Nenhuma tag disponível. Crie tags primeiro.'),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableTags.map((tag) {
                  final tagId = tag['id'] as String;
                  final tagName = tag['name'] as String;
                  final tagColor = tag['color'] as String?;
                  final isSelected = _selectedTagIds.contains(tagId);

                  return TagChip(
                    label: tagName,
                    color: tagColor,
                    selected: isSelected,
                    onTap: () => _toggleTag(tagId),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedTagIds),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

