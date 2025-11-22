import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../../../services/task_files_repository.dart';
import '../../../services/upload_manager.dart';


class TaskFilesSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects.name
  final bool canUpload;
  final bool canDeleteOwn;

  const TaskFilesSection({super.key, required this.task, required this.canUpload, required this.canDeleteOwn});

  @override
  State<TaskFilesSection> createState() => _TaskFilesSectionState();
}

class _TaskFilesSectionState extends State<TaskFilesSection> {
  final _repo = TaskFilesRepository();

  bool _loading = true;
  List<Map<String, dynamic>> _files = [];
  String? _error;

  // Background uploads started elsewhere (e.g., QuickTaskForm)
  ValueListenable<double?>? _bgProgress;
  VoidCallback? _bgListener;

  @override
  void initState() {
    super.initState();
    _reload();
    // Listen to background uploads for this task
    final id = widget.task['id'] as String;
    _bgProgress = UploadManager.instance.progressOf(id);
    _bgListener = () {
      if (!mounted) return;
      setState(() {});
      final v = _bgProgress!.value;
      if (v != null && v >= 1.0) {
        // refresh file list after background upload completes
        _reload();
      }
    };
    _bgProgress!.addListener(_bgListener!);
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _repo.listAssetsByTask(widget.task['id'] as String);
      if (!mounted) return;
      setState(() { _files = list; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }



  Future<void> _downloadFile(Map<String, dynamic> f) async {
    try {
      // Extrai a URL de download do Google Drive
      String? url;
      final id = f['drive_file_id'] as String?;
      if (id != null && id.isNotEmpty) {
        url = Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': id}).toString();
      } else {
        final view = f['drive_file_url'] as String?;
        if (view != null) {
          try {
            final u = Uri.parse(view);
            final fileId = u.queryParameters['id'];
            if (fileId != null && fileId.isNotEmpty) {
              url = Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': fileId}).toString();
            } else {
              url = view;
            }
          } catch (_) {
            url = view;
          }
        }
      }

      if (url == null) return;

      // Obtém o nome original do arquivo
      final filename = f['filename'] as String? ?? 'download_${DateTime.now().millisecondsSinceEpoch}';

      // Abre diálogo para escolher onde salvar
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar arquivo',
        fileName: filename,
      );

      if (outputPath == null) return; // Usuário cancelou

      // Baixa o arquivo
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Salva o arquivo
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo baixado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Erro ao baixar arquivo: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar arquivo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  @override
  void dispose() {
    if (_bgProgress != null && _bgListener != null) {
      _bgProgress!.removeListener(_bgListener!);
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Separate files by type
    final images = _files.where((f) => (f['mime_type'] as String?)?.startsWith('image/') ?? false).toList();
    final videos = _files.where((f) => (f['mime_type'] as String?)?.startsWith('video/') ?? false).toList();
    final others = _files.where((f) {
      final type = f['mime_type'] as String?;
      return !(type?.startsWith('image/') ?? false) && !(type?.startsWith('video/') ?? false);
    }).toList();

    final hasAssets = images.isNotEmpty || videos.isNotEmpty || others.isNotEmpty;

    // Se está carregando, não mostra nada ainda
    if (_loading) {
      return const SizedBox.shrink();
    }

    // Se não tem assets e não está fazendo upload em background, não mostra a seção
    if (!hasAssets && _bgProgress?.value == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Assets', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (_bgProgress?.value != null) ...[
                SizedBox(width: 120, child: LinearProgressIndicator(value: _bgProgress!.value == 0 ? null : _bgProgress!.value)),
                const SizedBox(width: 8),
                Text('${((_bgProgress!.value ?? 0) * 100).toStringAsFixed(0)}%'),
                const SizedBox(width: 12),
              ],
            ]),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (hasAssets)
              _TaskFilesTabView(
                images: images,
                others: others,
                videos: videos,
                onDownload: _downloadFile,
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskFilesTabView extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> others;
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onDownload;

  const _TaskFilesTabView({
    required this.images,
    required this.others,
    required this.videos,
    required this.onDownload,
  });

  @override
  State<_TaskFilesTabView> createState() => _TaskFilesTabViewState();
}

class _TaskFilesTabViewState extends State<_TaskFilesTabView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${widget.images.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                isLabelVisible: widget.images.isNotEmpty,
                child: const Icon(Icons.image),
              ),
            ),
            Tab(
              icon: Badge(
                label: Text('${widget.others.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                isLabelVisible: widget.others.isNotEmpty,
                child: const Icon(Icons.insert_drive_file),
              ),
            ),
            Tab(
              icon: Badge(
                label: Text('${widget.videos.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                isLabelVisible: widget.videos.isNotEmpty,
                child: const Icon(Icons.videocam),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCurrentTab(),
      ],
    );
  }

  Widget _buildCurrentTab() {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        final files = _tabController.index == 0
            ? widget.images
            : (_tabController.index == 1 ? widget.others : widget.videos);

        if (files.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Nenhum arquivo'),
          ));
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: files.map((f) => _buildFileTile(context, f, widget.onDownload)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFileTile(BuildContext context, Map<String, dynamic> f, Function(Map<String, dynamic>) onDownload) {
    final driveFileId = f['drive_file_id'] as String?;
    final mimeType = f['mime_type'] as String? ?? '';
    final filename = f['filename'] as String? ?? 'Sem nome';
    final isFromDesignMaterials = f['is_from_design_materials'] == true;

    final thumbnailUrl = driveFileId != null && mimeType.startsWith('image/')
        ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w800'
        : null;

    final isImage = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');

    Widget contentWidget;

    if (isImage && thumbnailUrl != null) {
      contentWidget = SizedBox(
        height: 150,
        width: 150,
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
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

    return SizedBox(
      width: 150,
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Imagem de fundo
            contentWidget,

            // Nome do arquivo na parte inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                  filename,
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

            // Badge "Design Materials" no canto superior esquerdo
            if (isFromDesignMaterials)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_special,
                        size: 10,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DM',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Botão de download no canto superior direito
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onDownload(f),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.download_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

