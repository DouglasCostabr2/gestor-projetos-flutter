import 'package:flutter/material.dart';
import 'tag_chip.dart';

/// Widget for displaying folders in a tree/list structure
class FolderTreeView extends StatelessWidget {
  final List<Map<String, dynamic>> folders;
  final String? selectedFolderId;
  final Function(String? folderId) onFolderSelected;
  final Function(Map<String, dynamic> folder)? onFolderRename;
  final Function(Map<String, dynamic> folder)? onFolderDelete;
  final Function(Map<String, dynamic> folder)? onAddSubfolder;

  const FolderTreeView({
    super.key,
    required this.folders,
    this.selectedFolderId,
    required this.onFolderSelected,
    this.onFolderRename,
    this.onFolderDelete,
    this.onAddSubfolder,
  });

  List<Map<String, dynamic>> _getRootFolders() {
    return folders.where((f) => f['parent_folder_id'] == null).toList();
  }

  List<Map<String, dynamic>> _getSubfolders(String parentId) {
    return folders.where((f) => f['parent_folder_id'] == parentId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rootFolders = _getRootFolders();

    return ListView(
      children: [
        // "All Files" option
        _buildFolderTile(
          context: context,
          folder: null,
          isSelected: selectedFolderId == null,
          level: 0,
        ),
        const Divider(height: 1),
        // Root folders
        ...rootFolders.map((folder) => _buildFolderWithChildren(context, folder, 0)),
      ],
    );
  }

  Widget _buildFolderWithChildren(BuildContext context, Map<String, dynamic> folder, int level) {
    final folderId = folder['id'] as String;
    final subfolders = _getSubfolders(folderId);
    final hasChildren = subfolders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFolderTile(
          context: context,
          folder: folder,
          isSelected: selectedFolderId == folderId,
          level: level,
          hasChildren: hasChildren,
        ),
        // Render children recursively
        if (hasChildren)
          ...subfolders.map((subfolder) => _buildFolderWithChildren(context, subfolder, level + 1)),
      ],
    );
  }

  Widget _buildFolderTile({
    required BuildContext context,
    required Map<String, dynamic>? folder,
    required bool isSelected,
    required int level,
    bool hasChildren = false,
  }) {
    final isAllFiles = folder == null;
    final folderName = isAllFiles ? 'Todos os Arquivos' : (folder['name'] as String);
    final folderTags = isAllFiles ? <Map<String, dynamic>>[] : _extractTags(folder);

    return Material(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => onFolderSelected(isAllFiles ? null : folder['id'] as String),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + (level * 24.0),
            right: 8,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              Icon(
                isAllFiles ? Icons.folder_open : (hasChildren ? Icons.folder : Icons.folder_outlined),
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (folderTags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: folderTags.map((tag) {
                          return TagChip(
                            label: tag['name'] as String,
                            color: tag['color'] as String?,
                            selected: false,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isAllFiles) ...[
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onFolderRename?.call(folder);
                        break;
                      case 'add_subfolder':
                        onAddSubfolder?.call(folder);
                        break;
                      case 'delete':
                        onFolderDelete?.call(folder);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Renomear'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_subfolder',
                      child: Row(
                        children: [
                          Icon(Icons.create_new_folder, size: 18),
                          SizedBox(width: 8),
                          Text('Nova Subpasta'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractTags(Map<String, dynamic> folder) {
    final folderTags = folder['folder_tags'] as List<dynamic>?;
    if (folderTags == null || folderTags.isEmpty) return [];

    return folderTags
        .map((ft) {
          final tag = ft['tag'];
          if (tag is Map<String, dynamic>) {
            return tag;
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}

