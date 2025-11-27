import 'package:flutter/material.dart';
import 'package:my_business/ui/atoms/avatars/cached_avatar.dart';
import 'package:my_business/ui/molecules/molecules.dart';
import 'package:my_business/ui/theme/ui_constants.dart';
import 'package:my_business/src/features/tasks/widgets/select_project_product_dialog.dart';

/// Componente para vincular produtos a uma tarefa/subtarefa no estilo do mock
/// - Mostra um painel com borda tracejada para adicionar
/// - Lista os produtos selecionados como cards com thumb, nome e comentário
/// - Usa o SelectProjectProductDialog para escolher um item do catálogo do projeto
class TaskProductLinkSelector extends StatefulWidget {
  final String? projectId;
  final String? currentTaskId;
  final List<Map<String, dynamic>> selectedProducts;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool enabled;
  final String? placeholderText; // ex.: "Vincular produto"

  const TaskProductLinkSelector({
    super.key,
    required this.projectId,
    required this.selectedProducts,
    required this.onChanged,
    this.currentTaskId,
    this.enabled = true,
    this.placeholderText,
  });

  @override
  State<TaskProductLinkSelector> createState() =>
      _TaskProductLinkSelectorState();
}

class _TaskProductLinkSelectorState extends State<TaskProductLinkSelector> {
  bool _isAddHover = false;

  void _openSelector() async {
    if (!widget.enabled) return;
    if (widget.projectId == null || widget.projectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione um projeto antes de vincular produtos.')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => SelectProjectProductDialog(
        projectId: widget.projectId!,
        currentTaskId: widget.currentTaskId,
      ),
    );

    if (!mounted || result == null) return; // Usuário clicou OK sem selecionar

    // Sem vínculo
    if (result['productId'] == null) {
      widget.onChanged(const []);
      return;
    }

    final newItem = {
      'productId': result['productId'],
      'packageId': result['packageId'],
      'position': result['position'],
      'label': result['label'],
      'packageName': result['packageName'],
      'comment': result['comment'],
      'thumbUrl': result['thumbUrl'],
    };

    final key = _keyOf(newItem);
    final exists = widget.selectedProducts.any((p) => _keyOf(p) == key);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto já adicionado.')),
      );
      return;
    }

    final updated = List<Map<String, dynamic>>.from(widget.selectedProducts)
      ..add(newItem);
    widget.onChanged(updated);
  }

  String _keyOf(Map<String, dynamic> p) =>
      '${p['productId']}:${p['packageId'] ?? ''}:${p['position'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Área de adicionar (borda tracejada)
          _DashedActionBox(
            enabled: widget.enabled && widget.projectId != null,
            onTap: _openSelector,
            onHoverChanged: (h) => setState(() => _isAddHover = h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: colorScheme.onSurface
                      .withValues(alpha: _isAddHover ? 0.8 : 0.5),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.placeholderText ?? 'Vincular produto',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface
                        .withValues(alpha: _isAddHover ? 0.8 : 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (widget.selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Lista de selecionados
            ...List<Widget>.generate(widget.selectedProducts.length, (i) {
              final p = widget.selectedProducts[i];
              final isLast = i == widget.selectedProducts.length - 1;
              return _ProductCard(
                label: (p['label'] ?? '-') as String,
                comment: (p['comment'] ?? '') as String,
                packageName: p['packageName'] as String?,
                thumbUrl: p['thumbUrl'] as String?,
                margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                onRemove: widget.enabled
                    ? () {
                        final updated = widget.selectedProducts
                            .where((e) => _keyOf(e) != _keyOf(p))
                            .toList();
                        widget.onChanged(updated);
                      }
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String label;
  final String comment;
  final String? packageName;
  final String? thumbUrl;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onRemove;

  const _ProductCard({
    required this.label,
    required this.comment,
    this.packageName,
    required this.thumbUrl,
    this.onRemove,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(UIConst.radiusSmall),
        border: Border.all(
            color: colorScheme.outlineVariant
                .withValues(alpha: colorScheme.outlineVariant.a * 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Builder(builder: (context) {
            final size = 40.0;
            final url = thumbUrl;
            if (url == null || url.isEmpty) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.inventory_2,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          }),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: textTheme.bodyMedium),
                if (comment.isNotEmpty)
                  Text(comment,
                      style: textTheme.bodySmall?.copyWith(color: Colors.amber))
                else if (packageName != null && packageName!.isNotEmpty)
                  Text(packageName!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remover',
            ),
        ],
      ),
    );
  }
}

class _DashedActionBox extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final ValueChanged<bool>? onHoverChanged;
  const _DashedActionBox({
    required this.child,
    required this.onTap,
    required this.enabled,
    this.onHoverChanged,
  });

  @override
  State<_DashedActionBox> createState() => _DashedActionBoxState();
}

class _DashedActionBoxState extends State<_DashedActionBox> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: _isHover ? 0.8 : 0.5);

    final overlay = _isHover
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;

    final box = DashedContainer(
      color: borderColor,
      strokeWidth: UIConst.dashedStroke,
      dashLength: UIConst.dashLengthDefault,
      dashGap: UIConst.dashGapDefault,
      borderRadius: UIConst.radiusSmall,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        color: overlay,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: widget.child,
      ),
    );

    if (!widget.enabled) return Opacity(opacity: 0.5, child: box);

    return InkWell(
      onHover: (h) {
        setState(() => _isHover = h);
        widget.onHoverChanged?.call(h);
      },
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(UIConst.radiusSmall),
      onTap: widget.onTap,
      child: box,
    );
  }
}
