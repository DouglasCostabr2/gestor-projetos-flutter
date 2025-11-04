import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mime/mime.dart' as mime;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/google_drive_oauth_service.dart';
import '../../../services/task_files_repository.dart';
import '../dialogs/dialogs.dart';
import '../../atoms/loaders/loaders.dart';

class FinalProjectSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects: { name, clients: { name } }
  const FinalProjectSection({super.key, required this.task});

  @override
  State<FinalProjectSection> createState() => _FinalProjectSectionState();
}

class _FinalProjectSectionState extends State<FinalProjectSection> {
  final _filesRepo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = [];

  // Arquivos temporários em upload (exibidos com loading)
  List<Map<String, dynamic>> _uploadingFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }



  Future<void> _loadFiles() async {
    debugPrint('🔄 [FinalProject] _loadFiles INICIADO');
    setState(() { _loading = true; _error = null; });
    try {
      debugPrint('🔄 [FinalProject] Buscando arquivos no banco...');
      final files = await _filesRepo.listFinalByTask(widget.task['id'] as String);
      debugPrint('✅ [FinalProject] ${files.length} arquivo(s) encontrado(s)');
      if (!mounted) {
        debugPrint('⚠️ [FinalProject] Widget desmontado, abortando setState');
        return;
      }
      setState(() { _files = files; });
      debugPrint('✅ [FinalProject] Estado atualizado com arquivos');
    } catch (e) {
      debugPrint('❌ [FinalProject] Erro ao carregar arquivos: $e');
      setState(() { _error = 'Erro ao carregar arquivos: $e'; });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
        debugPrint('✅ [FinalProject] _loadFiles CONCLUÍDO (loading = false)');
      } else {
        debugPrint('⚠️ [FinalProject] Widget desmontado no finally');
      }
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
    } catch (e) {
      debugPrint('⚠️ [FinalProject] Falha ao buscar companyName: $e');
      return null;
    }
  }

  Future<void> _pickAndUpload() async {
    debugPrint('📤 FinalProject: Iniciando seleção de arquivos...');
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: true,
    );

    if (res == null || res.files.isEmpty) {
      debugPrint('📤 FinalProject: Seleção cancelada ou vazia');
      return;
    }

    final filesToUpload = res.files.where((f) => f.bytes != null).toList();
    debugPrint('📤 FinalProject: ${filesToUpload.length} arquivo(s) selecionado(s)');

    if (!mounted) return;

    // Adiciona arquivos temporários à lista com status "uploading"
    final newUploadingFiles = filesToUpload.map((f) => {
      'filename': f.name,
      'mime_type': mime.lookupMimeType(f.name),
      'size_bytes': f.bytes!.length,
      'uploading': true, // Flag para identificar arquivos em upload
      'upload_id': DateTime.now().millisecondsSinceEpoch.toString() + f.name, // ID único
    }).toList();

    setState(() {
      _error = null;
      _uploadingFiles = [..._uploadingFiles, ...newUploadingFiles];
    });

    try {
      debugPrint('📤 FinalProject: Obtendo cliente autenticado...');
      final client = await _ensureClient();
      if (client == null) throw Exception('Conecte o Google Drive para enviar arquivos');

      debugPrint('📤 FinalProject: Cliente autenticado com sucesso');
      final clientName = (widget.task['projects']?['clients']?['name'] ?? 'Cliente').toString();
      final projectName = (widget.task['projects']?['name'] ?? 'Projeto').toString();
      final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();

      debugPrint('📤 FinalProject: Pasta destino: $clientName/$projectName/$taskTitle');

      final companyName = await _fetchCompanyNameForTask(widget.task['id'] as String);

      for (int i = 0; i < filesToUpload.length; i++) {
        final f = filesToUpload[i];
        final name = f.name;
        final bytes = f.bytes!;
        final mt = mime.lookupMimeType(name);

        debugPrint('📤 FinalProject: Enviando arquivo ${i + 1}/${filesToUpload.length}: $name (${bytes.length} bytes)');

        // Upload usando Resumable Upload API (suporta arquivos grandes) para subpasta "Projeto Final"
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
          onProgress: (progress) {
            // Não precisa fazer nada aqui - apenas mostra loading circular
          },
        );

        debugPrint('📤 FinalProject: Arquivo enviado ao Drive. ID: ${uploaded.id}');

        await _filesRepo.saveFile(
          taskId: widget.task['id'] as String,
          filename: name,
          sizeBytes: bytes.length,
          mimeType: mt,
          driveFileId: uploaded.id,
          driveFileUrl: uploaded.publicViewUrl,
          category: 'final',
        );

        debugPrint('📤 FinalProject: Arquivo salvo no banco de dados (${i + 1}/${filesToUpload.length})');
      }

      debugPrint('✅ FinalProject: Upload concluído com sucesso! Total: ${filesToUpload.length} arquivo(s)');
    } catch (e, stackTrace) {
      debugPrint('❌ FinalProject: Erro no upload: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) setState(() => _error = 'Falha ao enviar: $e');
    } finally {
      debugPrint('📤 FinalProject: Finalizando upload');

      // Remove os arquivos temporários que foram enviados
      if (mounted) {
        setState(() {
          _uploadingFiles.removeWhere((uploadingFile) {
            return newUploadingFiles.any((newFile) =>
              newFile['upload_id'] == uploadingFile['upload_id']
            );
          });
        });
      }
    }

    // Recarrega os arquivos após o upload (fora do try-catch para não travar a UI)
    debugPrint('📤 FinalProject: Recarregando lista de arquivos...');
    if (mounted) {
      await _loadFiles();
      debugPrint('✅ FinalProject: Lista de arquivos recarregada');
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
      debugPrint('🗑️ [FinalProject] Removendo arquivo: ${f['filename']}');

      // 1. Remover do Google Drive
      final driveFileId = f['drive_file_id'] as String?;
      if (driveFileId != null) {
        debugPrint('🗑️ [FinalProject] Removendo do Google Drive: $driveFileId');
        try {
          final client = await _ensureClient();
          if (client != null) {
            await _drive.deleteFile(
              client: client,
              driveFileId: driveFileId,
            );
            debugPrint('✅ [FinalProject] Arquivo removido do Google Drive');
          } else {
            debugPrint('⚠️ [FinalProject] Cliente Google Drive não disponível, pulando exclusão do Drive');
          }
        } catch (e) {
          debugPrint('⚠️ [FinalProject] Erro ao remover do Google Drive: $e');
          // Continua mesmo se falhar no Drive
        }
      }

      // 2. Remover do banco de dados
      debugPrint('🗑️ [FinalProject] Removendo do banco de dados: ${f['id']}');
      await _filesRepo.delete(f['id'] as String);
      debugPrint('✅ [FinalProject] Arquivo removido do banco de dados');

      // 3. Recarregar lista
      await _loadFiles();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo removido com sucesso')),
      );
    } catch (e) {
      debugPrint('❌ [FinalProject] Erro ao remover arquivo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover arquivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verificar se a tarefa está concluída
    final taskStatus = widget.task['status'] as String?;
    final isCompleted = taskStatus == 'completed';

    // Se a tarefa não está concluída, não mostra a seção
    if (!isCompleted) {
      return const SizedBox.shrink();
    }

    // Combina arquivos reais com arquivos em upload
    final allFiles = [..._files, ..._uploadingFiles];

    // Helper function to check if file is an image (by mime type AND extension)
    bool isImage(Map<String, dynamic> f) {
      final mimeType = f['mime_type'] as String?;
      final filename = (f['filename'] as String? ?? '').toLowerCase();

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
    bool isVideo(Map<String, dynamic> f) {
      final mimeType = f['mime_type'] as String?;
      return mimeType?.startsWith('video/') ?? false;
    }

    // Separate files by type
    final images = allFiles.where(isImage).toList();
    final videos = allFiles.where(isVideo).toList();
    final others = allFiles.where((f) => !isImage(f) && !isVideo(f)).toList();

    final hasFiles = allFiles.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Projeto Final', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            FilledButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Adicionar arquivos'),
            ),
          ]),
          const SizedBox(height: 12),

          // Mensagem de erro (se houver)
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Resto do conteúdo (lista de arquivos)
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!hasFiles)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhum arquivo enviado ainda',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Lista de arquivos
          if (!_loading && hasFiles)
            _FinalProjectTabView(
              images: images,
              others: others,
              videos: videos,
              onDownload: _downloadFile,
              onDelete: _deleteFile,
            ),
        ]),
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

class _FinalProjectTabViewState extends State<_FinalProjectTabView> with SingleTickerProviderStateMixin {
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
                borderRadius: 0,
              )
            : Image.network(
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
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  width: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
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
                borderRadius: 0,
              )
            : Icon(
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

            // Botões no canto superior direito
            if (!isUploading)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => widget.onDownload(f),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.download_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => widget.onDelete(f),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
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

