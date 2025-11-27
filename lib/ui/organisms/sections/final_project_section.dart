import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart' as mime;
import 'package:http/http.dart' as http;

// UI Components

import '../dialogs/dialogs.dart'; // DriveConnectDialog
import '../../molecules/tiles/asset_tile.dart';

// Services
import '../../../services/google_drive_oauth_service.dart';
import '../../../services/task_files_repository.dart';
import '../../../services/upload_manager.dart';

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

  // Background uploads
  ValueListenable<double?>? _bgProgress;
  VoidCallback? _bgListener;

  // Realtime subscription
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadFiles();

    final taskId = widget.task['id'] as String;

    // Subscribe to realtime changes
    _subscription = Supabase.instance.client
        .channel('task_files_final:$taskId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_files',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: taskId,
          ),
          callback: (payload) {
            if (mounted) {
              _loadFiles();
            }
          },
        )
        .subscribe();

    // Listen to background uploads for this task
    _bgProgress = UploadManager.instance.progressOf(taskId);
    _bgListener = () {
      if (!mounted) return;
      setState(() {}); // Atualiza a barra de progresso (se houver)

      final v = _bgProgress!.value;
      if (v != null && v >= 1.0) {
        // Fallback: Se o Realtime falhar, recarrega após o upload completar
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _loadFiles();
          }
        });
      }
    };
    _bgProgress!.addListener(_bgListener!);
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
    if (filesToUpload.isEmpty) return;

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

      final items = filesToUpload
          .map((f) => MemoryUploadItem(
                name: f.name,
                bytes: f.bytes!,
                mimeType:
                    mime.lookupMimeType(f.name) ?? 'application/octet-stream',
                subfolderName: 'Projeto Final',
                category: 'final',
              ))
          .toList();

      // Inicia o upload usando o UploadManager com cache local para feedback instantâneo
      await UploadManager.instance.startAssetsUploadWithLocalCache(
        client: client,
        taskId: widget.task['id'] as String,
        items: items,
        clientName: clientName,
        projectName: projectName,
        taskTitle: taskTitle,
        companyName: companyName,
      );

      // O Realtime e o Listener cuidarão de atualizar a UI
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao enviar: $e');
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> f) async {
    try {
      // Extrai a URL de download do Google Drive
      String? url;
      final id = f['drive_file_id'] as String?;
      if (id != null && id.isNotEmpty) {
        url = Uri.https(
                'drive.google.com', '/uc', {'export': 'download', 'id': id})
            .toString();
      } else {
        final view = f['drive_file_url'] as String?;
        if (view != null) {
          try {
            final u = Uri.parse(view);
            final fileId = u.queryParameters['id'];
            if (fileId != null && fileId.isNotEmpty) {
              url = Uri.https('drive.google.com', '/uc',
                  {'export': 'download', 'id': fileId}).toString();
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
      final filename = f['filename'] as String? ??
          'download_${DateTime.now().millisecondsSinceEpoch}';

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
      // O Realtime deve atualizar a lista, mas podemos forçar também
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
  void dispose() {
    _subscription?.unsubscribe();
    if (_bgProgress != null && _bgListener != null) {
      _bgProgress!.removeListener(_bgListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = widget.task['status'] as String?;
    final isCompleted = taskStatus == 'completed';
    if (!isCompleted) return const SizedBox.shrink();

    final allFiles = _files; // Não precisa mais de _uploadingFiles

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
            children: files
                .map((f) => AssetTile(
                      fileData: f,
                      onDownload: widget.onDownload,
                      onDelete: widget.onDelete,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
