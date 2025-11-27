import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/task_files_repository.dart';
import '../../../services/upload_manager.dart';
import '../../molecules/tiles/asset_tile.dart';

class TaskFilesSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects.name
  final bool canUpload;
  final bool canDeleteOwn;

  const TaskFilesSection(
      {super.key,
      required this.task,
      required this.canUpload,
      required this.canDeleteOwn});

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

  // Realtime subscription
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _reload();

    final taskId = widget.task['id'] as String;

    // Subscribe to realtime changes
    _subscription = Supabase.instance.client
        .channel('task_files:$taskId')
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
              _reload();
            }
          },
        )
        .subscribe();

    // Listen to background uploads for this task (apenas para barra de progresso)
    _bgProgress = UploadManager.instance.progressOf(taskId);
    _bgListener = () {
      if (!mounted) return;
      setState(() {}); // Atualiza a barra de progresso

      final v = _bgProgress!.value;
      if (v != null && v >= 1.0) {
        // Fallback: Se o Realtime falhar, recarrega após o upload completar
        // Aguarda 1.5s para garantir que o update no banco (que ocorre após o upload) finalizou
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _reload();
          }
        });
      }
    };
    _bgProgress!.addListener(_bgListener!);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listAssetsByTask(widget.task['id'] as String);
      if (!mounted) return;
      setState(() {
        _files = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
    // Separate files by type
    final images = _files
        .where(
            (f) => (f['mime_type'] as String?)?.startsWith('image/') ?? false)
        .toList();
    final videos = _files
        .where(
            (f) => (f['mime_type'] as String?)?.startsWith('video/') ?? false)
        .toList();
    final others = _files.where((f) {
      final type = f['mime_type'] as String?;
      return !(type?.startsWith('image/') ?? false) &&
          !(type?.startsWith('video/') ?? false);
    }).toList();

    final hasAssets =
        images.isNotEmpty || videos.isNotEmpty || others.isNotEmpty;

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
            ]),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

class _TaskFilesTabViewState extends State<_TaskFilesTabView>
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
            child: Text('Nenhum arquivo'),
          ));
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
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
