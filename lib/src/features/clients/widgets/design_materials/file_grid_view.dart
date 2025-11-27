import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../ui/atoms/badges/simple_badge.dart';
import '../../../../../ui/atoms/image_viewer/image_viewer.dart';

/// Widget for displaying files in a grid layout
class FileGridView extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final Function(Map<String, dynamic> file)? onFileRename;
  final Function(Map<String, dynamic> file)? onFileDelete;
  final Function(Map<String, dynamic> file)? onFileDownload;
  final Function(Map<String, dynamic> file)? onManageTags;

  const FileGridView({
    super.key,
    required this.files,
    this.onFileRename,
    this.onFileDelete,
    this.onFileDownload,
    this.onManageTags,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum arquivo nesta pasta',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileCard(
          file: file,
          onRename: onFileRename != null ? () => onFileRename!(file) : null,
          onDelete: onFileDelete != null ? () => onFileDelete!(file) : null,
          onDownload:
              onFileDownload != null ? () => onFileDownload!(file) : null,
          onManageTags: onManageTags != null ? () => onManageTags!(file) : null,
        );
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final VoidCallback? onManageTags;

  const _FileCard({
    required this.file,
    this.onRename,
    this.onDelete,
    this.onDownload,
    this.onManageTags,
  });

  bool _isImage(String? mimeType) {
    if (mimeType == null) {
      return false;
    }
    return mimeType.startsWith('image/');
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) {
      return Icons.insert_drive_file;
    }

    if (mimeType.startsWith('image/')) {
      return Icons.image;
    }
    if (mimeType.startsWith('video/')) {
      return Icons.video_file;
    }
    if (mimeType.startsWith('audio/')) {
      return Icons.audio_file;
    }
    if (mimeType.contains('pdf')) {
      return Icons.picture_as_pdf;
    }
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow;
    }
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        mimeType.contains('7z')) {
      return Icons.folder_zip;
    }

    return Icons.insert_drive_file;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  List<Map<String, dynamic>> _extractTags() {
    final fileTags = file['file_tags'] as List<dynamic>?;
    if (fileTags == null || fileTags.isEmpty) {
      return [];
    }

    return fileTags
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

  Future<void> _openFile() async {
    final url = file['drive_file_url'] as String?;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = file['filename'] as String? ?? 'Sem nome';
    final mimeType = file['mime_type'] as String?;
    final driveFileId = file['drive_file_id'] as String?;
    final fileSize = file['file_size_bytes'] as int?;
    final isImage = _isImage(mimeType);
    final isVideo = mimeType?.startsWith('video/') ?? false;
    final tags = _extractTags();

    // Gerar URL de thumbnail do Google Drive (mesmo sistema usado em assets)
    final thumbnailUrl = driveFileId != null && (isImage || isVideo)
        ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w800'
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openFile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail/Icon with overlays
            Expanded(
              child: Stack(
                children: [
                  // Background image or icon
                  Positioned.fill(
                    child: Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: (isImage || isVideo) && thumbnailUrl != null
                          ? GestureDetector(
                              onTap: isImage
                                  ? () => ImageViewer.show(
                                        context,
                                        imageUrl: thumbnailUrl,
                                        downloadFileName: filename,
                                      )
                                  : null,
                              child: MouseRegion(
                                cursor: isImage
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        _getFileIcon(mimeType),
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                _getFileIcon(mimeType),
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                    ),
                  ),

                  // Tags in top-left corner
                  if (tags.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: tags.take(3).map((tag) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SimpleBadge(
                              label: tag['name'] as String,
                              backgroundColor:
                                  const Color(0x80000000), // Black 50% opacity
                              textColor: const Color(0xFFE0E0E0), // Light grey
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Menu button in top-right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0x80000000), // Black 50% opacity
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          size: 16,
                          color: Color(0xFFE0E0E0), // Light grey
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            onRename?.call();
                            break;
                          case 'download':
                            onDownload?.call();
                            break;
                          case 'tags':
                            onManageTags?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Renomear'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download, size: 16),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'tags',
                          child: Row(
                            children: [
                              Icon(Icons.label, size: 16),
                              SizedBox(width: 8),
                              Text('Gerenciar Tags'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16),
                              SizedBox(width: 8),
                              Text('Excluir'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // File info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (fileSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(fileSize),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
