import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' as mime;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:my_business/src/platform/windows_thumbnail.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/services/google_drive_oauth_service.dart';
import 'package:my_business/ui/molecules/molecules.dart';
import 'package:my_business/ui/theme/ui_constants.dart';



/// Enum para tipos de asset
enum AssetType { image, file, video }

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
  bool _isDragging = false;

  bool _isAddHover = false;

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
      debugPrint('🗑️ [TaskAssets] Removendo asset: ${asset['filename']}');

      // 1. Remover do Google Drive
      final driveFileId = asset['drive_file_id'] as String?;
      if (driveFileId != null) {
        debugPrint('🗑️ [TaskAssets] Removendo do Google Drive: $driveFileId');
        try {
          final drive = GoogleDriveOAuthService();
          final client = await drive.getAuthedClient();
          await drive.deleteFile(
            client: client,
            driveFileId: driveFileId,
          );
          debugPrint('✅ [TaskAssets] Arquivo removido do Google Drive');
                } catch (e) {
          debugPrint('⚠️ [TaskAssets] Erro ao remover do Google Drive: $e');
          // Continua mesmo se falhar no Drive
        }
      }

      // 2. Remover do banco de dados
      final client = Supabase.instance.client;
      final assetId = asset['id'] as String;
      debugPrint('🗑️ [TaskAssets] Removendo do banco de dados: $assetId');
      await client.from('task_files').delete().eq('id', assetId);
      debugPrint('✅ [TaskAssets] Arquivo removido do banco de dados');

      // 3. Remove from local list
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
      debugPrint('❌ [TaskAssets] Erro ao remover asset: $e');
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
      final ext = f.extension?.toLowerCase() ?? '';
      final mt = mime.lookupMimeType(f.name) ?? '';

      // Classify file
      const rasterExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico'];
      const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
      const designExts = ['psd', 'ai', 'sketch', 'fig', 'xd'];

      // Arquivos de design vão para "Arquivos", não "Imagens"
      if (designExts.contains(ext)) {
        newFiles.add(f);
      } else if (rasterExts.contains(ext) || mt.startsWith('image/')) {
        newImages.add(f);
      } else if (videoExts.contains(ext) || mt.startsWith('video/')) {
        newVideos.add(f);
      } else {
        newFiles.add(f);
      }
    }

    widget.onAssetsChanged(newImages, newFiles, newVideos);
  }

  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (!widget.enabled) return;

    final List<PlatformFile> platformFiles = [];

    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final fileName = path.split(Platform.pathSeparator).last;

      platformFiles.add(PlatformFile(
        name: fileName,
        size: bytes.length,
        bytes: bytes,
        path: path,
      ));
    }

    if (platformFiles.isEmpty) return;

    // Classificar os arquivos
    final newImages = List<PlatformFile>.from(widget.assetsImages);
    final newFiles = List<PlatformFile>.from(widget.assetsFiles);
    final newVideos = List<PlatformFile>.from(widget.assetsVideos);

    final rasterExts = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};
    final videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm'};

    for (final f in platformFiles) {
      final ext = f.name.split('.').last.toLowerCase();
      final mt = mime.lookupMimeType(f.name) ?? '';

      if (rasterExts.contains(ext) || mt.startsWith('image/')) {
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
    AssetType tabType,
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

    // Helper function to check if file is an image (by mime type AND extension)
    bool isImage(Map<String, dynamic> asset) {
      final mimeType = asset['mime_type'] as String?;
      final filename = (asset['filename'] as String? ?? '').toLowerCase();

      // Excluir explicitamente arquivos PSD, AI, etc (arquivos de design)
      if (filename.endsWith('.psd') ||
          filename.endsWith('.ai') ||
          filename.endsWith('.sketch') ||
          filename.endsWith('.fig') ||
          filename.endsWith('.xd')) {
        return false;
      }

      // Verificar mime type para imagens comuns
      return mimeType?.startsWith('image/') ?? false;
    }

    // Helper function to check if file is a video
    bool isVideo(Map<String, dynamic> asset) {
      final mimeType = asset['mime_type'] as String?;
      return mimeType?.startsWith('video/') ?? false;
    }

    // Filter existing assets by type
    debugPrint('TaskAssetsSection: Filtering ${_existingAssets.length} existing assets for type: ${tabType.name}');
    final existingOfType = _existingAssets.where((asset) {
      debugPrint('  - Asset: ${asset['filename']}, type: ${asset['mime_type']}');
      if (tabType == AssetType.image) {
        return isImage(asset);
      } else if (tabType == AssetType.video) {
        return isVideo(asset);
      } else {
        return !isImage(asset) && !isVideo(asset);
      }
    }).toList();
    debugPrint('TaskAssetsSection: Found ${existingOfType.length} assets of type ${tabType.name}');

    // Label dinâmico para o botão de adicionar, conforme a aba atual
    final String addLabel = tabType == AssetType.image
        ? 'Adicionar imagens'
        : (tabType == AssetType.file
            ? 'Adicionar arquivos'
            : 'Adicionar vídeos');

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: [
            // Card de adicionar assets
            if (widget.enabled)
              InkWell(
                onTap: _pickAssets,
                onHover: (h) => setState(() => _isAddHover = h),
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final hasAnyAssets = existingOfType.isNotEmpty || files.isNotEmpty;
                    final cardWidth = hasAnyAssets ? UIConst.assetCardSize : constraints.maxWidth;

                    final borderColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: _isAddHover ? 0.8 : 0.5);
                    final overlayColor = _isAddHover
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)
                        : Colors.transparent;
                    final labelColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: _isAddHover ? 0.8 : 0.5);

                    return SizedBox(
                      height: 150,
                      width: cardWidth,
                      child: DashedContainer(
                        color: borderColor,
                        strokeWidth: UIConst.dashedStroke,
                        dashLength: UIConst.dashLengthAssets,
                        dashGap: UIConst.dashGapAssets,
                        borderRadius: UIConst.radiusSmall,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          color: overlayColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_rounded,
                                size: 32,
                                color: labelColor,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                addLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: labelColor,
                                  fontWeight: FontWeight.w500,
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

            // Existing assets (from database)
            ...existingOfType.map((asset) => _buildExistingAssetTile(asset)),

            // New assets (from file picker)
            ...files.asMap().entries.map((e) => Stack(
              children: [
                // Conteúdo principal
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: contentBuilder(e),
                ),

                // Nome do arquivo na parte inferior
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      e.value.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

                // Botão de remover
                if (widget.enabled)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onRemove(e.key),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
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

    // Generate Google Drive thumbnail URL - MAIOR RESOLUÇÃO
    final thumbnailUrl = driveFileId != null
        ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w800'
        : null;

    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');

    // Widget de conteúdo (imagem ou placeholder)
    Widget contentWidget;

    if (isImage && thumbnailUrl != null) {
      contentWidget = SizedBox(
        height: 150,
        width: 150,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              height: 150,
              width: 150,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              width: 150,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
      );
    } else {
      contentWidget = Container(
        height: 150,
        width: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          isVideo ? Icons.video_file : Icons.insert_drive_file,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return Stack(
      children: [
        // Conteúdo principal
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: contentWidget,
        ),

        // Nome do arquivo na parte inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),

        // Botão de remover
        if (widget.enabled)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _confirmDeleteExistingAsset(asset),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      child: Column(
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

        // Tabs
        DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);

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
                DropTarget(
                  onDragEntered: (details) {
                    if (widget.enabled) {
                      setState(() => _isDragging = true);
                    }
                  },
                  onDragExited: (details) {
                    setState(() => _isDragging = false);
                  },
                  onDragDone: (details) async {
                    setState(() => _isDragging = false);
                    if (!widget.enabled) return;

                    final paths = details.files.map((f) => f.path).toList();
                    await _handleDroppedFiles(paths);
                  },
                  child: Container(
                    decoration: _isDragging
                        ? BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          )
                        : null,
                    child: AnimatedBuilder(
                      animation: tabController,
                      builder: (context, child) {
                        final currentIndex = tabController.index;

                        Widget currentTab;
                        if (currentIndex == 0) {
                          // Images tab
                          currentTab = _buildAssetsTab(
                            widget.assetsImages,
                            'Nenhuma imagem adicionada',
                            (e) => e.value.bytes != null
                                ? SizedBox(
                                    height: 150,
                                    width: 150,
                                    child: Image.memory(
                                      e.value.bytes!,
                                      fit: BoxFit.cover,
                                      cacheWidth: (150 * MediaQuery.of(context).devicePixelRatio).round(),
                                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                        if (wasSynchronouslyLoaded) return child;
                                        return AnimatedOpacity(
                                          opacity: frame == null ? 0 : 1,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                          child: frame == null
                                              ? Container(
                                                  height: 150,
                                                  width: 150,
                                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  child: const Center(child: CircularProgressIndicator()),
                                                )
                                              : child,
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          width: 150,
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          child: const Center(
                                            child: Text('Erro ao carregar imagem', style: TextStyle(color: Colors.red, fontSize: 10)),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Container(
                                    height: 150,
                                    width: 150,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.image, size: 32, color: Theme.of(context).colorScheme.primary),
                                  ),
                            (idx) {
                              final newImages = List<PlatformFile>.from(widget.assetsImages)..removeAt(idx);
                              widget.onAssetsChanged(newImages, widget.assetsFiles, widget.assetsVideos);
                            },
                            AssetType.image,
                          );
                        } else if (currentIndex == 1) {
                          // Files tab
                          currentTab = _buildAssetsTab(
                            widget.assetsFiles,
                            'Nenhum arquivo adicionado',
                            (e) => Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              child: Center(child: _buildFileAvatar(e.value)),
                            ),
                            (idx) {
                              final newFiles = List<PlatformFile>.from(widget.assetsFiles)..removeAt(idx);
                              widget.onAssetsChanged(widget.assetsImages, newFiles, widget.assetsVideos);
                            },
                            AssetType.file,
                          );
                        } else {
                          // Videos tab
                          currentTab = _buildAssetsTab(
                            widget.assetsVideos,
                            'Nenhum vídeo adicionado',
                            (e) => Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              child: Center(
                                child: Icon(Icons.videocam, size: 32, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            (idx) {
                              final newVideos = List<PlatformFile>.from(widget.assetsVideos)..removeAt(idx);
                              widget.onAssetsChanged(widget.assetsImages, widget.assetsFiles, newVideos);
                            },
                            AssetType.video,
                          );
                        }

                        return currentTab;
                      },
                    ),
                  ),
                ),
              ],
            );
              },
            ),
          ),
      ],
      ),
    );

  }
}

