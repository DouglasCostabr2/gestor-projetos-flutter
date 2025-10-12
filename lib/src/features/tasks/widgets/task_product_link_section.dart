import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'select_project_product_dialog.dart';
import 'linked_preview.dart';

/// Reusable Task Product Link Section Widget
///
/// Allows linking MULTIPLE products from the project catalog to the task.
/// Shows preview cards with thumbnail, name, package, and comment.
/// Indicates if product is already linked to another task with option to unlink.
///
/// Features:
/// - Multiple product selection
/// - Preview cards with thumbnails
/// - "Already linked" indicator with task name
/// - Unlink from other task option
/// - Remove functionality
/// - Automatic data loading from Supabase
///
/// Usage:
/// ```dart
/// TaskProductLinkSection(
///   projectId: _projectId,
///   taskId: _taskId, // null for new tasks
///   onLinkedProductsChanged: (products) {
///     setState(() => _linkedProducts = products);
///   },
///   enabled: !_saving,
/// )
/// ```
class TaskProductLinkSection extends StatefulWidget {
  final String? projectId;
  final String? taskId; // null for new tasks
  final void Function(List<Map<String, dynamic>> products) onLinkedProductsChanged;
  final bool enabled;

  const TaskProductLinkSection({
    super.key,
    required this.projectId,
    required this.taskId,
    required this.onLinkedProductsChanged,
    this.enabled = true,
  });

  @override
  State<TaskProductLinkSection> createState() => _TaskProductLinkSectionState();
}

class _TaskProductLinkSectionState extends State<TaskProductLinkSection> {
  List<Map<String, dynamic>> _linkedProducts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _loadLinkedProducts();
    }
  }

  @override
  void didUpdateWidget(TaskProductLinkSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.taskId != oldWidget.taskId) {
      if (widget.taskId != null) {
        _loadLinkedProducts();
      } else {
        setState(() => _linkedProducts = []);
      }
    }
  }

  Future<void> _loadLinkedProducts() async {
    if (widget.taskId == null) {
      debugPrint('TaskProductLinkSection: taskId is null, skipping load');
      return;
    }

    debugPrint('TaskProductLinkSection: Loading products for task ${widget.taskId}');
    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;

      // Load linked products from task_products table
      final taskProducts = await client
          .from('task_products')
          .select('product_id, package_id')
          .eq('task_id', widget.taskId!);

      debugPrint('TaskProductLinkSection: Found ${taskProducts.length} linked products');

      final products = <Map<String, dynamic>>[];

      for (final tp in taskProducts) {
        final productId = tp['product_id'] as String;
        final packageId = tp['package_id'] as String?;

        // Load product details
        final prod = await client
            .from('products')
            .select('id, name, image_thumb_url, image_url')
            .eq('id', productId)
            .maybeSingle();

        if (prod == null) continue;

        String label = (prod['name'] ?? '-') as String;
        final thumbUrl = (prod['image_thumb_url'] as String?) ??
                         (prod['image_url'] as String?) ?? '';
        String packageName = '';
        String comment = '';

        // Load package info if linked to package
        if (packageId != null && packageId.isNotEmpty) {
          final pkg = await client
              .from('packages')
              .select('id, name')
              .eq('id', packageId)
              .maybeSingle();
          packageName = (pkg?['name'] ?? '') as String;

          final pkgi = await client
              .from('package_items')
              .select('comment')
              .eq('package_id', packageId)
              .eq('product_id', productId)
              .maybeSingle();
          comment = (pkgi?['comment'] as String?) ?? '';
        } else if (widget.projectId != null) {
          // Load from project catalog
          final pci = await client
              .from('project_catalog_items')
              .select('comment')
              .eq('project_id', widget.projectId!)
              .eq('kind', 'product')
              .eq('item_id', productId)
              .maybeSingle();
          comment = (pci?['comment'] as String?) ?? '';
        }

        products.add({
          'productId': productId,
          'packageId': packageId,
          'label': label,
          'packageName': packageName,
          'comment': comment,
          'thumbUrl': thumbUrl,
        });
      }

      if (!mounted) return;

      debugPrint('TaskProductLinkSection: Loaded ${products.length} products, notifying parent');

      setState(() {
        _linkedProducts = products;
        _loading = false;
      });

      // Notify parent
      widget.onLinkedProductsChanged(products);
    } catch (e) {
      debugPrint('Error loading linked products: $e');
      if (mounted) {
        setState(() {
          _linkedProducts = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectProduct() async {
    if (!widget.enabled || widget.projectId == null) return;

    final res = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => SelectProjectProductDialog(
        projectId: widget.projectId!,
        currentTaskId: widget.taskId,
      ),
    );

    if (!mounted || res == null) return;

    final productId = (res['productId'] ?? '').toString();
    final packageId = (res['packageId'] ?? '').toString();

    if (productId.isEmpty) return;

    // Add to linked products
    final newProduct = {
      'productId': productId,
      'packageId': packageId.isEmpty ? null : packageId,
      'label': res['label'] ?? '',
      'packageName': res['packageName'] ?? '',
      'comment': res['comment'] ?? '',
      'thumbUrl': res['thumbUrl'] ?? '',
    };

    setState(() {
      _linkedProducts = [..._linkedProducts, newProduct];
    });

    // Notify parent
    widget.onLinkedProductsChanged(_linkedProducts);
  }

  void _removeProduct(int index) {
    if (!widget.enabled) return;

    setState(() {
      _linkedProducts = List.from(_linkedProducts)..removeAt(index);
    });

    // Notify parent
    widget.onLinkedProductsChanged(_linkedProducts);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and add button
        Row(
          children: [
            Text('Produtos', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            if (widget.enabled && widget.projectId != null)
              TextButton.icon(
                onPressed: _selectProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Loading indicator
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),

        // Linked products list
        if (!_loading && _linkedProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Nenhum produto vinculado',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        // Product cards
        if (!_loading && _linkedProducts.isNotEmpty)
          ...List.generate(_linkedProducts.length, (index) {
            final product = _linkedProducts[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < _linkedProducts.length - 1 ? 8 : 0),
              child: LinkedPreviewCard(
                label: (product['label'] ?? '') as String,
                packageName: (product['packageName'] ?? '') as String,
                comment: (product['comment'] ?? '') as String,
                thumbUrl: (product['thumbUrl'] ?? '') as String,
                onClear: widget.enabled ? () => _removeProduct(index) : null,
              ),
            );
          }),
      ],
    );
  }
}

