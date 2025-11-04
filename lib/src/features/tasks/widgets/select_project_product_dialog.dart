import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';

class SelectProjectProductDialog extends StatefulWidget {
  final String projectId;
  final String? currentTaskId;

  const SelectProjectProductDialog({
    super.key,
    required this.projectId,
    this.currentTaskId,
  });

  @override
  State<SelectProjectProductDialog> createState() => _SelectProjectProductDialogState();
}

class _SelectProjectProductDialogState extends State<SelectProjectProductDialog> {
  bool _loading = true;
  String _query = '';
  String? _error;
  late final List<_Option> _allOptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;

      // Buscar produtos já vinculados a outras tasks DO MESMO PROJETO
      final linkedProducts = <String, Map<String, String>>{}; // productId+packageId -> {taskId, taskTitle}
      try {
        // Primeiro buscar todas as tasks do projeto atual
        final projectTasks = await client
            .from('tasks')
            .select('id')
            .eq('project_id', widget.projectId);

        final projectTaskIds = (projectTasks as List)
            .map((t) => t['id'] as String)
            .toSet();

        // Agora buscar produtos vinculados a essas tasks
        final allTaskProducts = await client
            .from('task_products')
            .select('product_id, package_id, task_id, tasks:task_id(title)');

        // Filtrar apenas produtos de tasks do projeto atual
        final linkedRows = (allTaskProducts as List).where((row) {
          final taskId = row['task_id'] as String?;
          if (taskId == null) return false;

          // Excluir a task atual se estamos editando
          if (widget.currentTaskId != null && taskId == widget.currentTaskId) {
            return false;
          }

          // Incluir apenas se a task pertence ao projeto atual
          return projectTaskIds.contains(taskId);
        }).toList();

        for (final row in linkedRows) {
          final productId = row['product_id'] as String?;
          final packageId = row['package_id'] as String?;
          final taskId = row['task_id'] as String?;
          final taskData = row['tasks'] as Map<String, dynamic>?;
          final taskTitle = taskData?['title'] as String?;

          if (productId != null && taskId != null) {
            final key = '$productId:${packageId ?? ""}';
            linkedProducts[key] = {
              'taskId': taskId,
              'taskTitle': taskTitle ?? 'Task sem título',
            };
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar produtos vinculados: $e');
      }

      // 1) Itens do catálogo do projeto (produtos e pacotes) com comentários
      final rows = await client
          .from('project_catalog_items')
          .select('kind, item_id, name, comment, position')
          .eq('project_id', widget.projectId)
          .order('position', ascending: true, nullsFirst: true);
      final list = List<Map<String, dynamic>>.from(rows as List);

      // coletar ids de produto para buscar thumbs em lote
      final productIds = <String>{};
      // Mapa de nomes de pacotes para exibir na listagem de produtos de pacotes
      final packageNames = <String, String>{};
      final packageIds = <String>{};

      for (final r in list) {
        final kind = (r['kind'] as String?) ?? 'product';
        final itemId = (r['item_id'] ?? '').toString();
        if (itemId.isEmpty) continue;
        if (kind == 'product') {
          productIds.add(itemId);
        } else if (kind == 'package') {
          packageIds.add(itemId);
          packageNames[itemId] = (r['name'] ?? '-') as String;
        }
      }

      // Buscar thumbs dos produtos diretos
      final thumbByProduct = <String, String?>{};
      if (productIds.isNotEmpty) {
        final inList = productIds.map((e) => '"$e"').join(',');
        final prods = await client
            .from('products')
            .select('id, image_url, image_thumb_url')
            .filter('id', 'in', '($inList)');
        for (final p in (prods as List)) {
          final id = (p['id'] ?? '').toString();
          thumbByProduct[id] = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
        }
      }

      for (final r in list) {
        final kind = (r['kind'] as String?) ?? 'product';
        final itemId = (r['item_id'] ?? '').toString();
        final name = (r['name'] ?? '-') as String;
        final comment = (r['comment'] as String?);
        if (kind == 'product') {
          final thumb = thumbByProduct[itemId];
          final linkKey = '$itemId:';
          final linkInfo = linkedProducts[linkKey];

          _allOptions.add(_Option(
            label: name,
            comment: comment,
            productId: itemId,
            packageId: null,
            packageName: null,
            thumbUrl: thumb,
            linkedTaskId: linkInfo?['taskId'],
            linkedTaskTitle: linkInfo?['taskTitle'],
          ));
        }
      }

      // 2) Produtos dentro dos pacotes do projeto, com comentários do package_items
      if (packageIds.isNotEmpty) {
        final inList = packageIds.map((e) => '"$e"').join(',');
        final pkgItems = await client
            .from('package_items')
            .select('package_id, product_id, comment')
            .filter('package_id', 'in', '($inList)')
            .order('position', ascending: true, nullsFirst: true);
        // buscar thumbs e nomes dos produtos referenciados
        final pkgProdIds = <String>{};
        for (final r in (pkgItems as List)) {
          final pid = (r['product_id'] ?? '').toString();
          if (pid.isNotEmpty) pkgProdIds.add(pid);
        }
        final thumbByPkgProd = <String, String?>{};
        final nameByPkgProd = <String, String>{};
        if (pkgProdIds.isNotEmpty) {
          final inP = pkgProdIds.map((e) => '"$e"').join(',');
          final prods = await client
              .from('products')
              .select('id, name, image_url, image_thumb_url')
              .filter('id', 'in', '($inP)');
          for (final p in (prods as List)) {
            final id = (p['id'] ?? '').toString();
            nameByPkgProd[id] = (p['name'] ?? '-') as String;
            thumbByPkgProd[id] = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
          }
        }
        for (final r in (pkgItems as List)) {
          final pkgId = (r['package_id'] ?? '').toString();
          final prodId = (r['product_id'] ?? '').toString();
          if (prodId.isEmpty) continue;
          final prodName = nameByPkgProd[prodId] ?? '-';
          final thumb = thumbByPkgProd[prodId];
          final comment = (r['comment'] as String?);
          final linkKey = '$prodId:$pkgId';
          final linkInfo = linkedProducts[linkKey];

          _allOptions.add(_Option(
            label: prodName,
            comment: comment,
            productId: prodId,
            packageId: pkgId,
            packageName: packageNames[pkgId],
            thumbUrl: thumb,
            linkedTaskId: linkInfo?['taskId'],
            linkedTaskTitle: linkInfo?['taskTitle'],
          ));
        }
      }

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showUnlinkDialog(BuildContext context, _Option option) {
    DialogHelper.show(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto já vinculado'),
        content: Text(
          'Este produto já está vinculado à task "${option.linkedTaskTitle}".\n\n'
          'Deseja desvincular e vincular a esta task?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx); // Fechar dialog

              // Desvincular produto da task antiga
              // Salvar referências antes da operação assíncrona
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final client = Supabase.instance.client;
                final userId = client.auth.currentUser?.id;

                var deleteQuery = client
                    .from('task_products')
                    .delete()
                    .eq('task_id', option.linkedTaskId!)
                    .eq('product_id', option.productId);

                if (option.packageId == null || option.packageId!.isEmpty) {
                  // Quando o vínculo é direto (não veio de pacote), package_id é NULL na tabela
                  // Usar IS NULL em vez de comparar com string vazia
                  deleteQuery = deleteQuery.filter('package_id', 'is', null);
                } else {
                  deleteQuery = deleteQuery.eq('package_id', option.packageId!);
                }

                await deleteQuery;

                // Registrar no histórico
                if (userId != null) {
                  try {
                    final productLabel = option.packageName != null && option.packageName!.isNotEmpty
                        ? '${option.label} (${option.packageName})'
                        : option.label;

                    await client.from('task_history').insert({
                      'task_id': option.linkedTaskId!,
                      'user_id': userId,
                      'action': 'updated',
                      'field_name': 'product_unlinked',
                      'old_value': productLabel,
                      'new_value': null,
                    });
                  } catch (e) {
                    debugPrint('Erro ao registrar histórico de desvinculação: $e');
                  }
                }

                // Retornar produto para vincular à nova task
                if (mounted) {
                  navigator.pop({
                    'productId': option.productId,
                    'packageId': option.packageId,
                    'label': option.label,
                    'packageName': option.packageName,
                    'comment': option.comment,
                    'thumbUrl': option.thumbUrl,
                  });
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erro ao desvincular: $e')),
                  );
                }
              }
            },
            child: const Text('Desvincular e vincular aqui'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allOptions.where((o) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return (o.label.toLowerCase().contains(q)) ||
             ((o.comment ?? '').toLowerCase().contains(q)) ||
             ((o.packageName ?? '').toLowerCase().contains(q));
    }).toList();

    return StandardDialog(
      title: 'Vincular produto do projeto',
      width: 720,
      height: MediaQuery.of(context).size.height * 0.85,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('OK'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nome, comentário ou pacote',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = filtered[i];
                return ListTile(
                  leading: _Thumb(url: o.thumbUrl),
                  title: Row(
                    children: [
                      Expanded(child: Text(o.label)),
                      if (o.isLinked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                'Vinculado',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (o.packageName != null && o.packageName!.isNotEmpty)
                        Text('Pacote: ${o.packageName}', style: const TextStyle(fontSize: 12)),
                      if (o.isLinked)
                        Text('Task: ${o.linkedTaskTitle}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
                      if ((o.comment ?? '').isNotEmpty)
                        Text(o.comment!, style: const TextStyle(fontSize: 12, color: Colors.amber)),
                    ],
                  ),
                  onTap: () {
                    if (o.isLinked) {
                      _showUnlinkDialog(context, o);
                    } else {
                      Navigator.pop(context, {
                        'productId': o.productId,
                        'packageId': o.packageId,
                        'label': o.label,
                        'packageName': o.packageName,
                        'comment': o.comment,
                        'thumbUrl': o.thumbUrl,
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});
  @override
  Widget build(BuildContext context) {
    final size = 40.0;
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2, size: 22),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url!, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class _Option {
  final String label;
  final String? comment;
  final String productId;
  final String? packageId;
  final String? packageName;
  final String? thumbUrl;
  final String? linkedTaskId;
  final String? linkedTaskTitle;

  _Option({
    required this.label,
    required this.comment,
    required this.productId,
    required this.packageId,
    required this.packageName,
    required this.thumbUrl,
    this.linkedTaskId,
    this.linkedTaskTitle,
  });

  bool get isLinked => linkedTaskId != null;
}

