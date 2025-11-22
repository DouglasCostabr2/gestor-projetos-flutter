import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart' as mime;

// UI Components
import '../../atoms/atoms.dart'; // SkeletonLoader, IconOnlyButton
import '../../atoms/image_viewer/image_viewer.dart';
import '../dialogs/dialogs.dart'; // DriveConnectDialog

// Services
import '../../../services/google_drive_oauth_service.dart';
import '../../../services/task_files_repository.dart';

class FinalProjectSection extends StatefulWidget {
  final Map<String, dynamic> task;

  const FinalProjectSection({
    super.key,
    required this.task,
  });

  @override
  State<FinalProjectSection> createState() => _FinalProjectSectionState();
}

class _FinalProjectSectionState extends State<FinalProjectSection> {
  final _filesRepo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = [];
  // Temporary uploading files list (shown with loading indicator)
  List<Map<String, dynamic>> _uploadingFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files =
          await _filesRepo.listFinalByTask(widget.task['id'] as String);
      if (!mounted) return;
      setState(() {
        _files = files;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar arquivos: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<auth.AuthClient?> _ensureClient() async {
    try {
      return await _drive.getAuthedClient();
    } on ConsentRequired catch (_) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => DriveConnectDialog(service: _drive),
      );
      if (ok == true) return await _drive.getAuthedClient();
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchCompanyNameForTask(String taskId) async {
    try {
      final row = await Supabase.instance.client
          .from('tasks')
          .select('projects:project_id(companies:company_id(name))')
          .eq('id', taskId)
          .maybeSingle();
      final companies = (row?['projects'] as Map?)?['companies'] as Map?;
      final name = companies?['name'] as String?;
      return (name != null && name.trim().isNotEmpty) ? name : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final filesToUpload = res.files.where((f) => f.bytes != null).toList();
    if (!mounted) return;

    final newUploadingFiles = filesToUpload
        .map((f) => {
              'filename': f.name,
              'mime_type': mime.lookupMimeType(f.name),
              'size_bytes': f.bytes!.length,
              'uploading': true,
              'upload_id': '${DateTime.now().millisecondsSinceEpoch}${f.name}',
            })
        .toList();

    setState(() {
      _error = null;
      _uploadingFiles = [..._uploadingFiles, ...newUploadingFiles];
    });

    try {
      final client = await _ensureClient();
      if (client == null) {
        throw Exception('Conecte o Google Drive para enviar arquivos');
      }

      final clientName =
          (widget.task['projects']?['clients']?['name'] ?? 'Cliente')
              .toString();
      final projectName =
          (widget.task['projects']?['name'] ?? 'Projeto').toString();
      final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();
      final companyName =
          await _fetchCompanyNameForTask(widget.task['id'] as String);

      for (final f in filesToUpload) {
        final name = f.name;
        final bytes = f.bytes!;
        final mt = mime.lookupMimeType(name);
        final uploaded = await _drive.uploadToTaskSubfolderResumable(
          client: client,
          clientName: clientName,
          projectName: projectName,
          taskName: taskTitle,
          subfolderName: 'Projeto Final',
          filename: name,
          bytes: bytes,
          mimeType: mt,
          companyName: companyName,
          onProgress: (_) {},
        );
        await _filesRepo.saveFile(
          taskId: widget.task['id'] as String,
          filename: name,
          sizeBytes: bytes.length,
          mimeType: mt,
          driveFileId: uploaded.id,
          driveFileUrl: uploaded.publicViewUrl,
          category: 'final',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao enviar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFiles.removeWhere((uploadingFile) => newUploadingFiles.any(
              (newFile) => newFile['upload_id'] == uploadingFile['upload_id']));
        });
      }
    }
    if (mounted) await _loadFiles();
  }

  Future<void> _downloadFile(Map<String, dynamic> f) async {
    try {
      final driveFileId = f['drive_file_id'] as String?;
      if (driveFileId == null || driveFileId.isEmpty) {
        throw Exception('ID do arquivo não encontrado');
      }
      final filename = f['filename'] as String? ??
          'download_${DateTime.now().millisecondsSinceEpoch}';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar arquivo',
        fileName: filename,
      );
      if (outputPath == null) return;
      final client = await _ensureClient();
      if (client == null) {
        throw Exception('Conecte o Google Drive para baixar arquivos');
      }
      final response = await client.get(Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$driveFileId?alt=media'));
      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Arquivo baixado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
        }
      } else {
        throw Exception('Erro ao baixar arquivo: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao baixar arquivo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3)));
      }
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> f) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover arquivo'),
        content: Text('Deseja remover "${f['filename']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final driveFileId = f['drive_file_id'] as String?;
      if (driveFileId != null) {
        try {
          final client = await _ensureClient();
          if (client != null) {
            await _drive.deleteFile(client: client, driveFileId: driveFileId);
          }
        } catch (_) {}
      }
      await _filesRepo.delete(f['id'] as String);
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arquivo removido com sucesso')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao remover arquivo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = widget.task['status'] as String?;
    final isCompleted = taskStatus == 'completed';
    if (!isCompleted) return const SizedBox.shrink();

    final allFiles = [..._files, ..._uploadingFiles];
    bool isImage(Map<String, dynamic> f) {
      final mimeType = f['mime_type'] as String?;
      final filename = (f['filename'] as String? ?? '').toLowerCase();
      if (filename.endsWith('.psd') ||
          filename.endsWith('.ai') ||
          filename.endsWith('.sketch') ||
          filename.endsWith('.fig') ||
          filename.endsWith('.xd')) {
        return false;
      }
      return mimeType?.startsWith('image/') ?? false;
    }

    bool isVideo(Map<String, dynamic> f) =>
        (f['mime_type'] as String?)?.startsWith('video/') ?? false;

    final images = allFiles.where(isImage).toList();
    final videos = allFiles.where(isVideo).toList();
    final others = allFiles.where((f) => !isImage(f) && !isVideo(f)).toList();
    final hasFiles = allFiles.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Projeto Final',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _pickAndUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Adicionar arquivos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (!hasFiles)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nenhum arquivo enviado ainda',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              _FinalProjectTabView(
                images: images,
                others: others,
                videos: videos,
                onDownload: _downloadFile,
                onDelete: _deleteFile,
              ),
          ],
        ),
      ),
    );
  }
}

class _FinalProjectTabView extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> others;
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onDownload;
  final Function(Map<String, dynamic>) onDelete;

  const _FinalProjectTabView({
    required this.images,
    required this.others,
    required this.videos,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  State<_FinalProjectTabView> createState() => _FinalProjectTabViewState();
}

class _FinalProjectTabViewState extends State<_FinalProjectTabView>
    with SingleTickerProviderStateMixin {
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
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${widget.images.length}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                isLabelVisible: widget.images.isNotEmpty,
                child: const Icon(Icons.image),
              ),
            ),
            Tab(
              icon: Badge(
                label: Text('${widget.others.length}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                isLabelVisible: widget.others.isNotEmpty,
                child: const Icon(Icons.insert_drive_file),
              ),
            ),
            Tab(
              icon: Badge(
                label: Text('${widget.videos.length}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface)),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Nenhum arquivo')));
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: files.map((f) => _buildFileTile(context, f)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFileTile(BuildContext context, Map<String, dynamic> f) {
    final isUploading = f['uploading'] == true;
    final driveFileId = f['drive_file_id'] as String?;
    final mimeType = f['mime_type'] as String? ?? '';
    final filename = f['filename'] as String? ?? 'Sem nome';
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
        child: isUploading
            ? SkeletonLoader.box(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0)
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                      height: 150,
                      width: 150,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()));
                },
                errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    width: 150,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.broken_image,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary)),
              ),
      );
    } else {
      contentWidget = Container(
        height: 150,
        width: 150,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: isUploading
            ? SkeletonLoader.box(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0)
            : Icon(isVideo ? Icons.video_file : Icons.insert_drive_file,
                size: 32, color: Theme.of(context).colorScheme.primary),
      );
    }

    return SizedBox(
      width: 150,
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            contentWidget,
            // File name overlay
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
                        bottomRight: Radius.circular(8))),
                child: Text(filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white, fontSize: 10)),
              ),
            ),
            if (!isUploading)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View image (if image)
                    if (isImage)
                      Material(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ImageViewer(imageUrl: thumbnailUrl!))),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.zoom_in,
                                  size: 14, color: Colors.white)),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Download button
                    Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => widget.onDownload(f),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.download_rounded,
                                size: 14, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Delete button
                    Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => widget.onDelete(f),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
