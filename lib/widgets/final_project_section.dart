import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mime/mime.dart' as mime;
import 'package:url_launcher/url_launcher.dart';

import '../services/google_drive_oauth_service.dart';
import '../services/task_files_repository.dart';
import 'drive_connect_dialog.dart';

class FinalProjectSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects: { name, clients: { name } }
  const FinalProjectSection({super.key, required this.task});

  @override
  State<FinalProjectSection> createState() => _FinalProjectSectionState();
}

class _FinalProjectSectionState extends State<FinalProjectSection> {
  final _filesRepo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();

  bool _uploading = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() { _loading = true; _error = null; });
    try {
      final files = await _filesRepo.listFinalByTask(widget.task['id'] as String);
      if (!mounted) return;
      setState(() { _files = files; });
    } catch (e) {
      setState(() { _error = 'Erro ao carregar arquivos: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<auth.AuthClient?> _ensureClient() async {
    try {
      return await _drive.getAuthedClient();
    } on ConsentRequired catch (_) {
      final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
      if (ok == true) return await _drive.getAuthedClient();
    } catch (_) {}
    return null;
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() { _uploading = true; _error = null; });

    try {
      final client = await _ensureClient();
      if (client == null) throw Exception('Conecte o Google Drive para enviar arquivos');
      final clientName = (widget.task['projects']?['clients']?['name'] ?? 'Cliente').toString();
      final projectName = (widget.task['projects']?['name'] ?? 'Projeto').toString();
      final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();

      for (final f in res.files.where((f) => f.bytes != null)) {
        final name = f.name;
        final bytes = f.bytes!;
        final mt = mime.lookupMimeType(name);
        final uploaded = await _drive.uploadToTaskFolder(
          client: client,
          clientName: clientName,
          projectName: projectName,
          taskName: taskTitle,
          filename: name,
          bytes: bytes,
          mimeType: mt,
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
      await _loadFiles(); // Reload files after upload
    } catch (e) {
      setState(() => _error = 'Falha ao enviar: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
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

  Future<void> _deleteFile(Map<String, dynamic> f) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover arquivo'),
        content: Text('Deseja remover "${f['filename']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _filesRepo.delete(f['id'] as String);
      await _loadFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo removido com sucesso')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover arquivo: $e')),
      );
    }
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

    final hasFiles = _files.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Projeto Final', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (_uploading) const SizedBox(width: 120, child: LinearProgressIndicator()),
            if (!_uploading)
              FilledButton.icon(
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Adicionar arquivos'),
              ),
          ]),
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          if (!_loading && !hasFiles)
            const Text('Nenhum arquivo adicionado'),
          if (!_loading && hasFiles)
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
        ]),
      ),
    );
  }

  Widget _buildFileGrid(List<Map<String, dynamic>> files) {
    if (files.isEmpty) {
      return const Center(child: Text('Nenhum arquivo'));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        final driveFileId = f['drive_file_id'] as String?;
        final mimeType = f['mime_type'] as String? ?? '';
        final filename = f['filename'] as String? ?? 'Sem nome';

        // Generate thumbnail URL for images
        final thumbnailUrl = driveFileId != null && mimeType.startsWith('image/')
            ? 'https://drive.google.com/thumbnail?id=$driveFileId&sz=w400'
            : null;

        return Container(
          width: 200,
          margin: const EdgeInsets.only(right: 12),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: thumbnailUrl != null
                              ? Image.network(
                                  thumbnailUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 48)),
                                )
                              : Center(
                                  child: Icon(
                                    mimeType.startsWith('video/') ? Icons.video_file : Icons.insert_drive_file,
                                    size: 48,
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
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
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _deleteFile(f),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

