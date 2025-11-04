import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/ui/organisms/lists/lists.dart';
import 'package:my_business/src/features/catalog/_select_products_dialog.dart';
import 'package:my_business/src/features/catalog/widgets/catalog_status_badge.dart';
import 'package:my_business/src/state/app_state_scope.dart';
import 'package:my_business/modules/modules.dart';
import 'package:my_business/modules/common/organization_context.dart';
import 'package:my_business/ui/organisms/tabs/tabs.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';
import 'package:image/image.dart' as img;
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/organisms/tables/dynamic_paginated_table.dart';
import 'package:my_business/ui/organisms/tables/table_search_filter_bar.dart';
import 'package:my_business/ui/organisms/tables/reusable_data_table.dart';
import 'package:my_business/ui/molecules/table_cells/table_cells.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_area.dart';
import 'package:my_business/services/mentions_service.dart';
import '../../services/permissions_service.dart';
import '../../navigation/user_role.dart';


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

  // Filtros de categorias
  String _catSearch = '';
  int _catFilter = 0; // 0=Todas, 1=Com produtos, 2=Sem produtos

  // Filtros de produtos
  String _prodSearch = '';
  String _prodFilterType = 'none'; // 'none', 'category', 'status'
  String? _prodFilterValue; // valor do filtro selecionado

  // Filtros de pacotes
  String _packSearch = '';
  String _packFilterType = 'none'; // 'none', 'category', 'status'
  String? _packFilterValue; // valor do filtro selecionado

  // Seleção de itens
  Set<String> _selectedProductIds = {};
  Set<String> _selectedPackageIds = {};
  Set<String> _selectedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }




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
      // Obter organization_id da organização ativa
      final organizationId = OrganizationContext.currentOrganizationId;
      if (organizationId == null) {
        throw Exception('Nenhuma organização ativa');
      }

      // Sanitizar nome do produto/pacote para usar no nome do arquivo
      final sanitizedName = productName.trim().isEmpty
          ? 'produto'
          : productName.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = 'thumb-$sanitizedName.jpg';
      final path = '$organizationId/$fileName';

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

  String _fmt(int cents) => (cents / 100.0).toStringAsFixed(2).replaceAll('.', ',');

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'BRL':
        return 'R\$';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return code;
    }
  }

  String _priceSummary(Map<String, dynamic> row) {
    final pm = (row['price_map'] as Map?)?.cast<String, dynamic>();
    if (pm != null && pm.isNotEmpty) {
      const order = ['BRL', 'USD', 'EUR'];
      final parts = <String>[];
      for (final code in order) {
        final v = pm[code];
        if (v is int) parts.add('${_currencySymbol(code)} ${_fmt(v)}');
      }
      pm.forEach((code, v) { if (!order.contains(code) && v is int) parts.add('${_currencySymbol(code)} ${_fmt(v)}'); });
      return parts.isEmpty ? '-' : parts.join(' • ');
    }
    final code = (row['currency_code'] as String?) ?? 'BRL';
    final cents = (row['price_cents'] as int?) ?? 0;
    return '${_currencySymbol(code)} ${_fmt(cents)}';
  }


  Widget _productLeadingThumb(Map<String, dynamic> p) {
    final url = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: url == null || url.isEmpty
          ? Icon(
              Icons.image_not_supported,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(url, width: 48, height: 48, fit: BoxFit.cover),
            ),
    );
  }

  Future<void> _editCategoryInline({Map<String, dynamic>? initial}) async {
    String? localErr;
    bool saving = false;
    final controller = TextEditingController(text: (initial?['name'] ?? '') as String);
    final ok = await DialogHelper.show<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        Future<void> doSave() async {
          setState(() { saving = true; localErr = null; });
          try {
            final name = controller.text.trim();
            if (name.isEmpty) throw 'Informe o nome da categoria';
            final client = Supabase.instance.client;
            if (initial == null) {
              // Adicionar organization_id ao criar categoria
              final orgId = OrganizationContext.currentOrganizationId;
              if (orgId == null) throw 'Nenhuma organização ativa';

              debugPrint('📁 Criando categoria: $name (org: $orgId)');

              await client.from('catalog_categories').insert({
                'name': name,
                'organization_id': orgId,
              });

              debugPrint('✅ Categoria criada com sucesso');
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
    final ok = await DialogHelper.show<bool>(
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
          await DialogHelper.show(
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

  /// Exclusão em lote de produtos
  Future<void> _bulkDeleteProducts() async {
    if (_selectedProductIds.isEmpty) return;

    final count = _selectedProductIds.length;
    final ok = await DialogHelper.show<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Excluir Produtos',
        message: 'Tem certeza que deseja excluir $count produto${count > 1 ? 's' : ''}?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (ok == true) {
      try {
        await Supabase.instance.client
            .from('products')
            .delete()
            .inFilter('id', _selectedProductIds.toList());

        setState(() => _selectedProductIds.clear());
        await _reload();
      } catch (e) {
        if (!mounted) return;
        String? friendly;

        if (e is PostgrestException && e.code == '23503') {
          friendly = 'Não é possível excluir um ou mais produtos pois estão sendo usados em pacotes.';
        }

        if (friendly != null) {
          await DialogHelper.show(
            context: context,
            builder: (_) => StandardDialog(
              title: 'Erro ao Excluir',
              child: Text(friendly!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
        }
      }
    }
  }

  /// Exclusão em lote de pacotes
  Future<void> _bulkDeletePackages() async {
    if (_selectedPackageIds.isEmpty) return;

    final count = _selectedPackageIds.length;
    final ok = await DialogHelper.show<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Excluir Pacotes',
        message: 'Tem certeza que deseja excluir $count pacote${count > 1 ? 's' : ''}?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (ok == true) {
      try {
        await Supabase.instance.client
            .from('packages')
            .delete()
            .inFilter('id', _selectedPackageIds.toList());

        setState(() => _selectedPackageIds.clear());
        await _reload();
      } catch (e) {
        if (!mounted) return;
        String? friendly;

        if (e is PostgrestException && e.code == '23503') {
          friendly = 'Não é possível excluir um ou mais pacotes pois possuem itens vinculados.';
        }

        if (friendly != null) {
          await DialogHelper.show(
            context: context,
            builder: (_) => StandardDialog(
              title: 'Erro ao Excluir',
              child: Text(friendly!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
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
      final ok = await DialogHelper.show<bool>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (context, setState) {
          Future<void> doSave() async {
            setState(() { saving = true; localErr = null; });
            try {
              final name = controller.text.trim();
              if (name.isEmpty) throw 'Informe o nome da categoria';
              final client = Supabase.instance.client;
              if (initial == null) {
                // Adicionar organization_id ao criar categoria
                final orgId = OrganizationContext.currentOrganizationId;
                if (orgId == null) throw 'Nenhuma organização ativa';

                debugPrint('📁 Criando categoria: $name (org: $orgId)');

                await client.from('catalog_categories').insert({
                  'name': name,
                  'organization_id': orgId,
                });

                debugPrint('✅ Categoria criada com sucesso');
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
    await DialogHelper.show<void>(
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
    String status = (initial?['status'] as String?) ?? 'active';

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
    final saved = await DialogHelper.show<bool>(
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

            final userId = authModule.currentUser?.id;

            final payload = <String, dynamic>{
              'name': name.text.trim(),
              'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
              'category_id': categoryId,
              'category': selectedName, // fallback para compatibilidade
              'status': status,
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
            String? itemId;
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
              // Adicionar organization_id
              final orgId = OrganizationContext.currentOrganizationId;
              if (orgId == null) throw 'Nenhuma organização ativa';
              payload['organization_id'] = orgId;

              // Salvar created_by
              if (userId != null) {
                payload['created_by'] = userId;
                payload['updated_by'] = userId;
              }

              debugPrint('🛍️ Criando ${table == 'products' ? 'produto' : 'pacote'}: ${payload['name']} (org: $orgId)');

              final ins = await client.from(table).insert(payload).select('id').single();
              itemId = (ins['id'] ?? '').toString();

              debugPrint('✅ ${table == 'products' ? 'Produto' : 'Pacote'} criado com sucesso: $itemId');
              if (table == 'packages') {
                final newId = itemId;
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
              // Salvar updated_by
              if (userId != null) {
                payload['updated_by'] = userId;
              }
              itemId = (initial['id'] ?? '').toString();
              await client.from(table).update(payload).eq('id', itemId);
              if (table == 'packages') {
                final pkgId = itemId;

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

            // Salvar menções da descrição
            final mentionsService = MentionsService();
            try {
              if (table == 'products') {
                await mentionsService.saveProductMentions(
                  productId: itemId,
                  fieldName: 'description',
                  content: desc.text,
                );
              } else if (table == 'packages') {
                await mentionsService.savePackageMentions(
                  packageId: itemId,
                  fieldName: 'description',
                  content: desc.text,
                );
              }
            } catch (e) {
              debugPrint('Erro ao salvar menções da descrição: $e');
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
                  MentionTextArea(
                    controller: desc,
                    labelText: 'Descrição',
                    hintText: 'Descrição do pacote... (digite @ para mencionar)',
                    minLines: 2,
                    maxLines: 4,
                    onMentionsChanged: (userIds) {
                      // Menções serão salvas ao salvar o pacote
                    },
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
                  MentionTextArea(
                    controller: desc,
                    labelText: 'Descrição',
                    hintText: 'Descrição do produto... (digite @ para mencionar)',
                    minLines: 2,
                    maxLines: 4,
                    onMentionsChanged: (userIds) {
                      // Menções serão salvas ao salvar o produto
                    },
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
                        final added = await DialogHelper.show<List<Map<String, dynamic>>>(
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
                      final unitFmt = '${_currencySymbol('BRL')} ${_fmt(centsBRL)}';
                      final totalFmt = '${_currencySymbol('BRL')} ${_fmt(centsBRL * qty)}';
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
                                final ok = await DialogHelper.show<bool>(
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
                            Text('${_currencySymbol('BRL')} $fBRL • ${_currencySymbol('USD')} $fUSD • ${_currencySymbol('EUR')} $fEUR', style: Theme.of(context).textTheme.bodySmall),
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
                  // Dropdown de Status
                  GenericDropdownField<String>(
                    value: status,
                    items: const [
                      DropdownItem(value: 'active', label: 'Ativo'),
                      DropdownItem(value: 'inactive', label: 'Inativo'),
                      DropdownItem(value: 'discontinued', label: 'Descontinuado'),
                      DropdownItem(value: 'coming_soon', label: 'Em breve'),
                    ],
                    labelText: 'Status',
                    onChanged: (v) => setState(() => status = v ?? 'active'),
                    enabled: !saving,
                  ),
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
                    decoration: const InputDecoration(labelText: 'R\$'),
                    onChanged: (_) => setState(() => autoBRL = false),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: usd,
                    decoration: const InputDecoration(labelText: '\$'),
                    onChanged: (_) => setState(() => autoUSD = false),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: eur,
                    decoration: const InputDecoration(labelText: '€'),
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

  Widget _buildCategoriesTab(appState) {
    // Filtrar categorias
    var filteredCategories = List<Map<String, dynamic>>.from(_categories);
    if (_catSearch.isNotEmpty) {
      final q = _catSearch.toLowerCase();
      filteredCategories = filteredCategories.where((c) => ((c['name'] ?? '') as String).toLowerCase().contains(q)).toList();
    }
    if (_catFilter != 0) {
      filteredCategories = filteredCategories.where((c) {
        final n = (c['product_count'] as int?) ?? 0;
        return _catFilter == 1 ? n > 0 : n == 0;
      }).toList();
    }

    return Column(
      children: [
        // Barra de busca e filtros
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: TableSearchFilterBar(
            searchHint: 'Pesquisar categoria...',
            onSearchChanged: (v) => setState(() => _catSearch = v.trim()),
            filterType: ['todas', 'com', 'sem'][_catFilter],
            filterTypeLabel: 'Filtro',
            filterTypeOptions: const [
              FilterOption(value: 'todas', label: 'Todas'),
              FilterOption(value: 'com', label: 'Com produtos'),
              FilterOption(value: 'sem', label: 'Sem produtos'),
            ],
            onFilterTypeChanged: (v) => setState(() => _catFilter = {'todas': 0, 'com': 1, 'sem': 2}[v]!),
            showFilters: true,
            actionButton: FilledButton.icon(
              onPressed: _newCategory,
              icon: const Icon(Icons.category),
              label: const Text('Nova Categoria'),
            ),
          ),
        ),
        // Tabela
        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: filteredCategories,
            columns: const [
              DataTableColumn(label: 'Nome', sortable: true),
              DataTableColumn(label: 'Produtos', sortable: true),
            ],
            cellBuilders: [
              (c) => Text((c['name'] ?? '') as String),
              (c) {
                final pc = (c['product_count'] as int?) ?? 0;
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text('$pc produtos', style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ],
            sortComparators: [
              (a, b) => ((a['name'] ?? '') as String).toLowerCase().compareTo(((b['name'] ?? '') as String).toLowerCase()),
              (a, b) => ((a['product_count'] as int?) ?? 0).compareTo((b['product_count'] as int?) ?? 0),
            ],
            getId: (c) => (c['id'] ?? '').toString(),
            itemLabel: 'categoria(s)',
            selectedIds: _selectedCategoryIds,
            onSelectionChanged: (ids) => setState(() => _selectedCategoryIds = ids),
            actions: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canEdit = permissionsService.canUpdate(userRole, PermissionEntity.category);
              final canDelete = permissionsService.canDelete(userRole, PermissionEntity.category);

              final actions = <DataTableAction<Map<String, dynamic>>>[];
              if (canEdit) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onPressed: (c) => _editCategoryInline(initial: c),
                ));
              }
              if (canDelete) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.delete_outline,
                  label: 'Excluir',
                  onPressed: (c) => _confirmDelete('catalog_categories', (c['id'] ?? '').toString()),
                ));
              }
              return actions.isEmpty ? null : actions;
            })(),
            emptyWidget: const Center(child: Text('Nenhuma categoria')),
          ),
        ),
      ],
    );
  }

  Widget _buildPackagesTab(appState, bool canViewValues) {
    // Filtrar pacotes
    var filteredPackages = List<Map<String, dynamic>>.from(_packages);
    if (_packSearch.isNotEmpty) {
      final q = _packSearch.toLowerCase();
      filteredPackages = filteredPackages.where((p) {
        final n = ((p['name'] ?? '') as String).toLowerCase();
        final d = ((p['description'] ?? '') as String).toLowerCase();
        return n.contains(q) || d.contains(q);
      }).toList();
    }
    // Aplicar filtro baseado no tipo selecionado
    if (_packFilterType == 'category' && _packFilterValue != null && _packFilterValue!.isNotEmpty) {
      filteredPackages = filteredPackages.where((p) => ((p['category_id'] ?? '') as String?) == _packFilterValue).toList();
    } else if (_packFilterType == 'status' && _packFilterValue != null && _packFilterValue!.isNotEmpty) {
      filteredPackages = filteredPackages.where((p) => ((p['status'] ?? 'active') as String) == _packFilterValue).toList();
    }

    return Column(
      children: [
        // Barra de busca e filtros
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: TableSearchFilterBar(
            searchHint: 'Pesquisar pacote...',
            onSearchChanged: (v) => setState(() => _packSearch = v.trim()),
            filterType: _packFilterType,
            filterTypeLabel: 'Tipo de filtro',
            filterTypeOptions: const [
              FilterOption(value: 'none', label: 'Nenhum'),
              FilterOption(value: 'category', label: 'Categoria'),
              FilterOption(value: 'status', label: 'Status'),
            ],
            onFilterTypeChanged: (v) => setState(() {
              _packFilterType = v ?? 'none';
              _packFilterValue = null; // Limpa o valor ao mudar o tipo
            }),
            filterValue: _packFilterValue,
            filterValueLabel: _packFilterType == 'category' ? 'Categoria' : 'Status',
            filterValueOptions: _packFilterType == 'category'
                ? _categories.map((c) => (c['id'] ?? '').toString()).toList()
                : ['active', 'inactive', 'discontinued', 'coming_soon'],
            filterValueLabelBuilder: (v) {
              if (_packFilterType == 'category') {
                final cat = _categories.firstWhere(
                  (c) => (c['id'] ?? '').toString() == v,
                  orElse: () => {'name': v},
                );
                return (cat['name'] ?? v) as String;
              } else {
                switch (v) {
                  case 'active': return 'Ativos';
                  case 'inactive': return 'Inativos';
                  case 'discontinued': return 'Descontinuados';
                  case 'coming_soon': return 'Em breve';
                  default: return v;
                }
              }
            },
            onFilterValueChanged: (v) => setState(() => _packFilterValue = (v == null || v.isEmpty) ? null : v),
            showFilters: true,
            selectedCount: _selectedPackageIds.length,
            bulkActions: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canDelete = permissionsService.canDelete(userRole, PermissionEntity.package_);
              return canDelete ? [
                BulkAction(
                  icon: Icons.delete_outline,
                  label: 'Excluir selecionados',
                  onPressed: () => _bulkDeletePackages(),
                ),
              ] : null;
            })(),
            actionButton: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canCreate = permissionsService.canCreate(userRole, PermissionEntity.package_);
              return canCreate ? FilledButton.icon(
                onPressed: _newPackage,
                icon: const Icon(Icons.add_card),
                label: const Text('Novo Pacote'),
              ) : null;
            })(),
          ),
        ),
        // Tabela
        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: filteredPackages,
            columns: [
              const DataTableColumn(label: 'Nome', sortable: true),
              if (canViewValues) const DataTableColumn(label: 'Preço', sortable: true),
              const DataTableColumn(label: 'Categoria', sortable: true),
              const DataTableColumn(label: 'Status', sortable: true),
              const DataTableColumn(label: 'Atualizado', sortable: true),
              const DataTableColumn(label: 'Criado', sortable: true),
            ],
            cellBuilders: [
              (p) => Row(
                children: [
                  _productLeadingThumb(p),
                  const SizedBox(width: 12),
                  Expanded(child: Text((p['name'] ?? '-') as String)),
                ],
              ),
              if (canViewValues) (p) => Text(_priceSummary(p)),
              (p) {
                final id = p['category_id'] as String?;
                final catName = _categoryNameById(id);
                if (catName.isEmpty) return const Text('-');
                return Text(catName);
              },
              (p) {
                final status = (p['status'] ?? 'active') as String;
                return CatalogStatusBadge(status: status);
              },
              (p) => TableCellUpdatedBy(
                date: p['updated_at'],
                profile: p['updated_by_profile'] as Map<String, dynamic>?,
                dateFormat: TableCellDateFormat.short,
                avatarSize: 10,
              ),
              (p) => TableCellUpdatedBy(
                date: p['created_at'],
                profile: p['created_by_profile'] as Map<String, dynamic>?,
                dateFormat: TableCellDateFormat.short,
                avatarSize: 10,
              ),
            ],
            sortComparators: [
              (a, b) => ((a['name'] ?? '') as String).toLowerCase().compareTo(((b['name'] ?? '') as String).toLowerCase()),
              if (canViewValues) (a, b) {
                int ac = 0;
                int bc = 0;
                final apm = (a['price_map'] as Map?)?.cast<String, dynamic>();
                final bpm = (b['price_map'] as Map?)?.cast<String, dynamic>();
                ac = (apm?['BRL'] as int?) ?? (a['price_cents'] as int? ?? 0);
                bc = (bpm?['BRL'] as int?) ?? (b['price_cents'] as int? ?? 0);
                return ac.compareTo(bc);
              },
              (a, b) => _categoryNameById(a['category_id'] as String?).compareTo(_categoryNameById(b['category_id'] as String?)),
              (a, b) => ((a['status'] ?? 'active') as String).compareTo((b['status'] ?? 'active') as String),
              (a, b) {
                final aDate = a['updated_at'] != null ? DateTime.parse(a['updated_at'].toString()) : DateTime(1970);
                final bDate = b['updated_at'] != null ? DateTime.parse(b['updated_at'].toString()) : DateTime(1970);
                return bDate.compareTo(aDate); // Mais recente primeiro
              },
              (a, b) {
                final aDate = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime(1970);
                final bDate = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime(1970);
                return bDate.compareTo(aDate); // Mais recente primeiro
              },
            ],
            getId: (p) => (p['id'] ?? '').toString(),
            itemLabel: 'pacote(s)',
            selectedIds: _selectedPackageIds,
            onSelectionChanged: (ids) => setState(() => _selectedPackageIds = ids),
            actions: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canEdit = permissionsService.canUpdate(userRole, PermissionEntity.package_);
              final canDelete = permissionsService.canDelete(userRole, PermissionEntity.package_);

              final actions = <DataTableAction<Map<String, dynamic>>>[];
              if (canEdit) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onPressed: (p) => _editPackage(p),
                ));
              }
              if (canDelete) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.delete_outline,
                  label: 'Excluir',
                  onPressed: (p) => _confirmDelete('packages', (p['id'] ?? '').toString()),
                ));
              }
              return actions.isEmpty ? null : actions;
            })(),
            emptyWidget: const Center(child: Text('Nenhum pacote')),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab(appState, bool canViewValues) {
    // Filtrar produtos
    var filteredProducts = List<Map<String, dynamic>>.from(_products);
    if (_prodSearch.isNotEmpty) {
      final q = _prodSearch.toLowerCase();
      filteredProducts = filteredProducts.where((p) {
        final n = ((p['name'] ?? '') as String).toLowerCase();
        final d = ((p['description'] ?? '') as String).toLowerCase();
        return n.contains(q) || d.contains(q);
      }).toList();
    }
    // Aplicar filtro baseado no tipo selecionado
    if (_prodFilterType == 'category' && _prodFilterValue != null && _prodFilterValue!.isNotEmpty) {
      filteredProducts = filteredProducts.where((p) => ((p['category_id'] ?? '') as String?) == _prodFilterValue).toList();
    } else if (_prodFilterType == 'status' && _prodFilterValue != null && _prodFilterValue!.isNotEmpty) {
      filteredProducts = filteredProducts.where((p) => ((p['status'] ?? 'active') as String) == _prodFilterValue).toList();
    }

    return Column(
      children: [
        // Barra de busca e filtros
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: TableSearchFilterBar(
            searchHint: 'Pesquisar produto...',
            onSearchChanged: (v) => setState(() => _prodSearch = v.trim()),
            filterType: _prodFilterType,
            filterTypeLabel: 'Tipo de filtro',
            filterTypeOptions: const [
              FilterOption(value: 'none', label: 'Nenhum'),
              FilterOption(value: 'category', label: 'Categoria'),
              FilterOption(value: 'status', label: 'Status'),
            ],
            onFilterTypeChanged: (v) => setState(() {
              _prodFilterType = v ?? 'none';
              _prodFilterValue = null; // Limpa o valor ao mudar o tipo
            }),
            filterValue: _prodFilterValue,
            filterValueLabel: _prodFilterType == 'category' ? 'Categoria' : 'Status',
            filterValueOptions: _prodFilterType == 'category'
                ? _categories.map((c) => (c['id'] ?? '').toString()).toList()
                : ['active', 'inactive', 'discontinued', 'coming_soon'],
            filterValueLabelBuilder: (v) {
              if (_prodFilterType == 'category') {
                final cat = _categories.firstWhere(
                  (c) => (c['id'] ?? '').toString() == v,
                  orElse: () => {'name': v},
                );
                return (cat['name'] ?? v) as String;
              } else {
                switch (v) {
                  case 'active': return 'Ativos';
                  case 'inactive': return 'Inativos';
                  case 'discontinued': return 'Descontinuados';
                  case 'coming_soon': return 'Em breve';
                  default: return v;
                }
              }
            },
            onFilterValueChanged: (v) => setState(() => _prodFilterValue = (v == null || v.isEmpty) ? null : v),
            showFilters: true,
            selectedCount: _selectedProductIds.length,
            bulkActions: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canDelete = permissionsService.canDelete(userRole, PermissionEntity.product);
              return canDelete ? [
                BulkAction(
                  icon: Icons.delete_outline,
                  label: 'Excluir selecionados',
                  onPressed: () => _bulkDeleteProducts(),
                ),
              ] : null;
            })(),
            actionButton: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canCreate = permissionsService.canCreate(userRole, PermissionEntity.product);
              return canCreate ? FilledButton.icon(
                onPressed: _newProduct,
                icon: const Icon(Icons.add),
                label: const Text('Novo Produto'),
              ) : null;
            })(),
          ),
        ),
        // Tabela
        Expanded(
          child: DynamicPaginatedTable<Map<String, dynamic>>(
            items: filteredProducts,
            columns: [
              const DataTableColumn(label: 'Nome', sortable: true),
              if (canViewValues) const DataTableColumn(label: 'Preço', sortable: true),
              const DataTableColumn(label: 'Categoria', sortable: true),
              const DataTableColumn(label: 'Status', sortable: true),
              const DataTableColumn(label: 'Atualizado', sortable: true),
              const DataTableColumn(label: 'Criado', sortable: true),
            ],
            cellBuilders: [
              (p) => Row(
                children: [
                  _productLeadingThumb(p),
                  const SizedBox(width: 12),
                  Expanded(child: Text((p['name'] ?? '-') as String)),
                ],
              ),
              if (canViewValues) (p) => Text(_priceSummary(p)),
              (p) {
                final id = p['category_id'] as String?;
                final catName = _categoryNameById(id);
                if (catName.isEmpty) return const Text('-');
                return Text(catName);
              },
              (p) {
                final status = (p['status'] ?? 'active') as String;
                return CatalogStatusBadge(status: status);
              },
              (p) => TableCellUpdatedBy(
                date: p['updated_at'],
                profile: p['updated_by_profile'] as Map<String, dynamic>?,
                dateFormat: TableCellDateFormat.short,
                avatarSize: 10,
              ),
              (p) => TableCellUpdatedBy(
                date: p['created_at'],
                profile: p['created_by_profile'] as Map<String, dynamic>?,
                dateFormat: TableCellDateFormat.short,
                avatarSize: 10,
              ),
            ],
            sortComparators: [
              (a, b) => ((a['name'] ?? '') as String).toLowerCase().compareTo(((b['name'] ?? '') as String).toLowerCase()),
              if (canViewValues) (a, b) {
                int ac = 0;
                int bc = 0;
                final apm = (a['price_map'] as Map?)?.cast<String, dynamic>();
                final bpm = (b['price_map'] as Map?)?.cast<String, dynamic>();
                ac = (apm?['BRL'] as int?) ?? (a['price_cents'] as int? ?? 0);
                bc = (bpm?['BRL'] as int?) ?? (b['price_cents'] as int? ?? 0);
                return ac.compareTo(bc);
              },
              (a, b) => _categoryNameById(a['category_id'] as String?).compareTo(_categoryNameById(b['category_id'] as String?)),
              (a, b) => ((a['status'] ?? 'active') as String).compareTo((b['status'] ?? 'active') as String),
              (a, b) {
                final aDate = a['updated_at'] != null ? DateTime.parse(a['updated_at'].toString()) : DateTime(1970);
                final bDate = b['updated_at'] != null ? DateTime.parse(b['updated_at'].toString()) : DateTime(1970);
                return bDate.compareTo(aDate); // Mais recente primeiro
              },
              (a, b) {
                final aDate = a['created_at'] != null ? DateTime.parse(a['created_at'].toString()) : DateTime(1970);
                final bDate = b['created_at'] != null ? DateTime.parse(b['created_at'].toString()) : DateTime(1970);
                return bDate.compareTo(aDate); // Mais recente primeiro
              },
            ],
            getId: (p) => (p['id'] ?? '').toString(),
            itemLabel: 'produto(s)',
            selectedIds: _selectedProductIds,
            onSelectionChanged: (ids) => setState(() => _selectedProductIds = ids),
            actions: (() {
              final userRole = UserRoleExtension.fromString(appState.role);
              final canEdit = permissionsService.canUpdate(userRole, PermissionEntity.product);
              final canDelete = permissionsService.canDelete(userRole, PermissionEntity.product);

              final actions = <DataTableAction<Map<String, dynamic>>>[];
              if (canEdit) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onPressed: (p) => _editProduct(p),
                ));
              }
              if (canDelete) {
                actions.add(DataTableAction<Map<String, dynamic>>(
                  icon: Icons.delete_outline,
                  label: 'Excluir',
                  onPressed: (p) => _confirmDelete('products', (p['id'] ?? '').toString()),
                ));
              }
              return actions.isEmpty ? null : actions;
            })(),
            emptyWidget: const Center(child: Text('Nenhum produto')),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    // Verificar permissão: apenas Admin, Gestor e Financeiro
    if (!appState.isAdmin && !appState.isGestor && !appState.isFinanceiro) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas Administradores, Gestores e Financeiros podem acessar o Catálogo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final canViewValues = appState.isAdmin || appState.isFinanceiro;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Catálogo', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
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
                        _buildProductsTab(appState, canViewValues),
                        // Pacotes
                        _buildPackagesTab(appState, canViewValues),

                        // Categorias
                        _buildCategoriesTab(appState),
                      ],
                    ),
        ),
      ]),
    );
  }
}

