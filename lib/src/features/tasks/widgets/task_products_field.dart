import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/molecules/dropdowns/multi_select_dropdown_field.dart';

/// Campo de seleção múltipla de produtos do projeto
///
/// Similar ao TaskAssigneesField, mas para produtos.
/// Exibe produtos e pacotes do catálogo do projeto.
class TaskProductsField extends StatefulWidget {
  final String? projectId;
  final List<Map<String, dynamic>> selectedProducts;
  final ValueChanged<List<Map<String, dynamic>>> onProductsChanged;
  final bool enabled;

  const TaskProductsField({
    super.key,
    required this.projectId,
    required this.selectedProducts,
    required this.onProductsChanged,
    this.enabled = true,
  });

  @override
  State<TaskProductsField> createState() => _TaskProductsFieldState();
}

class _TaskProductsFieldState extends State<TaskProductsField> {
  List<_ProductOption> _allProducts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _loadProducts();
    }
  }

  @override
  void didUpdateWidget(TaskProductsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId) {
      if (widget.projectId != null) {
        _loadProducts();
      } else {
        setState(() => _allProducts = []);
      }
    }
  }

  Future<void> _loadProducts() async {
    if (widget.projectId == null) return;

    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;

      // Buscar itens do catálogo do projeto
      final rows = await client
          .from('project_catalog_items')
          .select('kind, item_id, name, comment, position')
          .eq('project_id', widget.projectId!)
          .order('position', ascending: true, nullsFirst: true);

      final list = List<Map<String, dynamic>>.from(rows as List);

      // Coletar IDs de produtos para buscar thumbs
      final productIds = <String>{};
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

      // Buscar thumbs dos produtos
      final thumbByProduct = <String, String?>{};
      if (productIds.isNotEmpty) {
        final inList = productIds.map((e) => '"$e"').join(',');
        final prods = await client
            .from('products')
            .select('id, image_url, image_thumb_url')
            .filter('id', 'in', '($inList)');

        for (final p in (prods as List)) {
          final id = p['id'] as String?;
          if (id != null) {
            thumbByProduct[id] = (p['image_thumb_url'] ?? p['image_url']) as String?;
          }
        }
      }

      // Buscar produtos dos pacotes
      final packageProducts = <String, List<Map<String, dynamic>>>{};
      if (packageIds.isNotEmpty) {
        final inList = packageIds.map((e) => '"$e"').join(',');
        final items = await client
            .from('package_items')
            .select('package_id, product_id, products(id, name, image_url, image_thumb_url)')
            .filter('package_id', 'in', '($inList)');

        for (final item in (items as List)) {
          final packageId = item['package_id'] as String?;
          final productData = item['products'] as Map<String, dynamic>?;
          
          if (packageId != null && productData != null) {
            packageProducts.putIfAbsent(packageId, () => []);
            packageProducts[packageId]!.add(productData);
          }
        }
      }

      // Criar lista de opções
      final options = <_ProductOption>[];

      for (final r in list) {
        final kind = (r['kind'] as String?) ?? 'product';
        final itemId = (r['item_id'] ?? '').toString();
        final name = (r['name'] ?? '-') as String;
        final comment = (r['comment'] ?? '') as String;

        if (itemId.isEmpty) continue;

        if (kind == 'product') {
          // Produto direto
          options.add(_ProductOption(
            productId: itemId,
            packageId: null,
            label: name,
            packageName: null,
            comment: comment,
            thumbUrl: thumbByProduct[itemId],
          ));
        } else if (kind == 'package') {
          // Produtos do pacote
          final prods = packageProducts[itemId] ?? [];
          for (final p in prods) {
            final productId = p['id'] as String?;
            final productName = p['name'] as String?;
            final thumbUrl = (p['image_thumb_url'] ?? p['image_url']) as String?;

            if (productId != null && productName != null) {
              options.add(_ProductOption(
                productId: productId,
                packageId: itemId,
                label: productName,
                packageName: packageNames[itemId],
                comment: comment,
                thumbUrl: thumbUrl,
              ));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allProducts = options;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allProducts = [];
          _loading = false;
        });
      }
    }
  }

  String _getProductKey(Map<String, dynamic> product) {
    final productId = product['productId'] ?? '';
    final packageId = product['packageId'] ?? '';
    return '$productId:$packageId';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.projectId == null) {
      return const SizedBox.shrink();
    }

    // Converter produtos selecionados para lista de keys
    final selectedKeys = widget.selectedProducts
        .map((p) => _getProductKey(p))
        .toList();

    // Criar itens do dropdown
    final items = _allProducts.map((option) {
      final key = '${option.productId}:${option.packageId ?? ''}';

      return MultiSelectDropdownItem<String>(
        value: key,
        label: option.packageName != null
            ? '${option.label} (${option.packageName})'
            : option.label,
        leadingIcon: option.thumbUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  option.thumbUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 32),
                ),
              )
            : const Icon(Icons.image, size: 32),
      );
    }).toList();

    return MultiSelectDropdownField<String>(
      selectedValues: selectedKeys,
      items: items,
      onChanged: (keys) {
        // Converter keys de volta para produtos
        final products = keys.map((key) {
          final option = _allProducts.firstWhere(
            (o) => '${o.productId}:${o.packageId ?? ''}' == key,
          );

          return {
            'productId': option.productId,
            'packageId': option.packageId,
            'label': option.label,
            'packageName': option.packageName,
            'comment': option.comment,
            'thumbUrl': option.thumbUrl,
          };
        }).toList();

        widget.onProductsChanged(products);
      },
      labelText: 'Produtos',
      hintText: 'Selecione produtos...',
      enabled: widget.enabled,
    );
  }
}

class _ProductOption {
  final String productId;
  final String? packageId;
  final String label;
  final String? packageName;
  final String comment;
  final String? thumbUrl;

  _ProductOption({
    required this.productId,
    required this.packageId,
    required this.label,
    required this.packageName,
    required this.comment,
    required this.thumbUrl,
  });
}

