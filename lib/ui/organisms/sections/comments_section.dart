import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../editors/generic_block_editor.dart';
import '../../atoms/buttons/buttons.dart';

import '../../molecules/containers/containers.dart';

import '../../../src/state/app_state_scope.dart';

import '../../../modules/comments/module.dart';
import '../../../services/task_files_repository.dart';
import '../../../services/google_drive_oauth_service.dart';
import '../../../services/mentions_service.dart';
import '../../../utils/auto_scroll_helper.dart';

class CommentsSection extends StatefulWidget {
  final Map<String, dynamic>
      task; // must include id, title, projects: { name, clients: { name } }
  final ScrollController? pageScrollController;
  const CommentsSection(
      {super.key, required this.task, this.pageScrollController});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _filesRepo = TaskFilesRepository();
  final _drive = GoogleDriveOAuthService();

  final GenericBlockEditorController _composeEditorCtl =
      GenericBlockEditorController();
  final GlobalKey _composeFieldKey = GlobalKey();

  final GlobalKey _emojiPickerKey = GlobalKey();

  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();

  List<Map<String, dynamic>> get _combinedItems =>
      [..._comments, ..._pendingComments];

  bool _sending = false;
  String? _error;
  final List<Map<String, dynamic>> _comments = [];

  bool _composeEmpty = true;
  String _composeJson = '';
  final List<Map<String, dynamic>> _pendingComments = [];

  bool _isDragging = false;

  // ===== Debug: logging da posição do Scroll da página =====
  ScrollController? _observedPageCtrl;
  VoidCallback? _pageScrollLogListener;
  double? _lastMaxExtent;
  bool _shrinkFixPending = false;
  bool _growFixPending = false;

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
      return null;
    }
  }

  Future<String?> _fetchParentTaskTitle(String taskId) async {
    try {
      final row = await Supabase.instance.client
          .from('tasks')
          .select('parent_task_id, parent:parent_task_id(title)')
          .eq('id', taskId)
          .maybeSingle();
      final parent = row?['parent'] as Map?;
      final title = parent?['title'] as String?;
      return (title != null && title.trim().isNotEmpty) ? title : null;
    } catch (e) {
      return null;
    }
  }

  void _attachPageScrollLogger() {
    final next = widget.pageScrollController;
    if (_observedPageCtrl == next) return;
    // Remove antigo
    if (_observedPageCtrl != null && _pageScrollLogListener != null) {
      _observedPageCtrl!.removeListener(_pageScrollLogListener!);
    }
    _observedPageCtrl = next;
    if (_observedPageCtrl == null) return;
    _pageScrollLogListener = () {
      if (!mounted ||
          _observedPageCtrl == null ||
          !_observedPageCtrl!.hasClients) {
        return;
      }
      final pos = _observedPageCtrl!.position;
      try {
        final prevMax = _lastMaxExtent;
        final currMax = pos.maxScrollExtent;
        // Detecta encolhimento significativo do conteúdo quando estamos no fim
        if (prevMax != null &&
            currMax + 1.0 < prevMax &&
            pos.pixels + 8.0 >= currMax) {
          if (!_shrinkFixPending) {
            _shrinkFixPending = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _shrinkFixPending = false;
              _scrollToComposeField(allowUpIfShrink: true);
            });
          }
        }
        // Detecta crescimento do conteúdo quando estamos no fim (realinha para baixo)
        if (prevMax != null &&
            currMax > prevMax + 1.0 &&
            pos.pixels + 24.0 >= prevMax - 16.0) {
          if (!_growFixPending) {
            _growFixPending = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _growFixPending = false;
              _scrollToComposeField(allowUpIfShrink: false);
            });
          }
        }
        _lastMaxExtent = currMax;
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    };
    _observedPageCtrl!.addListener(_pageScrollLogListener!);
    // Log de acoplamento após o primeiro frame (garante métricas disponíveis)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (_observedPageCtrl != null && _observedPageCtrl!.hasClients) {
          final pos = _observedPageCtrl!.position;
          _lastMaxExtent = pos.maxScrollExtent; // baseline inicial
        } else {}
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    });
  }

  // ===== Helpers: arquivos de imagem em comentários =====
  List<Map<String, String>> _extractDriveFilesFromContent(String contentJson) {
    final results = <Map<String, String>>[];
    try {
      final data = jsonDecode(contentJson) as Map<String, dynamic>;
      final blocks = (data['blocks'] as List?) ?? [];
      for (final b in blocks) {
        if (b is! Map) continue;
        final type = (b['type'] ?? 'text').toString();
        if (type != 'image') continue;
        var raw = b['content'];
        String? url;
        if (raw is String) {
          try {
            final d = jsonDecode(raw);
            if (d is Map && d['url'] is String) {
              url = d['url'];
            } else {
              url = raw;
            }
          } catch (_) {
            url = raw;
          }
        } else if (raw is Map) {
          final u = raw['url'];
          if (u is String) {
            url = u;
          }
        }
        if (url == null) continue;
        if (!url.contains('drive.google.com')) continue;
        try {
          final uri = Uri.parse(url);
          final id = uri.queryParameters['id'];
          if (id != null && id.isNotEmpty) {
            results.add({'id': id, 'url': url});
          }
        } catch (_) {}
        // Ignorar erro (operação não crítica)
      }
    } catch (_) {}
    return results;
  }

  Future<void> _persistCommentFiles(Map<String, dynamic> comment) async {
    try {
      final content = (comment['content'] ?? '').toString();
      final pairs = _extractDriveFilesFromContent(content);
      if (pairs.isEmpty) return;

      final commentId = comment['id'] as String;
      final existing = await _filesRepo.listByComment(commentId);
      final existingIds =
          existing.map((e) => (e['drive_file_id'] ?? '').toString()).toSet();

      var idx = 1;
      for (final p in pairs) {
        final id = p['id']!;
        if (existingIds.contains(id)) continue;

        // Tenta encontrar registro temporário (comment_image)
        final tempFile = await Supabase.instance.client
            .from('task_files')
            .select()
            .eq('drive_file_id', id)
            .eq('category', 'comment_image')
            .maybeSingle();

        if (tempFile != null) {
          // Atualiza registro existente
          await _filesRepo.updateCommentId(tempFile['id'] as String, commentId);
        } else {
          // Cria novo registro (legado/fallback)
          final url = p['url'];
          await _filesRepo.saveFile(
            taskId: widget.task['id'] as String,
            filename: 'Comentario-$commentId-$idx',
            sizeBytes: 0,
            mimeType: null,
            driveFileId: id,
            driveFileUrl: url,
            category: 'comment',
            commentId: commentId,
          );
        }
        idx++;
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  // Edit state (usa o composer principal)
  String? _editingCommentId;

  // Emoji picker state
  bool _showingEmojiPicker = false;
  // Flag para garantir segundo passe de scroll em inserção de imagem (imagem carrega altura depois)
  bool _imageInsertionInProgress = false;

  void _onEditorChanged(String json) {
    _composeJson = json;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final blocks = (data['blocks'] as List?) ?? [];
      final empty =
          blocks.every((b) => (b['content'] ?? '').toString().trim().isEmpty);

      if (empty != _composeEmpty) {
        if (!mounted) return;
        setState(() {
          _composeEmpty = empty;
        });
      }

      // Sempre fazer scroll após mudanças para acompanhar o conteúdo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToComposeField();
      });
      // Se foi inserção de imagem, faz um segundo passe pequeno para capturar crescimento
      if (_imageInsertionInProgress) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToComposeField();
          });
        });
        _imageInsertionInProgress = false;
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  void _scrollToComposeField({bool allowUpIfShrink = false}) {
    // Garantir compositor visível, respeitando overlays (ex.: emoji picker)
    final pos = _findScrollPosition();
    if (pos != null) {
      // altura aproximada do picker
      // margem mínima quando não há overlay
      // Se detectarmos encolhimento recente e estamos colados no fim, permitir subir para recolocar o compositor
      final prevMax = _lastMaxExtent;
      final currMax = pos.maxScrollExtent;
      bool finalAllowUp = allowUpIfShrink;
      if (!finalAllowUp &&
          prevMax != null &&
          currMax + 1.0 < prevMax &&
          pos.pixels + 8.0 >= currMax) {
        finalAllowUp = true;
      }

      // Estratégia: rolar até o final absoluto (maxScrollExtent) para garantir que todo o compositor fique visível
      // Isso é especialmente importante com o SliverPadding que adiciona espaço extra
      final target = currMax;
      final current = pos.pixels;
      final delta = (target - current).abs();

      // Só rola se necessário (não está já no final ou se allowUp está ativo)
      if (finalAllowUp || delta >= 1.0) {
        if (delta < 24.0) {
          pos.jumpTo(target);
        } else {
          pos.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      } else {}

      // Passo de estabilização: após permitir subida por encolhimento, faz um segundo ensure sem subir
      if (finalAllowUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final p2 = _findScrollPosition();
          if (p2 != null) {
            final currMax2 = p2.maxScrollExtent;
            final delta2 = (currMax2 - p2.pixels).abs();
            if (delta2 >= 1.0) {
              if (delta2 < 24.0) {
                p2.jumpTo(currMax2);
              } else {
                p2.animateTo(
                  currMax2,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                );
              }
            }
            _lastMaxExtent = currMax2;
          }
        });
      }
      _lastMaxExtent = currMax; // mantenha baseline atualizada
    } else {}
  }

  @override
  void initState() {
    super.initState();
    _composeEmpty = true;
    // Anexa o logger de scroll no prximo frame para evitar mtricas nulas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachPageScrollLogger();
    });
    _reload();
  }

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageScrollController != widget.pageScrollController) {}
    _attachPageScrollLogger();
  }

  @override
  void dispose() {
    if (_observedPageCtrl != null && _pageScrollLogListener != null) {
      _observedPageCtrl!.removeListener(_pageScrollLogListener!);
    }
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await commentsModule.listByTask(widget.task['id'] as String);
      if (!mounted) return;
      // Insere os itens após o primeiro frame para permitir animação inicial
      _comments.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (int i = 0; i < list.length; i++) {
          _comments.add(list[i]);
          _listKey.currentState?.insertItem(
            1 + i, // após o header
            duration: const Duration(milliseconds: 120),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  // Métodos de emoji e imagem removidos - agora gerenciados pelo CommentEditor

  // Métodos auxiliares removidos - agora gerenciados pelo CommentEditor

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

  String _buildDateText(dynamic createdAt, dynamic updatedAt) {
    final createdStr = _formatDate(createdAt);

    // Verificar se foi editado comparando as datas
    if (updatedAt == null) return createdStr;

    final createdDt = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    final updatedDt = updatedAt is DateTime
        ? updatedAt
        : (updatedAt is String ? DateTime.tryParse(updatedAt) : null);

    if (createdDt == null || updatedDt == null) return createdStr;

    // Se a diferença for maior que 1 segundo, considera editado
    final diff = updatedDt.difference(createdDt).inSeconds;
    if (diff > 1) {
      final updatedStr = _formatDate(updatedAt);
      return '$createdStr • editado em $updatedStr';
    }

    return createdStr;
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    // Guardar conteúdo atual para possível restauração em caso de erro
    final originalJson = _composeJson;
    try {
      // Verificar se há conteúdo
      final data = jsonDecode(_composeJson) as Map<String, dynamic>;
      final blocks = (data['blocks'] as List?) ?? [];
      final isEmpty =
          blocks.every((b) => (b['content'] ?? '').toString().trim().isEmpty);

      if (isEmpty) {
        setState(() {
          _sending = false;
          _error = 'Comentário vazio';
        });
        return;
      }

      // Inserir placeholder otimista no topo e limpar o editor imediatamente
      if (_editingCommentId != null) {
        // Marcamos o comentário existente como pendente e atualizamos o conteúdo visível
        final idx = _comments.indexWhere((c) => c['id'] == _editingCommentId);
        if (idx >= 0) {
          final copy = Map<String, dynamic>.from(_comments[idx]);
          copy['content'] = originalJson;
          copy['pending'] = true;
          copy['updated_at'] = DateTime.now().toIso8601String();
          setState(() {
            _comments[idx] = copy;
          });
        }
      } else {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final app = AppStateScope.of(context);
        final profile = app.profile;
        final email = (profile?['email'] ??
                Supabase.instance.client.auth.currentUser?.email ??
                'Você')
            .toString();
        final fullName = (profile?['full_name'] ?? 'Você').toString();
        final avatarUrl = profile?['avatar_url'] as String?;

        final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
        final pending = <String, dynamic>{
          'id': pendingId,
          'content': originalJson,
          'user_id': uid,
          'user_profile': {
            'full_name': fullName,
            'email': email,
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              'avatar_url': avatarUrl,
          },
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': null,
          'pending': true,
        };
        final bool shouldAuto = _isNearBottom();
        final int insertIdx = 1 + _combinedItems.length;
        setState(() {
          _pendingComments.add(pending);
        });
        _listKey.currentState?.insertItem(
          insertIdx,
          duration: const Duration(milliseconds: 220),
        );
        if (shouldAuto) {
          _autoScrollToBottomSoon();
        }
        // Processa este envio em background
        final clientName =
            (widget.task['projects']?['clients']?['name'] ?? 'Cliente')
                .toString();
        final projectName =
            (widget.task['projects']?['name'] ?? 'Projeto').toString();
        final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();
        Future(() async {
          try {
            final companyName =
                await _fetchCompanyNameForTask(widget.task['id'] as String);
            final bool isSubTask =
                (widget.task['parent_task_id'] as String?) != null;
            String effectiveTaskTitle = taskTitle;
            String? subTaskTitle;
            if (isSubTask) {
              final parentTitle =
                  await _fetchParentTaskTitle(widget.task['id'] as String);
              if (parentTitle != null && parentTitle.trim().isNotEmpty) {
                effectiveTaskTitle = parentTitle;
              }
              subTaskTitle = taskTitle; // o título atual é da Subtarefa
            }
            final contentJson = await _composeEditorCtl.uploadCachedImages(
              clientName: clientName,
              projectName: projectName,
              taskTitle: effectiveTaskTitle,
              companyName: companyName,
              subTaskTitle: subTaskTitle,
              subfolderName: 'Comentarios',
              filePrefix: 'Comentario',
              overrideJson: originalJson,
            );
            final created = await commentsModule.createComment(
              taskId: widget.task['id'] as String,
              content: contentJson,
            );
            if (!mounted) return;

            // Salvar menções do comentário
            try {
              await mentionsService.saveCommentMentions(
                commentId: created['id'] as String,
                content: contentJson,
              );
            } catch (e) {
              // Ignorar erro (operação não crítica)
            }
            // Remove o pendente com animação e insere o criado
            final current = _combinedItems;
            final idx = current.indexWhere((c) => c['id'] == pendingId);
            if (idx >= 0) {
              final removed = Map<String, dynamic>.from(current[idx]);
              _pendingComments.removeWhere((c) => c['id'] == pendingId);
              _listKey.currentState?.removeItem(
                1 + idx,
                (ctx, a) => FadeTransition(
                  opacity: a,
                  child: SizeTransition(
                    sizeFactor: a,
                    axisAlignment: -1.0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCommentCard(ctx, removed),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 180),
              );
            }
            // Enriquecer com perfil local para exibição imediata
            created['user_profile'] ??= {
              'full_name': fullName,
              'email': email,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'avatar_url': avatarUrl,
            };
            final insertAt = 1 + _combinedItems.length;
            _comments.add(created);
            _listKey.currentState?.insertItem(
              insertAt,
              duration: const Duration(milliseconds: 220),
            );
            // Persistir metadados dos arquivos de imagem (para cleanup no delete)
            // N {o aguardar para n {o travar a UI
            Future(() async {
              await _persistCommentFiles(created);
            });
            if (_isNearBottom()) {
              _autoScrollToBottomSoon();
            }
          } catch (e) {
            if (!mounted) return;
            // Falha: remove pendente e restaura conteúdo
            final current = _combinedItems;
            final idx = current.indexWhere((c) => c['id'] == pendingId);
            if (idx >= 0) {
              final removed = Map<String, dynamic>.from(current[idx]);
              _pendingComments.removeWhere((c) => c['id'] == pendingId);
              _listKey.currentState?.removeItem(
                1 + idx,
                (ctx, a) => FadeTransition(
                  opacity: a,
                  child: SizeTransition(
                    sizeFactor: a,
                    axisAlignment: -1.0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCommentCard(ctx, removed),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 180),
              );
            }
            // Mensagem mais amigável para erro de Google Drive não conectado
            String errorMessage = 'Falha ao enviar: $e';
            if (e.toString().contains('Consentimento necessário') ||
                e.toString().contains('ConsentRequired')) {
              errorMessage =
                  'Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações.';
            }

            setState(() {
              _error = errorMessage;
            });
            if (_composeEmpty) {
              _composeEditorCtl.setJson(originalJson);
              _composeJson = originalJson;
              _composeEmpty = false;
            }
          }
        });
      }

      // Limpar o compositor imediatamente para dar sensação de fluidez
      _composeEditorCtl.clear();
      _composeJson = '';
      _composeEmpty = true;
      _showingEmojiPicker = false;
      if (mounted) setState(() {});

      // Upload de imagens em cache para Google Drive
      final clientName =
          (widget.task['projects']?['clients']?['name'] ?? 'Cliente')
              .toString();
      final projectName =
          (widget.task['projects']?['name'] ?? 'Projeto').toString();
      final taskTitle = (widget.task['title'] ?? 'Tarefa').toString();

      if (_editingCommentId != null) {
        // Fluxo de edição: mantém comportamento síncrono para evitar conflitos
        final companyName =
            await _fetchCompanyNameForTask(widget.task['id'] as String);
        final bool isSubTask =
            (widget.task['parent_task_id'] as String?) != null;
        String effectiveTaskTitle = taskTitle;
        String? subTaskTitle;
        if (isSubTask) {
          final parentTitle =
              await _fetchParentTaskTitle(widget.task['id'] as String);
          if (parentTitle != null && parentTitle.trim().isNotEmpty) {
            effectiveTaskTitle = parentTitle;
          }
          subTaskTitle = taskTitle;
        }
        final contentJson = await _composeEditorCtl.uploadCachedImages(
          clientName: clientName,
          projectName: projectName,
          taskTitle: effectiveTaskTitle,
          companyName: companyName,
          subTaskTitle: subTaskTitle,
          subfolderName: 'Comentarios',
          filePrefix: 'Comentario',
          overrideJson: originalJson,
        );
        final updated = await commentsModule.updateComment(
          commentId: _editingCommentId!,
          content: contentJson,
        );
        if (mounted) {
          setState(() {
            final idx =
                _comments.indexWhere((c) => c['id'] == _editingCommentId);
            if (idx >= 0) {
              final keepProfile = _comments[idx]['user_profile'];
              updated['user_profile'] = keepProfile;
              _comments[idx] = updated;
            }
            _editingCommentId = null;
          });
          // Sincronizar registros de arquivos "best-effort": adiciona entradas ausentes
          Future(() async {
            await _persistCommentFiles(updated);
          });
        }
      }
    } catch (e) {
      // Restaurar conteúdo apenas se o compositor estiver vazio (não sobrescrever rascunho atual)
      String errorMessage = 'Falha ao enviar: $e';

      // Mensagem mais amigável para erro de Google Drive não conectado
      if (e.toString().contains('Consentimento necessário') ||
          e.toString().contains('ConsentRequired')) {
        errorMessage =
            'Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações.';
      }

      setState(() {
        _error = errorMessage;
      });
      if (_composeEmpty) {
        _composeEditorCtl.setJson(originalJson);
        _composeJson = originalJson;
        _composeEmpty = false;
      }
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) {
      try {
        // 1. Buscar anexos do comentário
        final files = await _filesRepo.listByComment(c['id'] as String);

        // 2. Deletar anexos do Google Drive (registros no DB)
        final removedIds = <String>{};
        if (files.isNotEmpty) {
          try {
            final client = await _drive.getAuthedClient();
            for (final file in files) {
              final driveFileId = file['drive_file_id'] as String?;
              if (driveFileId != null && driveFileId.isNotEmpty) {
                removedIds.add(driveFileId);
                try {
                  await _drive.deleteFile(
                      client: client, driveFileId: driveFileId);
                } catch (e) {
                  // Continua mesmo se falhar no Drive
                }
              }

              // Deletar do banco de dados
              await _filesRepo.delete(file['id'] as String);
            }
          } catch (e) {
            // Continua mesmo se falhar
          }
        }

        // 2b. Fallback legado: deletar quaisquer imagens referenciadas no conteúdo
        try {
          final content = (c['content'] ?? '').toString();
          final pairs = _extractDriveFilesFromContent(content);
          if (pairs.isNotEmpty) {
            final client = await _drive.getAuthedClient();
            for (final p in pairs) {
              final id = p['id'];
              if (id == null || id.isEmpty) continue;
              if (removedIds.contains(id)) {
                continue; // já removido via registros
              }
              try {
                await _drive.deleteFile(client: client, driveFileId: id);
              } catch (e) {
                // Ignorar erro (operação não crítica)
              }
            }
          }
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }

        // 3. Deletar comentário
        await commentsModule.deleteComment(c['id'] as String);

        if (mounted) {
          final current = _combinedItems;
          final idx = current.indexWhere((e) => e['id'] == c['id']);
          if (idx >= 0) {
            final removed = Map<String, dynamic>.from(current[idx]);
            setState(() {
              _comments.removeWhere((e) => e['id'] == c['id']);
            });
            _listKey.currentState?.removeItem(
              1 + idx,
              (ctx, a) => FadeTransition(
                opacity: a,
                child: SizeTransition(
                  sizeFactor: a,
                  axisAlignment: -1.0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCommentCard(ctx, removed),
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 180),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao deletar comentário: $e')),
          );
        }
      }
    }
  }

  // Start inline editing of a comment
  void _startEditComment(Map<String, dynamic> c) {
    final raw = (c['content'] ?? '').toString();

    // Entra em modo edição usando o composer principal
    setState(() {
      _editingCommentId = c['id'] as String;
      _showingEmojiPicker = false;
    });

    // Carrega o conteúdo no editor principal
    _composeEditorCtl.setJson(raw);
    _composeJson = raw;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final blocks = (data['blocks'] as List?) ?? [];
      _composeEmpty =
          blocks.every((b) => (b['content'] ?? '').toString().trim().isEmpty);
    } catch (_) {
      _composeEmpty = false;
    }

    // Garante que o composer esteja visível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToComposeField();
    });
  }

  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> c) {
    return Column(
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
              c['user_profile']?['full_name'] ??
                  c['user_profile']?['email'] ??
                  'Usuário',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Builder(builder: (context) {
              final app = AppStateScope.of(context);
              final isAdmin = app.isAdminOrGestor;
              final uid = Supabase.instance.client.auth.currentUser?.id;
              final isOwner = uid != null && c['user_id'] == uid;
              final canManage = isAdmin || isOwner;
              if (!canManage || (c['pending'] == true)) {
                return const SizedBox.shrink();
              }
              return Row(mainAxisSize: MainAxisSize.min, children: [
                IconOnlyButton(
                    icon: Icons.edit,
                    tooltip: 'Editar',
                    onPressed: () => _startEditComment(c)),
                IconOnlyButton(
                    icon: Icons.delete,
                    tooltip: 'Excluir',
                    onPressed: () => _deleteComment(c)),
              ]);
            }),
          ],
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: c['pending'] == true ? 0.7 : 1.0,
          child: SelectableContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GenericBlockEditor(
                  initialJson: (c['content'] ?? '').toString(),
                  enabled: false,
                  showToolbar: false,
                  isUploading: c['pending'] == true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildDateText(c['created_at'], c['updated_at']),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerCard(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) async {
        setState(() => _isDragging = false);

        // Processar apenas arquivos de imagem
        for (final file in details.files) {
          final path = file.path;
          final extension = path.toLowerCase().split('.').last;

          // Verificar se é imagem
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']
              .contains(extension)) {
            await _composeEditorCtl.addImageFromPath(path);
          }
        }
      },
      child: Container(
        key: _composeFieldKey,
        decoration: BoxDecoration(
          color: _isDragging
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: _isDragging
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: _isDragging ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingCommentId != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit,
                          size: 16, color: Color(0xFF9AA0A6)),
                      const SizedBox(width: 6),
                      Text(
                        'Editando comentário...',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            GenericBlockEditor(
              initialJson: _composeJson.isNotEmpty ? _composeJson : null,
              controller: _composeEditorCtl,
              enabled: true,
              onChanged: _onEditorChanged,
              showToolbar: false,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconOnlyButton(
                  icon: Icons.text_fields,
                  tooltip: 'Adicionar texto',
                  onPressed: () => _composeEditorCtl.addTextBlock(),
                ),
                const SizedBox(width: 8),
                IconOnlyButton(
                  icon: Icons.check_box_outlined,
                  tooltip: 'Adicionar checkbox',
                  onPressed: () => _composeEditorCtl.addCheckboxBlock(),
                ),
                const SizedBox(width: 8),
                IconOnlyButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Inserir imagem',
                  onPressed: () {
                    setState(() {
                      _imageInsertionInProgress = true;
                    });
                    _composeEditorCtl.pickImage();
                  },
                ),
                const SizedBox(width: 8),
                IconOnlyButton(
                  icon: Icons.table_chart_outlined,
                  tooltip: 'Adicionar tabela',
                  onPressed: () => _composeEditorCtl.addTableBlock(),
                ),
                const SizedBox(width: 8),
                IconOnlyButton(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: 'Inserir emoji',
                  onPressed: _showEmojiPicker,
                ),
                const Spacer(),
                if (_editingCommentId != null) ...[
                  TextButton(
                    onPressed: _sending ? null : _cancelEditComment,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending || _composeEmpty ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar'),
                  ),
                ] else ...[
                  Builder(builder: (context) {
                    return _SendButton(
                      onPressed: _composeEmpty ? null : _send,
                      enabled: !_composeEmpty,
                    );
                  }),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Cancel inline editing
  void _cancelEditComment() {
    // Sai do modo edição usando o composer principal e limpa o campo

    _composeEditorCtl.clear();
    _composeJson = '';
    _composeEmpty = true;
    _editingCommentId = null;
  }

  // Métodos de emoji e imagem de edição removidos - agora gerenciados pelo CommentEditor

  void _showEmojiPicker() {
    setState(() {
      _showingEmojiPicker = !_showingEmojiPicker;
    });
    if (_showingEmojiPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AutoScrollHelper.scrollToPicker(
          key: _emojiPickerKey,
          enableDebugLogs: false,
        );
      });
    }
  }

  void _onEmojiSelected(String emoji) {
    _composeEditorCtl.insertEmoji(emoji);
    setState(() {
      _showingEmojiPicker = false;
    });
  }

  ScrollPosition? _findScrollPosition() {
    try {
      final preferred = widget.pageScrollController;
      if (preferred != null && preferred.hasClients) {
        return preferred.position;
      }
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        return scrollable.position;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isNearBottom([double threshold = 96]) {
    final p = _findScrollPosition();
    if (p == null) return false;
    final remaining = p.maxScrollExtent - p.pixels;
    return remaining <= threshold;
  }

  void _autoScrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = _findScrollPosition();
      if (p == null) return;
      p.animateTo(
        p.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: 2, // header + composer
      itemBuilder: (context, index, animation) {
        final combined = _combinedItems;
        final composerIndex = 1 + combined.length;
        if (index == 0) {
          // Header + erros
          final child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Comentários',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
              ]),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
          );
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
                sizeFactor: animation, axisAlignment: -1.0, child: child),
          );
        }
        if (index == composerIndex) {
          final child = Column(
            children: [
              _buildComposerCard(context),
              if (_showingEmojiPicker) ...[
                const SizedBox(height: 8),
                _CustomEmojiPicker(
                  key: _emojiPickerKey,
                  onEmojiSelected: _onEmojiSelected,
                ),
              ],
            ],
          );
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
                sizeFactor: animation, axisAlignment: -1.0, child: child),
          );
        }
        // Comentários
        final c = combined[index - 1];
        final child = Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCommentCard(context, c),
        );
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
              sizeFactor: animation, axisAlignment: -1.0, child: child),
        );
      },
    );
  }
}

/// Botão de enviar com hover effect (cinza -> branco)
class _SendButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool enabled;

  const _SendButton({
    required this.onPressed,
    required this.enabled,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Usa a mesma cor do hover do botão ghost/tab bar (0xFF2A2A2A)
    final backgroundColor = widget.enabled
        ? (_isHovered ? Colors.white : const Color(0xFF2A2A2A))
        : Theme.of(context).colorScheme.surfaceContainerHigh;

    final foregroundColor = widget.enabled
        ? (_isHovered ? Colors.black : Colors.white)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: IconButton(
        onPressed: widget.enabled
            ? () {
                widget.onPressed?.call();
              }
            : null,
        icon: const Icon(Icons.arrow_upward, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Emoji Picker customizado e minimalista
class _CustomEmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const _CustomEmojiPicker({
    super.key,
    required this.onEmojiSelected,
  });

  @override
  State<_CustomEmojiPicker> createState() => _CustomEmojiPickerState();
}

class _CustomEmojiPickerState extends State<_CustomEmojiPicker> {
  int _selectedCategory = 0;

  // Categorias de emojis
  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.access_time,
      'label': 'Recentes',
      'emojis': ['😀', '😂', '❤️', '👍', '🎉', '🔥', '✨', '💯']
    },
    {
      'icon': Icons.emoji_emotions_outlined,
      'label': 'Smileys',
      'emojis': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '🤣',
        '😂',
        '🙂',
        '🙃',
        '😉',
        '😊',
        '😇',
        '🥰',
        '😍',
        '🤩',
        '😘',
        '😗',
        '😚',
        '😙',
        '🥲',
        '😋',
        '😛',
        '😜',
        '🤪',
        '😝',
        '🤑',
        '🤗',
        '🤭',
        '🤫',
        '🤔',
        '🤐',
        '🤨',
        '😐',
        '😑',
        '😶',
        '😏',
        '😒',
        '🙄',
        '😬',
        '🤥',
        '😌',
        '😔',
        '😪',
        '🤤',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🤢',
        '🤮',
        '🤧',
        '🥵',
        '🥶',
        '😶‍🌫️',
        '🥴',
        '😵',
        '🤯',
        '🤠',
        '🥳',
        '🥸',
        '😎',
        '🤓',
        '🧐'
      ]
    },
    {
      'icon': Icons.favorite_outline,
      'label': 'Gestos',
      'emojis': [
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝️',
        '👍',
        '👎',
        '✊',
        '👊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💅',
        '🤳',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👂',
        '🦻',
        '👃',
        '🧠',
        '🫀',
        '🫁',
        '🦷',
        '🦴',
        '👀',
        '👁️',
        '👅',
        '👄',
        '💋'
      ]
    },
    {
      'icon': Icons.pets,
      'label': 'Animais',
      'emojis': [
        '🐶',
        '🐱',
        '🐭',
        '🐹',
        '🐰',
        '🦊',
        '🐻',
        '🐼',
        '🐨',
        '🐯',
        '🦁',
        '🐮',
        '🐷',
        '🐽',
        '🐸',
        '🐵',
        '🙈',
        '🙉',
        '🙊',
        '🐒',
        '🐔',
        '🐧',
        '🐦',
        '🐤',
        '🐣',
        '🐥',
        '🦆',
        '🦅',
        '🦉',
        '🦇',
        '🐺',
        '🐗',
        '🐴',
        '🦄',
        '🐝',
        '🐛',
        '🦋',
        '🐌',
        '🐞',
        '🐜',
        '🦟',
        '🦗',
        '🕷️',
        '🦂',
        '🐢',
        '🐍',
        '🦎',
        '🦖',
        '🦕',
        '🐙',
        '🦑',
        '🦐',
        '🦞',
        '🦀',
        '🐡',
        '🐠',
        '🐟',
        '🐬',
        '🐳',
        '🐋',
        '🦈',
        '🐊',
        '🐅',
        '🐆',
        '🦓',
        '🦍',
        '🦧',
        '🐘',
        '🦛',
        '🦏',
        '🐪',
        '🐫',
        '🦒',
        '🦘',
        '🐃',
        '🐂',
        '🐄',
        '🐎',
        '🐖',
        '🐏',
        '🐑',
        '🦙',
        '🐐',
        '🦌',
        '🐕',
        '🐩',
        '🦮',
        '🐕‍🦺',
        '🐈',
        '🐈‍⬛',
        '🐓',
        '🦃',
        '🦚',
        '🦜',
        '🦢',
        '🦩',
        '🕊️',
        '🐇',
        '🦝',
        '🦨',
        '🦡',
        '🦦',
        '🦥',
        '🐁',
        '🐀',
        '🐿️',
        '🦔'
      ]
    },
    {
      'icon': Icons.fastfood,
      'label': 'Comida',
      'emojis': [
        '🍏',
        '🍎',
        '🍐',
        '🍊',
        '🍋',
        '🍌',
        '🍉',
        '🍇',
        '🍓',
        '🫐',
        '🍈',
        '🍒',
        '🍑',
        '🥭',
        '🍍',
        '🥥',
        '🥝',
        '🍅',
        '🍆',
        '🥑',
        '🥦',
        '🥬',
        '🥒',
        '🌶️',
        '🫑',
        '🌽',
        '🥕',
        '🫒',
        '🧄',
        '🧅',
        '🥔',
        '🍠',
        '🥐',
        '🥯',
        '🍞',
        '🥖',
        '🥨',
        '🧀',
        '🥚',
        '🍳',
        '🧈',
        '🥞',
        '🧇',
        '🥓',
        '🥩',
        '🍗',
        '🍖',
        '🦴',
        '🌭',
        '🍔',
        '🍟',
        '🍕',
        '🫓',
        '🥪',
        '🥙',
        '🧆',
        '🌮',
        '🌯',
        '🫔',
        '🥗',
        '🥘',
        '🫕',
        '🥫',
        '🍝',
        '🍜',
        '🍲',
        '🍛',
        '🍣',
        '🍱',
        '🥟',
        '🦪',
        '🍤',
        '🍙',
        '🍚',
        '🍘',
        '🍥',
        '🥠',
        '🥮',
        '🍢',
        '🍡',
        '🍧',
        '🍨',
        '🍦',
        '🥧',
        '🧁',
        '🍰',
        '🎂',
        '🍮',
        '🍭',
        '🍬',
        '🍫',
        '🍿',
        '🍩',
        '🍪',
        '🌰',
        '🥜',
        '🍯'
      ]
    },
    {
      'icon': Icons.sports_soccer,
      'label': 'Atividades',
      'emojis': [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🥎',
        '🎾',
        '🏐',
        '🏉',
        '🥏',
        '🎱',
        '🪀',
        '🏓',
        '🏸',
        '🏒',
        '🏑',
        '🥍',
        '🏏',
        '🪃',
        '🥅',
        '⛳',
        '🪁',
        '🏹',
        '🎣',
        '🤿',
        '🥊',
        '🥋',
        '🎽',
        '🛹',
        '🛼',
        '🛷',
        '⛸️',
        '🥌',
        '🎿',
        '⛷️',
        '🏂',
        '🪂',
        '🏋️',
        '🤼',
        '🤸',
        '🤺',
        '⛹️',
        '🤾',
        '🏌️',
        '🏇',
        '🧘',
        '🏊',
        '🤽',
        '🚣',
        '🧗',
        '🚴',
        '🚵',
        '🎪',
        '🎭',
        '🎨',
        '🎬',
        '🎤',
        '🎧',
        '🎼',
        '🎹',
        '🥁',
        '🪘',
        '🎷',
        '🎺',
        '🪗',
        '🎸',
        '🪕',
        '🎻',
        '🎲',
        '♟️',
        '🎯',
        '🎳',
        '🎮',
        '🎰',
        '🧩'
      ]
    },
    {
      'icon': Icons.flight,
      'label': 'Viagens',
      'emojis': [
        '🚗',
        '🚕',
        '🚙',
        '🚌',
        '🚎',
        '🏎️',
        '🚓',
        '🚑',
        '🚒',
        '🚐',
        '🛻',
        '🚚',
        '🚛',
        '🚜',
        '🦯',
        '🦽',
        '🦼',
        '🛴',
        '🚲',
        '🛵',
        '🏍️',
        '🛺',
        '🚨',
        '🚔',
        '🚍',
        '🚘',
        '🚖',
        '🚡',
        '🚠',
        '🚟',
        '🚃',
        '🚋',
        '🚞',
        '🚝',
        '🚄',
        '🚅',
        '🚈',
        '🚂',
        '🚆',
        '🚇',
        '🚊',
        '🚉',
        '✈️',
        '🛫',
        '🛬',
        '🛩️',
        '💺',
        '🛰️',
        '🚀',
        '🛸',
        '🚁',
        '🛶',
        '⛵',
        '🚤',
        '🛥️',
        '🛳️',
        '⛴️',
        '🚢',
        '⚓',
        '⛽',
        '🚧',
        '🚦',
        '🚥',
        '🚏',
        '🗺️',
        '🗿',
        '🗽',
        '🗼',
        '🏰',
        '🏯',
        '🏟️',
        '🎡',
        '🎢',
        '🎠',
        '⛲',
        '⛱️',
        '🏖️',
        '🏝️',
        '🏜️',
        '🌋',
        '⛰️',
        '🏔️',
        '🗻',
        '🏕️',
        '⛺',
        '🛖',
        '🏠',
        '🏡',
        '🏘️',
        '🏚️',
        '🏗️',
        '🏭',
        '🏢',
        '🏬',
        '🏣',
        '🏤',
        '🏥',
        '🏦',
        '🏨',
        '🏪',
        '🏫',
        '🏩',
        '💒',
        '🏛️',
        '⛪',
        '🕌',
        '🕍',
        '🛕',
        '🕋'
      ]
    },
    {
      'icon': Icons.lightbulb_outline,
      'label': 'Objetos',
      'emojis': [
        '⌚',
        '📱',
        '📲',
        '💻',
        '⌨️',
        '🖥️',
        '🖨️',
        '🖱️',
        '🖲️',
        '🕹️',
        '🗜️',
        '💽',
        '💾',
        '💿',
        '📀',
        '📼',
        '📷',
        '📸',
        '📹',
        '🎥',
        '📽️',
        '🎞️',
        '📞',
        '☎️',
        '📟',
        '📠',
        '📺',
        '📻',
        '🎙️',
        '🎚️',
        '🎛️',
        '🧭',
        '⏱️',
        '⏲️',
        '⏰',
        '🕰️',
        '⌛',
        '⏳',
        '📡',
        '🔋',
        '🔌',
        '💡',
        '🔦',
        '🕯️',
        '🪔',
        '🧯',
        '🛢️',
        '💸',
        '💵',
        '💴',
        '💶',
        '💷',
        '🪙',
        '💰',
        '💳',
        '💎',
        '⚖️',
        '🪜',
        '🧰',
        '🪛',
        '🔧',
        '🔨',
        '⚒️',
        '🛠️',
        '⛏️',
        '🪚',
        '🔩',
        '⚙️',
        '🪤',
        '🧱',
        '⛓️',
        '🧲',
        '🔫',
        '💣',
        '🧨',
        '🪓',
        '🔪',
        '🗡️',
        '⚔️',
        '🛡️',
        '🚬',
        '⚰️',
        '🪦',
        '⚱️',
        '🏺',
        '🔮',
        '📿',
        '🧿',
        '💈',
        '⚗️',
        '🔭',
        '🔬',
        '🕳️',
        '🩹',
        '🩺',
        '💊',
        '💉',
        '🩸',
        '🧬',
        '🦠',
        '🧫',
        '🧪',
        '🌡️',
        '🧹',
        '🪠',
        '🧺',
        '🧻',
        '🚽',
        '🚰',
        '🚿',
        '🛁',
        '🛀',
        '🧼',
        '🪥',
        '🪒',
        '🧽',
        '🪣',
        '🧴',
        '🛎️',
        '🔑',
        '🗝️',
        '🚪',
        '🪑',
        '🛋️',
        '🛏️',
        '🛌',
        '🧸',
        '🪆',
        '🖼️',
        '🪞',
        '🪟',
        '🛍️',
        '🛒',
        '🎁',
        '🎈',
        '🎏',
        '🎀',
        '🪄',
        '🪅',
        '🎊',
        '🎉',
        '🎎',
        '🏮',
        '🎐',
        '🧧',
        '✉️',
        '📩',
        '📨',
        '📧',
        '💌',
        '📥',
        '📤',
        '📦',
        '🏷️',
        '🪧',
        '📪',
        '📫',
        '📬',
        '📭',
        '📮',
        '📯',
        '📜',
        '📃',
        '📄',
        '📑',
        '🧾',
        '📊',
        '📈',
        '📉',
        '🗒️',
        '🗓️',
        '📆',
        '📅',
        '🗑️',
        '📇',
        '🗃️',
        '🗳️',
        '🗄️',
        '📋',
        '📁',
        '📂',
        '🗂️',
        '🗞️',
        '📰',
        '📓',
        '📔',
        '📒',
        '📕',
        '📗',
        '📘',
        '📙',
        '📚',
        '📖',
        '🔖',
        '🧷',
        '🔗',
        '📎',
        '🖇️',
        '📐',
        '📏',
        '🧮',
        '📌',
        '📍',
        '✂️',
        '🖊️',
        '🖋️',
        '✒️',
        '🖌️',
        '🖍️',
        '📝',
        '✏️',
        '🔍',
        '🔎',
        '🔏',
        '🔐',
        '🔒',
        '🔓'
      ]
    },
    {
      'icon': Icons.tag,
      'label': 'Símbolos',
      'emojis': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❤️‍🔥',
        '❤️‍🩹',
        '❣️',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '☮️',
        '✝️',
        '☪️',
        '🕉️',
        '☸️',
        '✡️',
        '🔯',
        '🕎',
        '☯️',
        '☦️',
        '🛐',
        '⛎',
        '♈',
        '♉',
        '♊',
        '♋',
        '♌',
        '♍',
        '♎',
        '♏',
        '♐',
        '♑',
        '♒',
        '♓',
        '🆔',
        '⚛️',
        '🉑',
        '☢️',
        '☣️',
        '📴',
        '📳',
        '🈶',
        '🈚',
        '🈸',
        '🈺',
        '🈷️',
        '✴️',
        '🆚',
        '💮',
        '🉐',
        '㊙️',
        '㊗️',
        '🈴',
        '🈵',
        '🈹',
        '🈲',
        '🅰️',
        '🅱️',
        '🆎',
        '🆑',
        '🅾️',
        '🆘',
        '❌',
        '⭕',
        '🛑',
        '⛔',
        '📛',
        '🚫',
        '💯',
        '💢',
        '♨️',
        '🚷',
        '🚯',
        '🚳',
        '🚱',
        '🔞',
        '📵',
        '🚭',
        '❗',
        '❕',
        '❓',
        '❔',
        '‼️',
        '⁉️',
        '🔅',
        '🔆',
        '〽️',
        '⚠️',
        '🚸',
        '🔱',
        '⚜️',
        '🔰',
        '♻️',
        '✅',
        '🈯',
        '💹',
        '❇️',
        '✳️',
        '❎',
        '🌐',
        '💠',
        'Ⓜ️',
        '🌀',
        '💤',
        '🏧',
        '🚾',
        '♿',
        '🅿️',
        '🛗',
        '🈳',
        '🈂️',
        '🛂',
        '🛃',
        '🛄',
        '🛅',
        '🚹',
        '🚺',
        '🚼',
        '⚧️',
        '🚻',
        '🚮',
        '🎦',
        '📶',
        '🈁',
        '🔣',
        'ℹ️',
        '🔤',
        '🔡',
        '🔠',
        '🆖',
        '🆗',
        '🆙',
        '🆒',
        '🆕',
        '🆓',
        '0️⃣',
        '1️⃣',
        '2️⃣',
        '3️⃣',
        '4️⃣',
        '5️⃣',
        '6️⃣',
        '7️⃣',
        '8️⃣',
        '9️⃣',
        '🔟',
        '🔢',
        '#️⃣',
        '*️⃣',
        '⏏️',
        '▶️',
        '⏸️',
        '⏯️',
        '⏹️',
        '⏺️',
        '⏭️',
        '⏮️',
        '⏩',
        '⏪',
        '⏫',
        '⏬',
        '◀️',
        '🔼',
        '🔽',
        '➡️',
        '⬅️',
        '⬆️',
        '⬇️',
        '↗️',
        '↘️',
        '↙️',
        '↖️',
        '↕️',
        '↔️',
        '↪️',
        '↩️',
        '⤴️',
        '⤵️',
        '🔀',
        '🔁',
        '🔂',
        '🔄',
        '🔃',
        '🎵',
        '🎶',
        '➕',
        '➖',
        '➗',
        '✖️',
        '🟰',
        '♾️',
        '💲',
        '💱',
        '™️',
        '©️',
        '®️',
        '〰️',
        '➰',
        '➿',
        '🔚',
        '🔙',
        '🔛',
        '🔝',
        '🔜',
        '✔️',
        '☑️',
        '🔘',
        '🔴',
        '🟠',
        '🟡',
        '🟢',
        '🔵',
        '🟣',
        '⚫',
        '⚪',
        '🟤',
        '🔺',
        '🔻',
        '🔸',
        '🔹',
        '🔶',
        '🔷',
        '🔳',
        '🔲',
        '▪️',
        '▫️',
        '◾',
        '◽',
        '◼️',
        '◻️',
        '🟥',
        '🟧',
        '🟨',
        '🟩',
        '🟦',
        '🟪',
        '⬛',
        '⬜',
        '🟫',
        '🔈',
        '🔇',
        '🔉',
        '🔊',
        '🔔',
        '🔕',
        '📣',
        '📢',
        '👁️‍🗨️',
        '💬',
        '💭',
        '🗯️',
        '♠️',
        '♣️',
        '♥️',
        '♦️',
        '🃏',
        '🎴',
        '🀄',
        '🕐',
        '🕑',
        '🕒',
        '🕓',
        '🕔',
        '🕕',
        '🕖',
        '🕗',
        '🕘',
        '🕙',
        '🕚',
        '🕛',
        '🕜',
        '🕝',
        '🕞',
        '🕟',
        '🕠',
        '🕡',
        '🕢',
        '🕣',
        '🕤',
        '🕥',
        '🕦',
        '🕧'
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEmojis =
        _categories[_selectedCategory]['emojis'] as List<String>;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Barra de categorias
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == index;
                return IconButton(
                  onPressed: () => setState(() => _selectedCategory = index),
                  icon: Icon(category['icon'] as IconData, size: 20),
                  tooltip: category['label'] as String,
                  style: IconButton.styleFrom(
                    foregroundColor: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                    backgroundColor: isSelected
                        ? const Color(0xFF2A2A2A)
                        : Colors.transparent,
                  ),
                );
              },
            ),
          ),
          // Grid de emojis
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: currentEmojis.length,
              itemBuilder: (context, index) {
                final emoji = currentEmojis[index];
                return InkWell(
                  onTap: () => widget.onEmojiSelected(emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
