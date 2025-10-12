import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:mime/mime.dart' as mime;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_briefing.dart';
import 'standard_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

import '../services/google_drive_oauth_service.dart';
import '../src/state/app_state_scope.dart';

import '../services/task_comments_repository.dart';
import '../services/task_files_repository.dart';
import 'drive_connect_dialog.dart';

class CommentsSection extends StatefulWidget {
  final Map<String, dynamic> task; // must include id, title, projects: { name, clients: { name } }
  const CommentsSection({super.key, required this.task});


  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _commentsRepo = TaskCommentsRepository();
  final _filesRepo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();


  late quill.QuillController _ctrl;
  final FocusNode _editorFocus = FocusNode();

  final _text = TextEditingController();
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _comments = [];
  final List<PlatformFile> _pending = [];
  double _composeHeight = 120;

  bool _composeEmpty = true;
  void _onEditorChanged() {
    try {
      final empty = _ctrl.document.toPlainText().trim().isEmpty;
      final h = _calcComposeHeight();
      if (empty != _composeEmpty || (h - _composeHeight).abs() > 0.5) {
        if (!mounted) return;
        setState(() { _composeEmpty = empty; _composeHeight = h; });
      }
    } catch (_) {}
  }

  double _calcComposeHeight() {
    try {
      final text = _ctrl.document.toPlainText();
      final lines = text.isEmpty ? 1 : text.split('\n').length;
      int images = 0;
      final ops = List<Map<String, dynamic>>.from(_ctrl.document.toDelta().toJson());
      for (final op in ops) {
        final ins = op['insert'];
        if (ins is Map && ins.containsKey('image')) images++;
      }
      double h = 100 + (lines - 1) * 18 + images * 180;
      if (h < 100) h = 100;
      return h;
    } catch (_) {
      return 120;
    }
  }



  @override
  void initState() {
    super.initState();
    _ctrl = quill.QuillController.basic();
    _ctrl.addListener(_onEditorChanged);
    _composeEmpty = _ctrl.document.toPlainText().trim().isEmpty;
    _composeHeight = _calcComposeHeight();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await _commentsRepo.listByTask(widget.task['id'] as String);
      if (!mounted) return;
      setState(() => _comments = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pickImages() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: const ['jpg','jpeg','png','gif','webp'], withData: true);
    if (res == null) return;
    for (final f in res.files.where((f) => f.bytes != null)) {
      final bytes = f.bytes!;
      final extFromName = f.extension ?? '';
      final ext = extFromName.isNotEmpty ? extFromName : ((mime.lookupMimeType(f.name) ?? 'image/png').split('/').last);
      final tmpPath = await _writeTempImage(bytes, ext, originalName: f.name);
      final index = _ctrl.selection.baseOffset < 0 ? _ctrl.document.length : _ctrl.selection.baseOffset;
      _ctrl.replaceText(index, 0, quill.BlockEmbed.image(tmpPath), TextSelection.collapsed(offset: index + 1));
    }
    if (mounted) setState(() => _pending.addAll(res.files.where((f) => f.bytes != null)));
  }


  bool _isAbsolutePath(String p) {
    if (p.isEmpty) return false;
    return p.startsWith('/') || p.startsWith('\\') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(p);
  }

  ImageProvider<Object>? _quillImageProvider(BuildContext context, String imageUrl) {
    if (imageUrl.startsWith('data:')) {
      final i = imageUrl.indexOf(',');
      if (i > 0) {
        try {
          final b64 = imageUrl.substring(i + 1);
          return MemoryImage(base64Decode(b64));
        } catch (_) {}
      }
    }
    if (imageUrl.startsWith('file://')) {
      final path = Uri.parse(imageUrl).toFilePath();
      return FileImage(File(path));
    }
    if (_isAbsolutePath(imageUrl)) {
      return FileImage(File(imageUrl));
    }
    return null;
  }
  void _removeCommentImage(String src) {
    final ops = List<Map<String, dynamic>>.from(_ctrl.document.toDelta().toJson());
    final newOps = <Map<String, dynamic>>[];
    var removed = false;
    for (final op in ops) {
      final ins = op['insert'];
      if (!removed && ins is Map && ins['image'] == src) {
        removed = true;
        continue;
      }
      newOps.add(Map<String, dynamic>.from(op));
    }
    setState(() {
      _ctrl = quill.QuillController(
        document: quill.Document.fromJson(newOps),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }


  Future<String> _writeTempImage(List<int> bytes, String ext, {String? originalName}) async {
    final dir = Directory.systemTemp;
    final ts = DateTime.now().microsecondsSinceEpoch;
    String safeName = '';
    if (originalName != null && originalName.trim().isNotEmpty) {
      final base = originalName.split(RegExp(r'[\\/]')).last;
      safeName = base;
    }
    final filename = safeName.isNotEmpty ? 'comment_${ts}__$safeName' : 'comment_$ts.$ext';
    final file = File(dir.path + Platform.pathSeparator + filename);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
  Uri? _toDownloadUriFromSrc(String src) {
    try {
      final u = Uri.parse(src);
      if (!(u.scheme == 'http' || u.scheme == 'https')) return null;
      if (u.host.contains('drive.google.com')) {
        // handle ?id= and /file/d/<id>/ patterns
        final qid = u.queryParameters['id'];
        if (qid != null && qid.isNotEmpty) {
          return Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': qid});
        }
        final segs = u.pathSegments;
        final dIndex = segs.indexOf('d');
        if (dIndex >= 0 && dIndex + 1 < segs.length) {
          final fileId = segs[dIndex + 1];
          if (fileId.isNotEmpty) {
            return Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': fileId});
          }
        }
        // fallback
        return u;
      }
      return u;
    } catch (_) {
      return null;
    }
  }
  Future<void> _openDownloadFromSrc(String src) async {
    final uri = _toDownloadUriFromSrc(src);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(dynamic v) {
    DateTime? dt;
    if (v is DateTime) {
      dt = v;
    } else if (v is String) {
      dt = DateTime.tryParse(v);
    }
    if (dt == null) return (v ?? '').toString();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }


  Future<void> _send() async {
    setState(() { _sending = true; _error = null; });
    try {
      final plain = _ctrl.document.toPlainText().trim();
      // Create comment first to get comment_id for attachments
      final comment = await _commentsRepo.createComment(
        taskId: widget.task['id'] as String,
        content: plain.isEmpty ? '-' : plain,
      );

      // Process inline images in Quill Delta
      final List<Map<String, dynamic>> ops = List<Map<String, dynamic>>.from(_ctrl.document.toDelta().toJson());
      final usedNames = <String>{};
      String uniqueName(String base) {
        var candidate = base;
        var i = 1;
        while (usedNames.contains(candidate)) {
          final dot = candidate.lastIndexOf('.');
          final b = dot >= 0 ? candidate.substring(0, dot) : candidate;
          final ext = dot >= 0 ? candidate.substring(dot) : '';
          candidate = '$b ($i)$ext';
          i++;
        }
        usedNames.add(candidate);
        return candidate;
      }

      Future<auth.AuthClient?> ensureClient() async {
        try { return await _drive.getAuthedClient(); } on ConsentRequired catch (_) {
          if (!mounted) return null;
          final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
          if (ok == true) return await _drive.getAuthedClient();
        } catch (_) {}
        return null;
      }

      // Upload any local/data images and replace with Drive URLs
      auth.AuthClient? client;
      for (var i = 0; i < ops.length; i++) {
        final op = ops[i];
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          final src = insert['image']?.toString() ?? '';
          // Detect local or data images
          final isLocal = src.startsWith('data:') || src.startsWith('file://') || _isAbsolutePath(src);
          if (!isLocal) continue;

          client ??= await ensureClient();
          if (client == null) throw Exception('Conecte o Google Drive para enviar imagens nos comentários');

          // Read bytes and determine extension
          List<int> bytes;
          String ext;
          String mimeType;
          if (src.startsWith('data:')) {
            final headerEnd = src.indexOf(',');
            final header = headerEnd > 0 ? src.substring(5, headerEnd) : 'image/png;base64';
            final mt = header.split(';').first;
            ext = (mt.split('/').last);
            bytes = base64Decode(src.substring(headerEnd + 1));
            mimeType = mt;
          } else {
            final path = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
            final file = File(path);
            bytes = await file.readAsBytes();
            final mt = mime.lookupMimeType(path) ?? 'image/png';
            ext = mt.split('/').last;
            mimeType = mt;
          }

          // Build filename
          String originalName;
          if (src.startsWith('file://') || _isAbsolutePath(src)) {
            final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
            originalName = filePath.split(RegExp(r"[\\/]")).last;
          } else {
            originalName = 'Comentario_image.$ext';
          }
          if (!originalName.toLowerCase().startsWith('comentario_')) {
            originalName = 'Comentario_$originalName';
          }
          final filename = uniqueName(originalName);

          final clientName = (widget.task['projects']?['clients']?['name'] ?? 'Cliente').toString();
          final projectName = (widget.task['projects']?['name'] ?? 'Projeto').toString();
          final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();

          final up = await _drive.uploadToTaskSubfolder(
            client: client,
            clientName: clientName,
            projectName: projectName,
            taskName: taskTitle,
            subfolderName: 'Comentarios',
            filename: filename,
            bytes: bytes,
            mimeType: mimeType,
          );

          await _filesRepo.saveFile(
            taskId: widget.task['id'] as String,
            filename: filename,
            sizeBytes: bytes.length,
            mimeType: mimeType,
            driveFileId: up.id,
            driveFileUrl: up.publicViewUrl,
            category: 'comment',
            commentId: comment['id'] as String,
          );

          op['insert'] = { 'image': up.publicViewUrl };
          ops[i] = op;
        }
      }

      final contentJson = jsonEncode(ops);
      await Supabase.instance.client
          .from('task_comments')
          .update({'content': contentJson})
          .eq('id', comment['id']);

      _ctrl = quill.QuillController.basic();
      _ctrl.addListener(_onEditorChanged);
      _composeEmpty = true;
      _composeHeight = 120;
      _pending.clear();
      if (mounted) setState(() {});
      await _reload();
    } catch (e) {
      setState(() => _error = 'Falha ao enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir comentário?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) {
      await _commentsRepo.deleteComment(c['id'] as String);
      await _reload();
    }
  }

  Future<void> _editComment(Map<String, dynamic> c) async {
    final raw = (c['content'] ?? '').toString();
    quill.QuillController localCtrl;
    try {
      final decoded = raw.trim().startsWith('[') ? (jsonDecode(raw) as List) : null;
      if (decoded != null) {
        localCtrl = quill.QuillController(document: quill.Document.fromJson(decoded), selection: const TextSelection.collapsed(offset: 0));
      } else {
        localCtrl = quill.QuillController(document: quill.Document()..insert(0, raw), selection: const TextSelection.collapsed(offset: 0));
      }
    } catch (_) {
      localCtrl = quill.QuillController.basic();
    }

    Future<void> insertImages() async {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: const ['jpg','jpeg','png','gif','webp'], withData: true);
      if (res == null) return;
      for (final f in res.files.where((f) => f.bytes != null)) {
        final bytes = f.bytes!;
        final extFromName = f.extension ?? '';
        final ext = extFromName.isNotEmpty ? extFromName : ((mime.lookupMimeType(f.name) ?? 'image/png').split('/').last);
        final tmpPath = await _writeTempImage(bytes, ext, originalName: f.name);
        final index = localCtrl.selection.baseOffset < 0 ? localCtrl.document.length : localCtrl.selection.baseOffset;
        localCtrl.replaceText(index, 0, quill.BlockEmbed.image(tmpPath), TextSelection.collapsed(offset: index + 1));
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return StandardDialog(
            title: 'Editar comentário',
            width: StandardDialog.widthMedium,
            height: StandardDialog.heightMedium,
            showCloseButton: false,
            isLoading: saving,
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: saving ? null : () async {
                  setS(() => saving = true);
                  try {
                    // Process ops and upload local images
                    final List<Map<String, dynamic>> ops = List<Map<String, dynamic>>.from(localCtrl.document.toDelta().toJson());
                    final usedNames = <String>{};
                    String uniqueName(String base) {
                      var candidate = base;
                      var i = 1;
                      while (usedNames.contains(candidate)) {
                        final dot = candidate.lastIndexOf('.');
                        final b = dot >= 0 ? candidate.substring(0, dot) : candidate;
                        final ext = dot >= 0 ? candidate.substring(dot) : '';
                        candidate = '$b ($i)$ext';
                        i++;
                      }
                      usedNames.add(candidate);
                      return candidate;
                    }

                    Future<auth.AuthClient?> ensureClient() async {
                      try { return await _drive.getAuthedClient(); } on ConsentRequired catch (_) {
                        final ok = await showDialog<bool>(context: context, builder: (_) => DriveConnectDialog(service: _drive));
                        if (ok == true) return await _drive.getAuthedClient();
                      } catch (_) {}
                      return null;
                    }

                    auth.AuthClient? client;
                    for (var i = 0; i < ops.length; i++) {
                      final op = ops[i];
                      final insert = op['insert'];
                      if (insert is Map && insert.containsKey('image')) {
                        final src = insert['image']?.toString() ?? '';
                        final isLocal = src.startsWith('data:') || src.startsWith('file://') || _isAbsolutePath(src);
                        if (!isLocal) continue;
                        client ??= await ensureClient();
                        if (client == null) throw Exception('Conecte o Google Drive para enviar imagens nos comentários');

                        List<int> bytes;
                        String ext;
                        String mimeType;
                        if (src.startsWith('data:')) {
                          final headerEnd = src.indexOf(',');
                          final header = headerEnd > 0 ? src.substring(5, headerEnd) : 'image/png;base64';
                          final mt = header.split(';').first;
                          ext = mt.split('/').last;
                          bytes = base64Decode(src.substring(headerEnd + 1));
                          mimeType = mt;
                        } else {
                          final path = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
                          final file = File(path);
                          bytes = await file.readAsBytes();
                          final mt = mime.lookupMimeType(path) ?? 'image/png';
                          ext = mt.split('/').last;
                          mimeType = mt;
                        }

                        String originalName;
                        if (src.startsWith('file://') || _isAbsolutePath(src)) {
                          final filePath = src.startsWith('file://') ? Uri.parse(src).toFilePath() : src;
                          originalName = filePath.split(RegExp(r"[\\/]")).last;
                        } else {
                          originalName = 'Comentario_image.$ext';
                        }
                        if (!originalName.toLowerCase().startsWith('comentario_')) {
                          originalName = 'Comentario_$originalName';
                        }
                        final filename = uniqueName(originalName);

                        final clientName = (widget.task['projects']?['clients']?['name'] ?? 'Cliente').toString();
                        final projectName = (widget.task['projects']?['name'] ?? 'Projeto').toString();
                        final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();
                        final up = await _drive.uploadToTaskSubfolder(
                          client: client,
                          clientName: clientName,
                          projectName: projectName,
                          taskName: taskTitle,
                          subfolderName: 'Comentarios',
                          filename: filename,
                          bytes: bytes,
                          mimeType: mimeType,
                        );
                        await _filesRepo.saveFile(
                          taskId: widget.task['id'] as String,
                          filename: filename,
                          sizeBytes: bytes.length,
                          mimeType: mimeType,
                          driveFileId: up.id,
                          driveFileUrl: up.publicViewUrl,
                          category: 'comment',
                          commentId: c['id'] as String,
                        );
                        op['insert'] = { 'image': up.publicViewUrl };
                        ops[i] = op;
                      }
                    }

                    final contentJson = jsonEncode(ops);
                    await _commentsRepo.updateComment(id: c['id'] as String, content: contentJson);
                    if (!mounted) return;
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    setS(() => saving = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                    return;
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 260,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: quill.QuillEditor.basic(
                      controller: localCtrl,
                      config: quill.QuillEditorConfig(
                        customStyles: chatDefaultStyles(ctx),
                        embedBuilders: [
                          ChatImageEmbedBuilder(
                            imageProviderBuilder: _quillImageProvider,
                            onDownload: (_, src) => _openDownloadFromSrc(src),
                            onRemove: (_, src) {
                              final ops = List<Map<String, dynamic>>.from(localCtrl.document.toDelta().toJson());
                              final newOps = <Map<String, dynamic>>[];
                              var removed = false;
                              for (final op in ops) {
                                final ins = op['insert'];
                                if (!removed && ins is Map && ins['image'] == src) { removed = true; continue; }
                                newOps.add(Map<String, dynamic>.from(op));
                              }
                              setS(() {
                                localCtrl = quill.QuillController(
                                  document: quill.Document.fromJson(newOps),
                                  selection: const TextSelection.collapsed(offset: 0),
                                );
                              });
                            },
                          ),
                          ...FlutterQuillEmbeds.editorBuilders(
                            imageEmbedConfig: QuillEditorImageEmbedConfig(
                              onImageClicked: (_) {},
                              imageProviderBuilder: _quillImageProvider,
                            ),
                          ).where((b) => b.key != 'image'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 8, children: [
                    FilledButton.icon(onPressed: saving ? null : insertImages, icon: const Icon(Icons.image), label: const Text('Inserir imagem')),
                  ]),
                )
              ],
            ),
          );
        });
      },
    );

    if (saved == true) {
      await _reload();
    }
  }

  void _cancelCompose() {
    FocusScope.of(context).unfocus();
    setState(() {
      _ctrl = quill.QuillController.basic();
      _ctrl.addListener(_onEditorChanged);
      _composeEmpty = true;
      _composeHeight = 120;
      _pending.clear();
      _error = null;
    });
  }


  @override
  void dispose() {
    _ctrl.removeListener(_onEditorChanged);
    _text.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Comentários', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (_sending) const SizedBox(width: 100, child: LinearProgressIndicator()),
          ]),
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final c in _comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final avatarUrl = c['user_profile']?['avatar_url'] as String?;
                          return CircleAvatar(
                            radius: 10,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(Icons.person, size: 12)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c['user_profile']?['full_name'] ?? c['user_profile']?['email'] ?? 'Usuário',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Builder(builder: (context) {
                        final app = AppStateScope.of(context);
                        final isAdmin = app.isAdminOrGestor;
                        final uid = Supabase.instance.client.auth.currentUser?.id;
                        final isOwner = uid != null && c['user_id'] == uid;
                        final canManage = isAdmin || isOwner;
                        if (!canManage) return const SizedBox.shrink();
                        return Row(mainAxisSize: MainAxisSize.min, children: [
                          IconOnlyButton(icon: Icons.edit, tooltip: 'Editar', onPressed: () => _editComment(c)),
                          IconOnlyButton(icon: Icons.delete, tooltip: 'Excluir', onPressed: () => _deleteComment(c)),
                        ]);
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final raw = (c['content'] ?? '').toString();
                    Widget contentWidget;
                    try {
                      final decoded = raw.trim().startsWith('[') ? (jsonDecode(raw) as List) : null;
                      if (decoded != null) {
                        final doc = quill.Document.fromJson(decoded);
                        final localCtrl = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
                        contentWidget = Directionality(
                          textDirection: TextDirection.ltr,
                          child: quill.QuillEditor.basic(
                            controller: localCtrl,
                            config: quill.QuillEditorConfig(
                              customStyles: chatDefaultStyles(context),
                              embedBuilders: [
                                ChatImageEmbedBuilder(imageProviderBuilder: _quillImageProvider, onDownload: (_, src) => _openDownloadFromSrc(src)),
                                ...FlutterQuillEmbeds.editorBuilders(
                                  imageEmbedConfig: const QuillEditorImageEmbedConfig(onImageClicked: null),
                                ).where((b) => b.key != 'image'),
                              ],
                            ),
                          ),
                        );
                      } else {
                        contentWidget = Text(raw);
                      }
                    } catch (_) {
                      contentWidget = Text(raw);
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      contentWidget,
                      const SizedBox(height: 4),
                      Text(_formatDate(c['created_at']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]);
                  }),
                ],
              ),
            ),
          const Divider(),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Novo comentário', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: _composeHeight + 56,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        bottom: 56,
                        child: Stack(children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: quill.QuillEditor.basic(
                              controller: _ctrl,
                              config: quill.QuillEditorConfig(
                                customStyles: chatDefaultStyles(context),
                                embedBuilders: [
                                  ChatImageEmbedBuilder(
                                    imageProviderBuilder: _quillImageProvider,
                                    onRemove: (_, src) => _removeCommentImage(src),
                                    onDownload: (_, src) => _openDownloadFromSrc(src),
                                  ),
                                  ...FlutterQuillEmbeds.editorBuilders(
                                    imageEmbedConfig: QuillEditorImageEmbedConfig(
                                      onImageClicked: (_) {},
                                      imageProviderBuilder: _quillImageProvider,
                                    ),
                                  ).where((b) => b.key != 'image'),
                                ],
                              ),
                            ),
                          ),
                          if (_composeEmpty)
                            IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Escreva um comentário ou insira uma imagem...'.trim(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                        ]),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(children: [
                          FilledButton.icon(onPressed: _pickImages, icon: const Icon(Icons.image), label: const Text('Inserir imagem')),
                          const Spacer(),
                          TextButton(onPressed: _sending ? null : _cancelCompose, child: const Text('Cancelar')),
                          const SizedBox(width: 8),
                          FilledButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send), label: const Text('Enviar')),
                        ]),
                      ),
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
}

