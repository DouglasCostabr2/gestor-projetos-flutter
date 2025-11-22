import 'package:flutter/material.dart';
import '../../../../services/design_materials_repository.dart';

/// Página de gerenciamento de tags de arquivos da organização
///
/// Permite criar, editar e excluir tags que podem ser usadas
/// para organizar arquivos em Design Materials e outros módulos
class FileTagsPage extends StatefulWidget {
  const FileTagsPage({super.key});

  @override
  State<FileTagsPage> createState() => _FileTagsPageState();
}

class _FileTagsPageState extends State<FileTagsPage> {
  final DesignMaterialsRepository _repository = DesignMaterialsRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final tags = await _repository.getTags();
      if (mounted) {
        setState(() => _tags = tags);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar tags: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createTag() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _TagDialog(),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);

    try {
      await _repository.createTag(
        name: result['name'] as String,
        color: result['color'] as String,
      );

      await _loadTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar tag: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editTag(Map<String, dynamic> tag) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TagDialog(
        initialName: tag['name'] as String,
        initialColor: tag['color'] as String,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _loading = true);

    try {
      await _repository.updateTag(
        tagId: tag['id'] as String,
        name: result['name'] as String,
        color: result['color'] as String,
      );

      await _loadTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar tag: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Tag'),
        content: Text(
          'Tem certeza que deseja excluir a tag "${tag['name']}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await _repository.deleteTag(tag['id'] as String);
      await _loadTags();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir tag: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 64,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma tag cadastrada',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie tags para organizar seus arquivos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    final color = _parseColor(tag['color'] as String?);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.label,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          tag['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Cor: ${tag['color']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Editar',
                              onPressed: () => _editTag(tag),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              tooltip: 'Excluir',
                              color: Colors.red.shade300,
                              onPressed: () => _deleteTag(tag),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTag,
        icon: const Icon(Icons.add),
        label: const Text('Nova Tag'),
        backgroundColor: const Color(0xFF2196F3),
      ),
    );
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return Colors.blue;
    }
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

/// Dialog para criar/editar tag
class _TagDialog extends StatefulWidget {
  final String? initialName;
  final String? initialColor;

  const _TagDialog({
    this.initialName,
    this.initialColor,
  });

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final TextEditingController _nameController;
  String _selectedColor = '#2196F3';

  final List<String> _availableColors = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#F44336', // Red
    '#9C27B0', // Purple
    '#00BCD4', // Cyan
    '#FFEB3B', // Yellow
    '#795548', // Brown
    '#607D8B', // Blue Grey
    '#E91E63', // Pink
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedColor = widget.initialColor ?? '#2196F3';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialName != null;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Tag' : 'Nova Tag'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da Tag',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cor',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = color),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
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
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Digite um nome para a tag')),
              );
              return;
            }

            Navigator.of(context).pop({
              'name': name,
              'color': _selectedColor,
            });
          },
          child: Text(isEdit ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

