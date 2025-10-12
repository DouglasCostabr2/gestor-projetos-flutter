import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gestor_projetos_flutter/src/platform/windows_thumbnail.dart';
import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';

/// Reusable Task Assets Section Widget
/// 
/// Manages task assets (images, files, videos) with tabbed interface.
/// Supports:
/// - Multiple file types (images, files, videos)
/// - Windows PSD thumbnails
/// - Drag & drop (via parent)
/// - File removal
/// 
/// Usage:
/// ```dart
/// TaskAssetsSection(
///   assetsImages: _assetsImages,
///   assetsFiles: _assetsFiles,
///   assetsVideos: _assetsVideos,
///   onAssetsChanged: (images, files, videos) {
///     setState(() {
///       _assetsImages = images;
///       _assetsFiles = files;
///       _assetsVideos = videos;
///     });
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskAssetsSection extends StatefulWidget {
  final List<PlatformFile> assetsImages;
  final List<PlatformFile> assetsFiles;
  final List<PlatformFile> assetsVideos;
  final void Function(List<PlatformFile> images, List<PlatformFile> files, List<PlatformFile> videos) onAssetsChanged;
  final bool enabled;
  final String? taskId; // Para carregar assets existentes

  const TaskAssetsSection({
    super.key,
    required this.assetsImages,
    required this.assetsFiles,
    required this.assetsVideos,
    required this.onAssetsChanged,
    this.enabled = true,
    this.taskId,
  });

  @override
  State<TaskAssetsSection> createState() => _TaskAssetsSectionState();
}

class _TaskAssetsSectionState extends State<TaskAssetsSection> {
  final Map<String, Uint8List> _fileThumbs = {};
  List<Map<String, dynamic>> _existingAssets = [];

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _loadExistingAssets();
    }
  }

  Future<void> _loadExistingAssets() async {
    if (widget.taskId == null) {
      debugPrint('TaskAssetsSection: No taskId provided, skipping load');
      return;
    }

    debugPrint('TaskAssetsSection: Loading existing assets for task ${widget.taskId}');

    try {
      final client = Supabase.instance.client;

      debugPrint('TaskAssetsSection: Querying task_files table...');
      final rows = await client
          .from('task_files')
          .select('id, filename, mime_type, drive_file_id, drive_file_url, category')
          .eq('task_id', widget.taskId!)
          .or('category.is.null,category.eq.assets')
          .order('created_at', ascending: true);

      debugPrint('TaskAssetsSection: Query returned ${(rows as List).length} rows');
      debugPrint('TaskAssetsSection: Rows: $rows');

      if (!mounted) return;

      setState(() {
        _existingAssets = List<Map<String, dynamic>>.from(rows);
      });

      debugPrint('TaskAssetsSection: Loaded ${_existingAssets.length} existing assets');
    } catch (e) {
      debugPrint('TaskAssetsSection: Error loading existing assets: $e');
    }
  }

  Future<void> _confirmDeleteExistingAsset(Map<String, dynamic> asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Remover Asset',
        message: 'Deseja remover "${asset['filename']}"?\n\nO arquivo será excluído do Google Drive.',
        confirmText: 'Remover',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await _deleteExistingAsset(asset);
    }
  }

  Future<void> _deleteExistingAsset(Map<String, dynamic> asset) async {
    try {
      final client = Supabase.instance.client;
      final assetId = asset['id'] as String;

      // Delete from database
      await client.from('task_files').delete().eq('id', assetId);

      // Remove from local list
      if (mounted) {
        setState(() {
          _existingAssets.removeWhere((a) => a['id'] == assetId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asset removido com sucesso')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting existing asset: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover asset: $e')),
        );
      }
    }
  }

  Future<void> _pickAssets() async {
    if (!widget.enabled) return;
    
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (res == null || !mounted) return;

    final newImages = List<PlatformFile>.from(widget.assetsImages);
    final newFiles = List<PlatformFile>.from(widget.assetsFiles);
    final newVideos = List<PlatformFile>.from(widget.assetsVideos);

    for (final f in res.files) {
      final name = f.name.toLowerCase();
      final ext = f.extension?.toLowerCase() ?? '';
      final mt = mime.lookupMimeType(f.name) ?? '';

      // Classify file
      const rasterExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico'];
      const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];

      if (rasterExts.contains(ext) || (mt.startsWith('image/') && !name.endsWith('.psd'))) {
        newImages.add(f);
      } else if (videoExts.contains(ext) || mt.startsWith('video/')) {
        newVideos.add(f);
      } else {
        newFiles.add(f);
      }
    }

    widget.onAssetsChanged(newImages, newFiles, newVideos);
  }

  Widget _buildFileAvatar(PlatformFile f) {
    final path = f.path;
    if (Platform.isWindows && path != null && path.toLowerCase().endsWith('.psd')) {
      final thumb = _fileThumbs[path];
      if (thumb != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 32,
            height: 32,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.memory(thumb),
            ),
          ),
        );
      }
    }
    return const Icon(Icons.insert_drive_file);
  }

  Widget _buildAssetsTab(
    List<PlatformFile> files,
    String emptyMessage,
    Widget Function(MapEntry<int, PlatformFile>) contentBuilder,
    void Function(int) onRemove,
    String fileType, // 'image', 'file', 'video'
  ) {
    // Resolve Windows thumbnails for PSD files (best effort)
    if (Platform.isWindows) {
      for (final e in files) {
        final path = e.path;
        if (path != null && path.toLowerCase().endsWith('.psd') && !_fileThumbs.containsKey(path)) {
          // ignore: discarded_futures
          getWindowsThumbnailPng(path, size: 200).then((png) {
            if (png != null && mounted) {
              setState(() => _fileThumbs[path] = png);
            }
          });
        }
      }
    }

    // Filter existing assets by type
    debugPrint('TaskAssetsSection: Filtering ${_existingAssets.length} existing assets for type: $fileType');
    final existingOfType = _existingAssets.where((asset) {
      final type = asset['mime_type'] as String?;
      debugPrint('  - Asset: ${asset['filename']}, type: $type');
      if (fileType == 'image') {
        return type?.startsWith('image/') ?? false;
      } else if (fileType == 'video') {
        return type?.startsWith('video/') ?? false;
      } else {
        return !(type?.startsWith('image/') ?? false) && !(type?.startsWith('video/') ?? false);
      }
    }).toList();
    debugPrint('TaskAssetsSection: Found ${existingOfType.length} assets of type $fileType');

    if (files.isEmpty && existingOfType.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: [
            // Existing assets (from database)
            ...existingOfType.map((asset) => _buildExistingAssetTile(asset)),

            // New assets (from file picker)
            ...files.asMap().entries.map((e) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: contentBuilder(e),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: widget.enabled ? () => onRemove(e.key) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  width: 120,
                  child: Text(
                    e.value.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingAssetTile(Map<String, dynamic> asset) {
    final fileName = asset['filename'] as String? ?? 'Sem nome';
    final mimeType = asset['mime_type'] as String? ?? '';
    final driveFileId = asset['drive_file_id'] as String?;

    // Generate Google Drive thumbnail URL
    // Format: https://drive.google.com/thumbnail?id=FILE_ID&sz=w200
    final thumbnailUrl = driveFileId != null
        ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w200'
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mimeType.startsWith('image/') && thumbnailUrl != null
                  ? Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      mimeType.startsWith('video/') ? Icons.video_file : Icons.insert_drive_file,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
          ),
          // Remove button
          if (widget.enabled)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _confirmDeleteExistingAsset(asset),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAssets = widget.assetsImages.isNotEmpty ||
                      widget.assetsFiles.isNotEmpty ||
                      widget.assetsVideos.isNotEmpty ||
                      _existingAssets.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Assets',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),

        // Add button
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.enabled ? _pickAssets : null,
            icon: const Icon(Icons.attach_file),
            label: const Text('Adicionar assets'),
          ),
        ),
        const SizedBox(height: 8),

        // Tabs (only if has assets)
        if (hasAssets) ...[
          DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) {
                // Count existing assets by type
                final existingImages = _existingAssets.where((a) => (a['mime_type'] as String?)?.startsWith('image/') ?? false).length;
                final existingVideos = _existingAssets.where((a) => (a['mime_type'] as String?)?.startsWith('video/') ?? false).length;
                final existingFiles = _existingAssets.where((a) {
                  final type = a['mime_type'] as String?;
                  return !(type?.startsWith('image/') ?? false) && !(type?.startsWith('video/') ?? false);
                }).length;

                final totalImages = widget.assetsImages.length + existingImages;
                final totalFiles = widget.assetsFiles.length + existingFiles;
                final totalVideos = widget.assetsVideos.length + existingVideos;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(
                          icon: Badge(
                            label: Text('$totalImages', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: totalImages > 0,
                            child: const Icon(Icons.image),
                          ),
                        ),
                        Tab(
                          icon: Badge(
                            label: Text('$totalFiles', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: totalFiles > 0,
                            child: const Icon(Icons.insert_drive_file),
                          ),
                        ),
                        Tab(
                          icon: Badge(
                            label: Text('$totalVideos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: totalVideos > 0,
                            child: const Icon(Icons.videocam),
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: TabBarView(
                    children: [
                      // Images tab
                      _buildAssetsTab(
                        widget.assetsImages,
                        'Nenhuma imagem adicionada',
                        (e) => e.value.bytes != null
                            ? Image.memory(e.value.bytes!, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 48),
                        (idx) {
                          final newImages = List<PlatformFile>.from(widget.assetsImages)..removeAt(idx);
                          widget.onAssetsChanged(newImages, widget.assetsFiles, widget.assetsVideos);
                        },
                        'image',
                      ),
                      // Files tab
                      _buildAssetsTab(
                        widget.assetsFiles,
                        'Nenhum arquivo adicionado',
                        (e) => Center(child: _buildFileAvatar(e.value)),
                        (idx) {
                          final newFiles = List<PlatformFile>.from(widget.assetsFiles)..removeAt(idx);
                          widget.onAssetsChanged(widget.assetsImages, newFiles, widget.assetsVideos);
                        },
                        'file',
                      ),
                      // Videos tab
                      _buildAssetsTab(
                        widget.assetsVideos,
                        'Nenhum vídeo adicionado',
                        (e) => const Center(child: Icon(Icons.videocam, size: 48)),
                        (idx) {
                          final newVideos = List<PlatformFile>.from(widget.assetsVideos)..removeAt(idx);
                          widget.onAssetsChanged(widget.assetsImages, widget.assetsFiles, newVideos);
                        },
                        'video',
                      ),
                    ],
                  ),
                ),
              ],
            );
              },
            ),
          ),
        ],
      ],
    );
  }
}

