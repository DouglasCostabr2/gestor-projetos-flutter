

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mime/mime.dart' as mime;

import 'package:url_launcher/url_launcher.dart';

import '../services/google_drive_oauth_service.dart';
import '../services/task_files_repository.dart';
import '../services/upload_manager.dart';


class TaskFilesSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects.name
  final bool canUpload;
  final bool canDeleteOwn;

  const TaskFilesSection({super.key, required this.task, required this.canUpload, required this.canDeleteOwn});

  @override
  State<TaskFilesSection> createState() => _TaskFilesSectionState();
}

class _TaskFilesSectionState extends State<TaskFilesSection> {
  String? _connectedEmail;

  final _repo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();

  bool _loading = true;
  List<Map<String, dynamic>> _files = [];
  String? _error;
  bool _uploading = false;
  double _progress = 0;

  // Background uploads started elsewhere (e.g., QuickTaskForm)
  ValueListenable<double?>? _bgProgress;
  VoidCallback? _bgListener;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadConnectionEmail();
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

  Future<void> _loadConnectionEmail() async {
    try {
      final email = await _drive.getConnectedEmail();
      if (!mounted) return;
      setState(() { _connectedEmail = email; });
    } catch (_) {}
  }





  Future<void> _pickAndUpload() async {
    if (!widget.canUpload) return;

    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['jpg','jpeg','png','gif','webp'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    setState(() { _uploading = true; _progress = 0; _error = null; });

    try {
      // Acquire client via refresh or show error if not connected
      auth.AuthClient client;
      try {
        client = await _drive.getAuthedClient();
      } on ConsentRequired catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive não conectado. Peça ao administrador para conectar no Painel Admin.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        setState(() { _uploading = false; });
        return;
      }

      final projectName = (widget.task['projects']?['name'] ?? 'Projeto').toString();
      final clientName = (widget.task['projects']?['clients']?['name'] ?? 'Cliente').toString();
      final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();

      final total = res.files.length;
      var index = 0;
      for (final f in res.files) {
        index++;
        final name = f.name;
        final bytes = f.bytes;
        if (bytes == null) continue;
        final type = mime.lookupMimeType(name);

        final uploaded = await _drive.uploadToTaskFolder(
          client: client,
          clientName: clientName,
          projectName: projectName,
          taskName: taskTitle,
          filename: name,
          bytes: bytes,
          mimeType: type,
        );

        final url = uploaded.publicViewUrl;
        await _repo.saveFile(
          taskId: widget.task['id'] as String,
          filename: name,
          sizeBytes: bytes.length,
          mimeType: type,
          driveFileId: uploaded.id,
          driveFileUrl: url,
          category: 'assets',
        );

        setState(() { _progress = index / total; });
      }
      await _reload();
    } catch (e) {
      setState(() { _error = 'Falha no upload: $e'; });
    } finally {
      if (mounted) setState(() { _uploading = false; });
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }
  Future<void> _downloadFile(Map<String, dynamic> f) async {
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
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
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

    final actions = <Widget>[];

    if (widget.canUpload) {
      actions.add(FilledButton.icon(
        onPressed: _connectedEmail != null ? _pickAndUpload : null,
        icon: const Icon(Icons.file_upload),
        label: const Text('Adicionar assets'),
      ));
    }

    final hasAssets = images.isNotEmpty || videos.isNotEmpty || others.isNotEmpty;

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
              if (_uploading) SizedBox(width: 120, child: LinearProgressIndicator(value: _progress == 0 ? null : _progress)),
              if (_uploading) const SizedBox(width: 8),
              ...actions,
            ]),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
            if (!_loading && !hasAssets)
              const Text('Nenhum asset adicionado'),
            if (!_loading && hasAssets)
              DefaultTabController(
                length: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(
                          icon: Badge(
                            label: Text('${images.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: images.isNotEmpty,
                            child: const Icon(Icons.image),
                          ),
                        ),
                        Tab(
                          icon: Badge(
                            label: Text('${others.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: others.isNotEmpty,
                            child: const Icon(Icons.insert_drive_file),
                          ),
                        ),
                        Tab(
                          icon: Badge(
                            label: Text('${videos.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            isLabelVisible: videos.isNotEmpty,
                            child: const Icon(Icons.videocam),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          _buildFileGrid(images),
                          _buildFileGrid(others),
                          _buildFileGrid(videos),
                        ],
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

  Widget _buildFileGrid(List<Map<String, dynamic>> files) {
    if (files.isEmpty) {
      return const Center(child: Text('Nenhum arquivo'));
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        final url = f['drive_file_url'] as String?;
        final driveFileId = f['drive_file_id'] as String?;
        final mimeType = f['mime_type'] as String? ?? '';
        final filename = f['filename'] as String? ?? 'Sem nome';

        // Generate thumbnail URL for images
        final thumbnailUrl = driveFileId != null && mimeType.startsWith('image/')
            ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w200'
            : null;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: InkWell(
                  onTap: () => _openUrl(url),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: thumbnailUrl != null
                              ? Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                                )
                              : Icon(
                                  mimeType.startsWith('video/') ? Icons.video_file : Icons.insert_drive_file,
                                  size: 48,
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: InkWell(
                  onTap: () => _downloadFile(f),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.download, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


