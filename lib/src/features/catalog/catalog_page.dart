import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';
import 'package:gestor_projetos_flutter/widgets/reorderable_drag_list.dart';
import 'package:gestor_projetos_flutter/src/features/catalog/_select_products_dialog.dart';
import 'package:gestor_projetos_flutter/src/state/app_state_scope.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';
import 'package:gestor_projetos_flutter/widgets/tabs/tabs.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';
import 'package:image/image.dart' as img;
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';


class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _packages = [];
  bool _depsInitialized = false;
  List<Map<String, dynamic>> _categories = [];

  // Filtros/ordenacao de categorias
  String _catSearch = '';
  int _catFilter = 0; // 0=Todas, 1=Com produtos, 2=Sem produtos
  String _catSort = 'name_asc';
  // Filtros/ordenacao de produtos e pacotes
  @override
  void initState() {
    super.initState();
    _reload();
  }

  String _prodSearch = '';
  String? _prodCatFilter; // categoria_id ou null para todas
  String _prodSort = 'name_asc';

  String _packSearch = '';
  String? _packCatFilter;
  String _packSort = 'name_asc';




  String _categoryNameById(String? id) {
    if (id == null) return '';
    for (final c in _categories) {
      if ((c['id'] ?? '').toString() == id) return (c['name'] ?? '') as String;
    }
    return '';
  }

  /// Upload de miniatura de produto para Supabase Storage com downscale automático
  /// Redimensiona para máximo de 400x400px mantendo proporção
  /// Retorna a URL pública da imagem ou null em caso de erro
  Future<String?> _uploadProductThumbnail({
    required Uint8List imageBytes,
    required String productId,
    required String productName,
    String? oldThumbnailUrl,
  }) async {
    try {
      // 1. Decodificar a imagem
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ Erro ao decodificar imagem');
        return null;
      }

      // 2. Redimensionar mantendo proporção (máximo 400x400)
      const maxSize = 400;
      img.Image thumbnail;
      if (image.width > maxSize || image.height > maxSize) {
        thumbnail = img.copyResize(
          image,
          width: image.width > image.height ? maxSize : null,
          height: image.height >= image.width ? maxSize : null,
          interpolation: img.Interpolation.linear,
        );
        debugPrint('📐 Imagem redimensionada de ${image.width}x${image.height} para ${thumbnail.width}x${thumbnail.height}');
      } else {
        thumbnail = image;
        debugPrint('📐 Imagem já está no tamanho adequado: ${image.width}x${image.height}');
      }

      // 3. Comprimir como JPEG com qualidade 85
      final compressed = img.encodeJpg(thumbnail, quality: 85);
      final originalSize = imageBytes.length / 1024; // KB
      final compressedSize = compressed.length / 1024; // KB
      debugPrint('🗜️ Compressão: ${originalSize.toStringAsFixed(1)}KB → ${compressedSize.toStringAsFixed(1)}KB (${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}% redução)');

      // 4. Deletar miniatura antiga se existir
      if (oldThumbnailUrl != null && oldThumbnailUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(oldThumbnailUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('product-thumbnails');
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final oldPath = pathSegments.sublist(bucketIndex + 1).join('/');
            await Supabase.instance.client.storage
                .from('product-thumbnails')
                .remove([oldPath]);
            debugPrint('✅ Miniatura antiga deletada: $oldPath');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar miniatura antiga: $e');
        }
      }

      // 5. Upload para Supabase Storage
      // Sanitizar nome do produto/pacote para usar no nome do arquivo
      final sanitizedName = productName.trim().isEmpty
          ? 'produto'
          : productName.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = 'thumb-$sanitizedName.jpg';
      final path = fileName;

      await Supabase.instance.client.storage
          .from('product-thumbnails')
          .uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // 6. Obter URL pública
      final url = Supabase.instance.client.storage
          .from('product-thumbnails')
          .getPublicUrl(path);

      debugPrint('✅ Miniatura enviada com sucesso: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Erro ao fazer upload da miniatura: $e');
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInitialized) {
      _depsInitialized = true;
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      // Carrega categorias, mas não falha a página se a tabela não existir
      List<Map<String, dynamic>> cats = [];
      try {
        // Busca categorias com contagem de produtos por categoria
        final r = await client
            .from('catalog_categories')
            .select('id, name, products:products(count)')
            .order('name');
        cats = List<Map<String, dynamic>>.from(r.map((e) {
          final m = Map<String, dynamic>.from(e);
          // Supabase retorna o count dentro de uma lista agregada
          final products = m['products'];
          int count = 0;
          if (products is List && products.isNotEmpty) {
            final first = products.first;
            if (first is Map && first['count'] is int) count = first['count'] as int;
          }
          m['product_count'] = count;
          return m;
        }));
      } catch (_) {
        cats = [];
      }
      // Usando o módulo de catálogo
      final prods = await catalogModule.getProducts();
      final packs = await catalogModule.getPackages();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _products = List<Map<String, dynamic>>.from(prods);
        _packages = List<Map<String, dynamic>>.from(packs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Falha ao carregar catálogo: $e'; _loading = false; });
    }
  }

  String _fmt(int cents) => (cents / 100.0).toStringAsFixed(2);


  String _priceSummary(Map<String, dynamic> row) {
    final pm = (row['price_map'] as Map?)?.cast<String, dynamic>();
    if (pm != null && pm.isNotEmpty) {
      const order = ['BRL', 'USD', 'EUR'];
      final parts = <String>[];
      for (final code in order) {
        final v = pm[code];
        if (v is int) parts.add('$code ${_fmt(v)}');
      }
      pm.forEach((code, v) { if (!order.contains(code) && v is int) parts.add('$code ${_fmt(v)}'); });
      return parts.isEmpty ? '-' : parts.join(' • ');
    }
    final code = (row['currency_code'] as String?) ?? 'BRL';
    final cents = (row['price_cents'] as int?) ?? 0;
    return '$code ${_fmt(cents)}';
  }


  Widget _productLeadingThumb(Map<String, dynamic> p) {
    final url = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
    if (url == null || url.isEmpty) {
      return const CircleAvatar(radius: 18, child: Icon(Icons.image_not_supported, size: 18));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(url, width: 48, height: 48, fit: BoxFit.cover),
    );
  }

  Future<void> _editCategoryInline({Map<String, dynamic>? initial}) async {
    String? localErr;
    bool saving = false;
    final controller = TextEditingController(text: (initial?['name'] ?? '') as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        Future<void> doSave() async {
          setState(() { saving = true; localErr = null; });
          try {
            final name = controller.text.trim();
            if (name.isEmpty) throw 'Informe o nome da categoria';
            final client = Supabase.instance.client;
            if (initial == null) {
              await client.from('catalog_categories').insert({'name': name});
            } else {
              await client.from('catalog_categories').update({'name': name}).eq('id', (initial['id'] ?? '').toString());
            }
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            setState(() { localErr = e.toString(); });
          } finally {
            setState(() { saving = false; });
          }
        }

        return StandardDialog(
          title: initial == null ? 'Nova categoria' : 'Editar categoria',
          width: StandardDialog.widthSmall,
          height: StandardDialog.heightSmall,
          showCloseButton: false,
          isLoading: saving,
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: saving ? null : doSave, child: const Text('Salvar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome')),
              if (localErr != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Erro: $localErr', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ),
            ],
          ),
        );
      }),
    );
    if (ok == true) await _reload();
  }



  int _parseMoneyToCents(String input) {
    var s = input.trim();
    // Remove qualquer símbolo de moeda/letras/espacos, mantendo dígitos, vírgula, ponto e sinal
    s = s.replaceAll(RegExp(r'[^0-9,\.-]'), '');
    // Se tiver vírgula, trata como separador decimal BR; remove pontos (milhar) e troca vírgula por ponto
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    if (s.isEmpty || s == '-' || s == '.' || s == ',') return 0;
    final v = double.tryParse(s);
    return v == null ? 0 : (v * 100).round();
  }

  Future<void> _newProduct() => _editItem('products', null);
  Future<void> _newPackage() => _editItem('packages', null);
  Future<void> _newCategory() async {
    await _editCategoryInline();
  }

  Future<void> _editProduct(Map<String, dynamic> row) => _editItem('products', row);
  Future<void> _editPackage(Map<String, dynamic> row) => _editItem('packages', row);

  Future<void> _confirmDelete(String table, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Excluir Item',
        message: 'Tem certeza que deseja excluir este item?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );
    if (ok == true) {
      try {
        await Supabase.instance.client.from(table).delete().eq('id', id);
        await _reload();
      } catch (e) {
        if (!mounted) return;
        String? friendly;
        // Violação de chave estrangeira (código 23503)
        try {
          if (e is PostgrestException && e.code == '23503') {
            if (table == 'products') {
              friendly = 'Não é possível excluir este produto pois ele está sendo usado em um ou mais pacotes. Remova-o dos pacotes antes de excluir. Se preferir, posso habilitar ON DELETE CASCADE no banco.';
            } else if (table == 'packages') {
              friendly = 'Não é possível excluir este pacote pois ele possui itens vinculados. Remova os itens antes de excluir. Se preferir, posso habilitar ON DELETE CASCADE no banco.';
            }
          }
        } catch (_) {}
        if (friendly != null) {
          await showDialog(
            context: context,
            builder: (_) => StandardDialog(
              title: 'Exclusão bloqueada',
              width: StandardDialog.widthSmall,
              height: StandardDialog.heightSmall,
              actions: [
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')),
              ],
              child: Text(friendly!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
        }
      }
    }
  }

  Future<void> _manageCategories() async {
    String? error;
    bool busy = false;

    Future<void> addOrEdit({Map<String, dynamic>? initial}) async {
      final controller = TextEditingController(text: (initial?['name'] ?? '') as String);
      String? localErr;
      bool saving = false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (context, setState) {
          Future<void> doSave() async {
            setState(() { saving = true; localErr = null; });
            try {
              final name = controller.text.trim();
              if (name.isEmpty) throw 'Informe o nome da categoria';
              final client = Supabase.instance.client;
              if (initial == null) {
                await client.from('catalog_categories').insert({'name': name});
              } else {
                await client.from('catalog_categories').update({'name': name}).eq('id', (initial['id'] ?? '').toString());
              }
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setState(() { localErr = e.toString(); });
            } finally {
              setState(() { saving = false; });
            }
          }

          return StandardDialog(
            title: initial == null ? 'Nova categoria' : 'Editar categoria',
            width: StandardDialog.widthSmall,
            height: StandardDialog.heightSmall,
            showCloseButton: false,
            isLoading: saving,
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: saving ? null : doSave, child: const Text('Salvar')),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome')),
                if (localErr != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(alignment: Alignment.centerLeft, child: Text('Erro: $localErr', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ),
              ],
            ),
          );
        }),
      );
      if (ok == true) {
        final cats = await Supabase.instance.client.from('catalog_categories').select('id, name').order('name');
        if (!mounted) return;
        setState(() { _categories = List<Map<String, dynamic>>.from(cats); });
      }
    }

    // OBS: fluxo antigo de gerenciar lista completo foi descontinuado
    // Mantido como utilitário oculto caso seja necessário no futuro
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        Future<void> refresh() async {
          setState(() { busy = true; error = null; });
          try {
            final cats = await Supabase.instance.client.from('catalog_categories').select('id, name').order('name');
            if (!mounted) return;
            setState(() { _categories = List<Map<String, dynamic>>.from(cats); });
          } catch (e) {
            setState(() { error = e.toString(); });
          } finally {
            setState(() { busy = false; });
          }
        }

        Future<void> remove(String id) async {
          setState(() { busy = true; error = null; });
          try {
            await Supabase.instance.client.from('catalog_categories').delete().eq('id', id);
            await refresh();
          } catch (e) {
            setState(() { error = e.toString(); });
          } finally {
            setState(() { busy = false; });
          }
        }

        return StandardDialog(
          title: 'Categorias',
          width: StandardDialog.widthMedium,
          height: StandardDialog.heightMedium,
          isLoading: busy,
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Fechar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => addOrEdit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova categoria'),
                  ),
                  const SizedBox(width: 8),
                  IconOnlyButton(
                    onPressed: busy ? null : refresh,
                    tooltip: 'Atualizar',
                    icon: Icons.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (error != null)
                Align(alignment: Alignment.centerLeft, child: Text('Erro: $error', style: TextStyle(color: Theme.of(context).colorScheme.error))),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final c = _categories[i];
                    final name = (c['name'] ?? '') as String;
                    final id = (c['id'] ?? '').toString();
                    return ListTile(
                      title: Text(name),
                      subtitle: null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconOnlyButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar',
                          onPressed: busy ? null : () => addOrEdit(initial: c),
                        ),
                        IconOnlyButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Excluir',
                          onPressed: busy ? null : () => remove(id),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }


  Future<void> _editItem(String table, Map<String, dynamic>? initial) async {
    // Package items (for packages form)
    List<Map<String, dynamic>> pkgItems = [];
    bool pkgLoading = table == 'packages' && initial != null;
    String? pkgError;
    // suprimir avisos se não usados diretamente (mantidos para futura UX de loading/erro)
    // ignore: unused_local_variable
    final suppress1 = pkgLoading;
    // ignore: unused_local_variable
    final suppress2 = pkgError;

    final name = TextEditingController(text: (initial?['name'] ?? '') as String);
    // Carregar itens do pacote ao abrir o formulário de edição de pacote
    if (table == 'packages' && initial != null) {
      try {
        final res = await Supabase.instance.client
            .from('package_items')
            .select('product_id, quantity, comment, position')
            .eq('package_id', (initial['id'] ?? '').toString())
            .order('position', ascending: true);
        pkgItems = List<Map<String, dynamic>>.from(res);
      } catch (e) {
        pkgError = e.toString();
      } finally {
        pkgLoading = false;
      }
    }

    final desc = TextEditingController(text: (initial?['description'] ?? '') as String);
    // Image fields for products
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    String? imageUrl = (initial?['image_url'] as String?);
    bool imageCleared = false;

    String? categoryId = (initial?['category_id'] as String?);

    String textFrom(Map<String, dynamic>? r, String code) {
      final pm = (r?['price_map'] as Map?)?.cast<String, dynamic>();
      final v = pm != null && pm[code] is int ? pm[code] as int : null;
      if (v != null) return _fmt(v);
      if (r != null && r['currency_code'] == code) return _fmt((r['price_cents'] as int?) ?? 0);
      return '';
    }
    final brl = TextEditingController(text: textFrom(initial, 'BRL'));
    final usd = TextEditingController(text: textFrom(initial, 'USD'));
    final eur = TextEditingController(text: textFrom(initial, 'EUR'));
    // Auto-preenchimento a partir da soma dos itens do pacote; bloqueia ao editar
    bool autoBRL = true, autoUSD = true, autoEUR = true;


    // Se estiver editando um pacote existente, detecta se o usuário já personalizou valores
    if (table == 'packages') {
      int sumBRL = 0, sumUSD = 0, sumEUR = 0;
      for (final it in pkgItems) {
        final pid = (it['product_id'] ?? '').toString();
        final prod = _products.firstWhere((p) => (p['id'] ?? '').toString() == pid, orElse: () => {});
        final pm = (prod['price_map'] as Map?)?.cast<String, dynamic>();
        final qty = (it['quantity'] as int?) ?? 1;
        sumBRL += (pm?['BRL'] as int? ?? (prod['currency_code'] == 'BRL' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
        sumUSD += (pm?['USD'] as int? ?? (prod['currency_code'] == 'USD' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
        sumEUR += (pm?['EUR'] as int? ?? (prod['currency_code'] == 'EUR' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
      }
      final curBRL = _parseMoneyToCents(brl.text);
      final curUSD = _parseMoneyToCents(usd.text);
      final curEUR = _parseMoneyToCents(eur.text);
      if (curBRL != 0 || brl.text.trim().isNotEmpty) {
        if (curBRL != sumBRL) autoBRL = false;
      }
      if (curUSD != 0 || usd.text.trim().isNotEmpty) {
        if (curUSD != sumUSD) autoUSD = false;
      }
      if (curEUR != 0 || eur.text.trim().isNotEmpty) {
        if (curEUR != sumEUR) autoEUR = false;
      }
    }

    bool saving = false;

    String? err;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        Future<void> doSave() async {
          setState(() { saving = true; err = null; });
          try {
            final pm = <String, int>{};
            final b = _parseMoneyToCents(brl.text); if (b > 0) pm['BRL'] = b;
            final u = _parseMoneyToCents(usd.text); if (u > 0) pm['USD'] = u;
            final e = _parseMoneyToCents(eur.text); if (e > 0) pm['EUR'] = e;
            if (name.text.trim().isEmpty) throw 'Informe o nome';
            final selectedName = categoryId == null
                ? null
                : (() {
                    for (final c in _categories) {
                      if ((c['id'] ?? '').toString() == categoryId) return (c['name'] ?? '') as String;
                    }
                    return null;
                  })();

            final payload = <String, dynamic>{
              'name': name.text.trim(),
              'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
              'category_id': categoryId,
              'category': selectedName, // fallback para compatibilidade
            };

            // Upload de miniatura no Supabase Storage (produtos e pacotes)
            String? imagePublicUrl;
            if (table == 'products' || table == 'packages') {
              try {
                if (pickedImageBytes != null && pickedImageName != null) {
                  // Gerar ID temporário para novos itens ou usar o ID existente
                  final itemId = initial?['id'] as String? ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

                  // Upload com downscale automático para Supabase
                  imagePublicUrl = await _uploadProductThumbnail(
                    imageBytes: pickedImageBytes!,
                    productId: itemId,
                    productName: name.text.trim(),
                    oldThumbnailUrl: imageUrl,
                  );
                } else if (imageCleared) {
                  // Deletar miniatura antiga se foi limpa
                  if (imageUrl != null && imageUrl!.isNotEmpty) {
                    try {
                      final uri = Uri.parse(imageUrl!);
                      final pathSegments = uri.pathSegments;
                      final bucketIndex = pathSegments.indexOf('product-thumbnails');
                      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
                        final oldPath = pathSegments.sublist(bucketIndex + 1).join('/');
                        await Supabase.instance.client.storage
                            .from('product-thumbnails')
                            .remove([oldPath]);
                        debugPrint('✅ Miniatura deletada: $oldPath');
                      }
                    } catch (e) {
                      debugPrint('⚠️ Erro ao deletar miniatura: $e');
                    }
                  }
                  imagePublicUrl = null;
                } else if (imageUrl != null) {
                  imagePublicUrl = imageUrl; // mantém existente
                }
              } catch (e) {
                debugPrint('❌ Erro no upload da miniatura: $e');
              }
              payload['image_url'] = imagePublicUrl;
            }

            final client = Supabase.instance.client;
            if (initial == null) {
              // CREATE: define price_map; e define currency_code/price_cents coerente
              payload['price_map'] = pm;
              if (pm.containsKey('BRL')) {
                payload['currency_code'] = 'BRL';
                payload['price_cents'] = pm['BRL'];
              } else if (pm.isNotEmpty) {
                final first = pm.entries.first;
                payload['currency_code'] = first.key;
                payload['price_cents'] = first.value;
              } else {
                // fallback seguro caso a tabela tenha NOT NULL
                payload['currency_code'] = 'BRL';
                payload['price_cents'] = 0;
              }
              final ins = await client.from(table).insert(payload).select('id').single();
              if (table == 'packages') {
                final newId = (ins['id'] ?? '').toString();
                if (pkgItems.isNotEmpty) {
                  final rows = List.generate(pkgItems.length, (i) { final it = pkgItems[i]; return {
                    'package_id': newId,
                    'product_id': (it['product_id'] ?? '').toString(),
                    'quantity': (it['quantity'] as int?) ?? 1,
                        'comment': (it['comment'] as String?),
                        'position': i,
                  }; }).toList();
                  await client.from('package_items').insert(rows);
                }
              }
            } else {
              // UPDATE: s pm vazio -> n o sobrescreve price_map
              if (pm.isNotEmpty) payload['price_map'] = pm;
              // Atualiza legacy s f de BRL informado; caso contr e1rio mant eam
              if (pm.containsKey('BRL')) {
                payload['currency_code'] = 'BRL';
                payload['price_cents'] = pm['BRL'];
              }
              await client.from(table).update(payload).eq('id', (initial['id'] ?? '').toString());
              if (table == 'packages') {
                final pkgId = (initial['id'] ?? '').toString();

                await client.from('package_items').delete().eq('package_id', pkgId);
                if (pkgItems.isNotEmpty) {
                  final rows = List.generate(pkgItems.length, (i) { final it = pkgItems[i]; return {
                    'package_id': pkgId,
                    'product_id': (it['product_id'] ?? '').toString(),
                    'quantity': (it['quantity'] as int?) ?? 1,
                        'comment': (it['comment'] as String?),
                        'position': i,
                  }; }).toList();
                  await client.from('package_items').insert(rows);
                }
              }
            }
            if (context.mounted) Navigator.pop(context, true);
          } catch (ex) {
            setState(() { err = ex.toString(); });
          } finally {
            setState(() { saving = false; });
          }
        }

        final categoryItems = _categories
            .map((c) => DropdownItem<String>(
                  value: (c['id'] ?? '').toString(),
                  label: (c['name'] ?? '') as String,
                ))
            .toList();

        return StandardDialog(
          title: initial == null ? (table == 'products' ? 'Novo Produto' : 'Novo Pacote') : 'Editar',
          width: StandardDialog.widthMedium,
          height: StandardDialog.heightMedium,
          showCloseButton: false,
          isLoading: saving,
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: saving ? null : doSave, child: const Text('Salvar')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                // Pacotes: Nome, Descrição e Categoria primeiro
                if (table == 'packages') ...[
                  const SizedBox(height: 16),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GenericDropdownField<String>(
                        value: categoryId,
                        items: categoryItems,
                        labelText: 'Categoria',
                        onChanged: (v) => setState(() => categoryId = v),
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async { await _manageCategories(); if (context.mounted) await _reload(); },
                      icon: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('Gerenciar'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Imagem do pacote
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const ['jpg','jpeg','png','webp','gif'],
                                  withData: true,
                                  allowMultiple: false,
                                );
                                if (res != null && res.files.isNotEmpty) {
                                  final f = res.files.first;
                                  if (f.bytes != null) {
                                    pickedImageBytes = f.bytes!;
                                    pickedImageName = f.name;
                                    if (context.mounted) setState(() {});
                                  }
                                }
                              },
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Selecionar imagem do pacote'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: saving ? null : () { imageCleared = true; imageUrl = null; pickedImageBytes = null; pickedImageName = null; setState(() {}); },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remover imagem'),
                      ),
                  ]),
                  if (pickedImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Selecionado: \\${pickedImageName ?? 'arquivo'}', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  if (imageUrl != null && imageUrl!.isNotEmpty && pickedImageBytes == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Imagem atual definida', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  // Pré-visualização da imagem
                  if (pickedImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(pickedImageBytes!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    )
                  else if (imageUrl != null && imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                ],
                if (table == 'products') ...[
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 12),
                ],

                if (table == 'packages') ...[
                  const SizedBox(height: 12),
                  // Botão para abrir modal de seleção de produtos
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: saving ? null : () async {
                        final added = await showDialog<List<Map<String, dynamic>>>(
                          context: context,
                          builder: (_) => SelectProductsDialog(
                            products: _products,
                            alreadySelected: const {}, // permitir duplicados do mesmo produto
                          ),
                        );
                        if (added != null && added.isNotEmpty) {
                          setState(() {
                            for (final a in added) {
                              final pid = (a['product_id'] ?? '').toString();
                              final qty = (a['quantity'] as int?) ?? 1;
                              for (var j = 0; j < qty; j++) {
                                pkgItems.add({'product_id': pid, 'quantity': 1, 'comment': null});
                              }
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Adicionar produto'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista de itens do pacote com unitário e total
                  ReorderableDragList<Map<String, dynamic>>(
                    items: pkgItems,
                    enabled: true,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = pkgItems.removeAt(oldIndex);
                        pkgItems.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, it, i) {
                      final pid = (it['product_id'] ?? '').toString();
                      final prod = _products.firstWhere((p) => (p['id'] ?? '').toString() == pid, orElse: () => {});
                      final prodName = (prod['name'] ?? pid) as String;
                      final pm = (prod['price_map'] as Map?)?.cast<String, dynamic>();
                      final centsBRL = pm?['BRL'] as int? ?? (prod['price_cents'] as int? ?? 0);
                      final qty = 1;
                      final unitFmt = 'BRL ${_fmt(centsBRL)}';
                      final totalFmt = 'BRL ${_fmt(centsBRL * qty)}';
                      return ListTile(
                        dense: true,
                        leading: _productLeadingThumb(prod),
                        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(prodName)),
                          ]),
                          if ((AppStateScope.of(context).isAdminOrGestor || AppStateScope.of(context).isFinanceiro)) Text('Unit: $unitFmt • Total: $totalFmt'),
                          const SizedBox(height: 4),
                          Row(children: [
                            IconOnlyButton(
                              icon: Icons.mode_comment_outlined,
                              tooltip: 'Adicionar comentário',
                              onPressed: () async {
                                final controller = TextEditingController(text: (it['comment'] as String?) ?? '');
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => StandardDialog(
                                    title: 'Comentário do item',
                                    width: StandardDialog.widthSmall,
                                    height: StandardDialog.heightSmall,
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
                                    ],
                                    child: TextField(
                                      controller: controller,
                                      maxLines: 4,
                                      decoration: const InputDecoration(hintText: 'Escreva um comentário opcional...'),
                                    ),
                                  ),
                                );
                                if (ok == true) {
                                  setState(() => it['comment'] = controller.text.trim());
                                }
                              },
                            ),
                            if ((it['comment'] as String?)?.isNotEmpty == true)
                              Expanded(
                                child: Text(
                                  it['comment'] as String,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber),
                                ),
                              ),
                          ]),
                        ]),
                        subtitle: null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconOnlyButton(
                            icon: Icons.add_circle_outline,
                            tooltip: 'Duplicar item',
                            onPressed: () => setState(() {
                              final copy = {
                                'product_id': (it['product_id'] ?? '').toString(),
                                'quantity': 1,
                                'comment': null,
                              };
                              pkgItems.insert(i + 1, copy);
                            }),
                          ),
                          const SizedBox(width: 8),
                          IconOnlyButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Remover item',
                            onPressed: () => setState(() => pkgItems.removeAt(i)),
                          ),
                        ]),
                      );
                    },
                    getKey: (it) => '${it['product_id']}_${pkgItems.indexOf(it)}',
                    emptyWidget: const Center(child: Text('Nenhum produto adicionado')),
                  ),
                  // Totais dos produtos por moeda + sincronização automática com campos editáveis
                  if (pkgItems.isNotEmpty && (AppStateScope.of(context).isAdmin || AppStateScope.of(context).isFinanceiro)) ...[
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      int sumBRL = 0, sumUSD = 0, sumEUR = 0;
                      for (final it in pkgItems) {
                        final pid = (it['product_id'] ?? '').toString();
                        final prod = _products.firstWhere((p) => (p['id'] ?? '').toString() == pid, orElse: () => {});
                        final pm = (prod['price_map'] as Map?)?.cast<String, dynamic>();
                        final qty = 1;
                        sumBRL += (pm?['BRL'] as int? ?? (prod['currency_code'] == 'BRL' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
                        sumUSD += (pm?['USD'] as int? ?? (prod['currency_code'] == 'USD' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
                        sumEUR += (pm?['EUR'] as int? ?? (prod['currency_code'] == 'EUR' ? (prod['price_cents'] as int? ?? 0) : 0)) * qty;
                      }
                      final fBRL = _fmt(sumBRL);
                      final fUSD = _fmt(sumUSD);
                      final fEUR = _fmt(sumEUR);
                      if (autoBRL && brl.text != fBRL) brl.text = fBRL;
                      if (autoUSD && usd.text != fUSD) usd.text = fUSD;
                      if (autoEUR && eur.text != fEUR) eur.text = fEUR;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Total dos produtos:', style: Theme.of(context).textTheme.bodySmall),
                            Text('BRL $fBRL • USD $fUSD • EUR $fEUR', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                      );
                    }),
                  ],



                ],

                // Campos comuns do formulário

                if (table == 'products') ...[
                  Row(children: [
                    Expanded(
                      child: GenericDropdownField<String>(
                        value: categoryId,
                        items: categoryItems,
                        labelText: 'Categoria',
                        onChanged: (v) => setState(() => categoryId = v),
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              await _manageCategories();
                              if (context.mounted) await _reload();
                            },
                      icon: const Icon(Icons.category_outlined, size: 18),
                      label: const Text('Gerenciar'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
                if (table == 'products') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const ['jpg','jpeg','png','webp','gif'],
                                  withData: true,
                                  allowMultiple: false,
                                );
                                if (res != null && res.files.isNotEmpty) {
                                  final f = res.files.first;
                                  if (f.bytes != null) {
                                    pickedImageBytes = f.bytes!;
                                    pickedImageName = f.name;
                                    if (context.mounted) setState(() {});
                                  }
                                }
                              },
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Selecionar imagem do produto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: saving ? null : () { imageCleared = true; imageUrl = null; pickedImageBytes = null; pickedImageName = null; setState(() {}); },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remover imagem'),
                      ),
                  ]),
                  if (pickedImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Selecionado: ${pickedImageName ?? 'arquivo'}', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  if (imageUrl != null && imageUrl!.isNotEmpty && pickedImageBytes == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Imagem atual definida', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  // Pré-visualização da imagem
                  if (pickedImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(pickedImageBytes!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    )
                  else if (imageUrl != null && imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                ],


                const SizedBox(height: 12),
                if ((AppStateScope.of(context).isAdmin || AppStateScope.of(context).isFinanceiro)) Row(children: [
                  Expanded(child: TextField(
                    controller: brl,
                    decoration: const InputDecoration(labelText: 'BRL'),
                    onChanged: (_) => setState(() => autoBRL = false),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: usd,
                    decoration: const InputDecoration(labelText: 'USD'),
                    onChanged: (_) => setState(() => autoUSD = false),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: eur,
                    decoration: const InputDecoration(labelText: 'EUR'),
                    onChanged: (_) => setState(() => autoEUR = false),
                  )),
                ]),
                if (err != null) Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Erro: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ),
              ],
            ),
        );
      }),
    );
    if (saved == true) await _reload();
  }


  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canViewValues = appState.isAdmin || appState.isFinanceiro;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Catálogo', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          if (!_loading && (appState.isAdmin || appState.isGestor || appState.isDesigner)) ...[
            FilledButton.tonalIcon(onPressed: _newProduct, icon: const Icon(Icons.add), label: const Text('Novo Produto')),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(onPressed: _newPackage, icon: const Icon(Icons.add_card), label: const Text('Novo Pacote')),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(onPressed: _newCategory, icon: const Icon(Icons.category), label: const Text('Nova Categoria')),
            const SizedBox(width: 8),
          ],
          IconOnlyButton(
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _reload,
            icon: Icons.refresh,
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : GenericTabView(
                      tabs: const [
                        TabConfig(text: 'Produtos'),
                        TabConfig(text: 'Pacotes'),
                        TabConfig(text: 'Categorias'),
                      ],
                      children: [
                        // Produtos
                        Column(children: [
                          // Barra de busca/filtro/ordenação de produtos
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Row(children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar produto...'),
                                  onChanged: (v) => setState(() => _prodSearch = v.trim()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Filtro por categoria
                              SizedBox(
                                width: 150,
                                child: GenericDropdownField<String>(
                                  value: _prodCatFilter ?? 'ALL',
                                  items: [
                                    const DropdownItem(value: 'ALL', label: 'Todas'),
                                    ..._categories.map((c) => DropdownItem<String>(
                                          value: (c['id'] ?? '').toString(),
                                          label: (c['name'] ?? '') as String,
                                        )),
                                  ],
                                  onChanged: (v) => setState(() => _prodCatFilter = (v == null || v == 'ALL') ? null : v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ordenação
                              SizedBox(
                                width: 150,
                                child: GenericDropdownField<String>(
                                  value: _prodSort,
                                  items: const [
                                    DropdownItem(value: 'name_asc', label: 'Nome A→Z'),
                                    DropdownItem(value: 'name_desc', label: 'Nome Z→A'),
                                    DropdownItem(value: 'price_asc', label: 'Preço ↑'),
                                    DropdownItem(value: 'price_desc', label: 'Preço ↓'),
                                  ],
                                  onChanged: (v) => setState(() => _prodSort = v ?? 'name_asc'),
                                ),
                              ),
                            ]),
                          ),
                          Expanded(
                            child: Builder(builder: (context) {
                              var list = List<Map<String, dynamic>>.from(_products);
                              if (_prodSearch.isNotEmpty) {
                                final q = _prodSearch.toLowerCase();
                                list = list.where((p) {
                                  final n = ((p['name'] ?? '') as String).toLowerCase();
                                  final d = ((p['description'] ?? '') as String).toLowerCase();
                                  return n.contains(q) || d.contains(q);
                                }).toList();
                              }
                              if (_prodCatFilter != null) {
                                final sel = _prodCatFilter;
                                list = list.where((p) => ((p['category_id'] ?? '') as String?) == sel).toList();
                              }
                              list.sort((a, b) {
                                if (_prodSort.startsWith('price')) {
                                  int ac = 0;
                                  int bc = 0;
                                  final apm = (a['price_map'] as Map?)?.cast<String, dynamic>();
                                  final bpm = (b['price_map'] as Map?)?.cast<String, dynamic>();
                                  ac = (apm?['BRL'] as int?) ?? (a['price_cents'] as int? ?? 0);
                                  bc = (bpm?['BRL'] as int?) ?? (b['price_cents'] as int? ?? 0);
                                  return _prodSort == 'price_desc' ? bc.compareTo(ac) : ac.compareTo(bc);
                                }
                                final an = ((a['name'] ?? '') as String).toLowerCase();
                                final bn = ((b['name'] ?? '') as String).toLowerCase();
                                return _prodSort == 'name_desc' ? bn.compareTo(an) : an.compareTo(bn);
                              });
                              if (list.isEmpty) return const Center(child: Text('Nenhum produto'));
                              return ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final p = list[i];
                                  final name = (p['name'] ?? '-') as String;
                                  final desc = (p['description'] ?? '') as String;
                                  final catName = (() {
                                    final id = p['category_id'] as String?;
                                    final byId = _categoryNameById(id);
                                    if (byId.isNotEmpty) return byId;
                                    return (p['category'] as String?) ?? '';
                                  })();
                                  return ListTile(
                                    leading: _productLeadingThumb(p),
                                    title: Row(children: [
                                      Expanded(child: Text(name)),
                                      if (catName.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Chip(
                                            label: Text(catName),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                    ]),
                                    subtitle: canViewValues
                                        ? Text(desc.isNotEmpty ? '${_priceSummary(p)}\n$desc' : _priceSummary(p))
                                        : (desc.isNotEmpty ? Text(desc) : null),
                                    isThreeLine: canViewValues ? desc.isNotEmpty : false,
                                    trailing: (appState.isAdmin || appState.isGestor || appState.isDesigner)
                                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                                            IconOnlyButton(icon: Icons.edit_outlined, tooltip: 'Editar', onPressed: () => _editProduct(p)),
                                            IconOnlyButton(icon: Icons.delete_outline, tooltip: 'Excluir', onPressed: () => _confirmDelete('products', (p['id'] ?? '').toString())),
                                          ])
                                        : null,
                                  );
                                },
                              );
                            }),
                          ),
                        ]),
                        // Pacotes
                        Column(children: [
                          // Barra de busca/filtro/ordenação de pacotes
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Row(children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar pacote...'),
                                  onChanged: (v) => setState(() => _packSearch = v.trim()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Filtro por categoria
                              SizedBox(
                                width: 150,
                                child: GenericDropdownField<String>(
                                  value: _packCatFilter ?? 'ALL',
                                  items: [
                                    const DropdownItem(value: 'ALL', label: 'Todas'),
                                    ..._categories.map((c) => DropdownItem<String>(
                                          value: (c['id'] ?? '').toString(),
                                          label: (c['name'] ?? '') as String,
                                        )),
                                  ],
                                  onChanged: (v) => setState(() => _packCatFilter = (v == null || v == 'ALL') ? null : v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ordenação
                              SizedBox(
                                width: 150,
                                child: GenericDropdownField<String>(
                                  value: _packSort,
                                  items: const [
                                    DropdownItem(value: 'name_asc', label: 'Nome A→Z'),
                                    DropdownItem(value: 'name_desc', label: 'Nome Z→A'),
                                    DropdownItem(value: 'price_asc', label: 'Preço ↑'),
                                    DropdownItem(value: 'price_desc', label: 'Preço ↓'),
                                  ],
                                  onChanged: (v) => setState(() => _packSort = v ?? 'name_asc'),
                                ),
                              ),
                            ]),
                          ),
                          Expanded(
                            child: Builder(builder: (context) {
                              var list = List<Map<String, dynamic>>.from(_packages);
                              if (_packSearch.isNotEmpty) {
                                final q = _packSearch.toLowerCase();
                                list = list.where((p) {
                                  final n = ((p['name'] ?? '') as String).toLowerCase();
                                  final d = ((p['description'] ?? '') as String).toLowerCase();
                                  return n.contains(q) || d.contains(q);
                                }).toList();
                              }
                              if (_packCatFilter != null) {
                                final sel = _packCatFilter;
                                list = list.where((p) => ((p['category_id'] ?? '') as String?) == sel).toList();
                              }
                              list.sort((a, b) {
                                if (_packSort.startsWith('price')) {
                                  int ac = 0;
                                  int bc = 0;
                                  final apm = (a['price_map'] as Map?)?.cast<String, dynamic>();
                                  final bpm = (b['price_map'] as Map?)?.cast<String, dynamic>();
                                  ac = (apm?['BRL'] as int?) ?? (a['price_cents'] as int? ?? 0);
                                  bc = (bpm?['BRL'] as int?) ?? (b['price_cents'] as int? ?? 0);
                                  return _packSort == 'price_desc' ? bc.compareTo(ac) : ac.compareTo(bc);
                                }
                                final an = ((a['name'] ?? '') as String).toLowerCase();
                                final bn = ((b['name'] ?? '') as String).toLowerCase();
                                return _packSort == 'name_desc' ? bn.compareTo(an) : an.compareTo(bn);
                              });
                              if (list.isEmpty) return const Center(child: Text('Nenhum pacote'));
                              return ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final p = list[i];
                                  final name = (p['name'] ?? '-') as String;
                                  final desc = (p['description'] ?? '') as String;
                                  final catName = (() {
                                    final id = p['category_id'] as String?;
                                    final byId = _categoryNameById(id);
                                    if (byId.isNotEmpty) return byId;
                                    return (p['category'] as String?) ?? '';
                                  })();
                                  return ListTile(
                                    leading: _productLeadingThumb(p),
                                    title: Row(children: [
                                      Expanded(child: Text(name)),
                                      if (catName.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Chip(
                                            label: Text(catName),
                                            visualDensity: VisualDensity.compact,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                    ]),
                                    subtitle: canViewValues
                                        ? Text(desc.isNotEmpty ? '${_priceSummary(p)}\n$desc' : _priceSummary(p))
                                        : (desc.isNotEmpty ? Text(desc) : null),
                                    isThreeLine: desc.isNotEmpty,
                                    trailing: (appState.isAdmin || appState.isGestor || appState.isDesigner)
                                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                                            IconOnlyButton(icon: Icons.edit_outlined, tooltip: 'Editar', onPressed: () => _editPackage(p)),
                                            IconOnlyButton(icon: Icons.delete_outline, tooltip: 'Excluir', onPressed: () => _confirmDelete('packages', (p['id'] ?? '').toString())),
                                          ])
                                        : null,
                                  );
                                },
                              );
                            }),
                          ),
                        ]),

                        // Categorias
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Barra de busca, filtro e ordenação
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 8),
                              child: Row(children: [
                                // Busca
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Pesquisar categoria...'),
                                    onChanged: (v) => setState(() => _catSearch = v.trim()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Filtro
                                SizedBox(
                                  width: 150,
                                  child: GenericDropdownField<String>(
                                    value: ['todas','com','sem'][_catFilter],
                                    items: const [
                                      DropdownItem(value: 'todas', label: 'Todas'),
                                      DropdownItem(value: 'com', label: 'Com produtos'),
                                      DropdownItem(value: 'sem', label: 'Sem produtos'),
                                    ],
                                    onChanged: (v) => setState(() => _catFilter = {'todas':0,'com':1,'sem':2}[v]!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Ordenação
                                SizedBox(
                                  width: 150,
                                  child: GenericDropdownField<String>(
                                    value: _catSort,
                                    items: const [
                                      DropdownItem(value: 'name_asc', label: 'Nome A→Z'),
                                      DropdownItem(value: 'name_desc', label: 'Nome Z→A'),
                                    ],
                                    onChanged: (v) => setState(() => _catSort = v ?? 'name_asc'),
                                  ),
                                ),
                              ]),
                            ),

                            Expanded(
                              child: Builder(builder: (context) {
                                // Aplica busca/filtro/ordenacao
                                List<Map<String, dynamic>> list = List.of(_categories);
                                if (_catSearch.isNotEmpty) {
                                  final q = _catSearch.toLowerCase();
                                  list = list.where((c) => ((c['name'] ?? '') as String).toLowerCase().contains(q)).toList();
                                }
                                if (_catFilter != 0) {
                                  list = list.where((c) {
                                    final n = (c['product_count'] as int?) ?? 0;
                                    return _catFilter == 1 ? n > 0 : n == 0;
                                  }).toList();
                                }
                                list.sort((a,b){
                                  final an = ((a['name'] ?? '') as String).toLowerCase();
                                  final bn = ((b['name'] ?? '') as String).toLowerCase();
                                  return _catSort == 'name_desc' ? bn.compareTo(an) : an.compareTo(bn);
                                });

                                if (list.isEmpty) return const Center(child: Text('Nenhuma categoria'));
                                return ListView.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final c = list[i];
                                    final name = (c['name'] ?? '') as String;
                                    final id = (c['id'] ?? '').toString();
                                    final pc = (c['product_count'] as int?) ?? 0;
                                    return ListTile(
                                      title: Row(children: [
                                        Expanded(child: Text(name)),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          child: Text('$pc produtos', style: Theme.of(context).textTheme.bodySmall),
                                        ),
                                      ]),
                                      subtitle: null,
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconOnlyButton(
                                          icon: Icons.edit_outlined, tooltip: 'Editar',
                                          onPressed: () => _editCategoryInline(initial: c),
                                        ),
                                        IconOnlyButton(
                                          icon: Icons.delete_outline, tooltip: 'Excluir',
                                          onPressed: () => _confirmDelete('catalog_categories', id),
                                        ),
                                      ]),
                                    );
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
        ),
      ]),
    );
  }
}

