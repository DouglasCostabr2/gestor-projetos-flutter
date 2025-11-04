import 'package:flutter/material.dart';

/// Modelo para item de multi-select dropdown
class MultiSelectDropdownItem<T> {
  final T value;
  final String label;
  final Widget? leadingIcon;

  const MultiSelectDropdownItem({
    required this.value,
    required this.label,
    this.leadingIcon,
  });
}

/// Widget genérico para multi-select dropdown (Material 3)
///
/// Características:
/// - Type-safe com generics
/// - Seleção múltipla com chips
/// - Design Material 3
/// - Suporta ícones leading
/// - Largura responsiva
///
/// Exemplo de uso:
/// ```dart
/// MultiSelectDropdownField<String>(
///   selectedValues: _selectedUsers,
///   items: [
///     MultiSelectDropdownItem(value: 'user1', label: 'João Silva'),
///     MultiSelectDropdownItem(value: 'user2', label: 'Maria Santos'),
///   ],
///   onChanged: (values) => setState(() => _selectedUsers = values),
///   labelText: 'Responsáveis',
/// )
/// ```
class MultiSelectDropdownField<T> extends StatefulWidget {
  /// Valores atualmente selecionados
  final List<T> selectedValues;

  /// Lista de itens disponíveis
  final List<MultiSelectDropdownItem<T>> items;

  /// Callback quando os valores mudam
  final ValueChanged<List<T>>? onChanged;

  /// Texto do label
  final String? labelText;

  /// Texto de hint quando nada está selecionado
  final String? hintText;

  /// Se o campo está habilitado
  final bool enabled;

  /// Largura do dropdown (null = responsiva automática)
  final double? width;

  /// Se deve focar no campo de busca ao abrir o menu
  final bool requestSearchFocusOnOpen;

  const MultiSelectDropdownField({
    super.key,
    required this.selectedValues,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.width,
    this.requestSearchFocusOnOpen = false,
  });

  @override
  State<MultiSelectDropdownField<T>> createState() => _MultiSelectDropdownFieldState<T>();
}

class _MultiSelectDropdownFieldState<T> extends State<MultiSelectDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _closeDropdown();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }


  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    if (widget.requestSearchFocusOnOpen) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _searchFocusNode.requestFocus();
      });
    }


  }

  void _closeDropdown() {
    _overlayEntry?.remove();

    _overlayEntry = null;
    _searchController.clear();
    _searchQuery = '';
    setState(() => _isOpen = false);
  }

  void _toggleItem(T value) {
    if (!widget.enabled) return;

    final newValues = List<T>.from(widget.selectedValues);
    if (newValues.contains(value)) {
      newValues.remove(value);
    } else {
      newValues.add(value);
    }
    widget.onChanged?.call(newValues);
  }

  void _removeChip(T value) {
    if (!widget.enabled) return;

    final newValues = List<T>.from(widget.selectedValues);
    newValues.remove(value);
    widget.onChanged?.call(newValues);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _closeDropdown,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 350),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo de busca
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) {
                              setState(() => _searchQuery = value.toLowerCase());
                              _overlayEntry?.markNeedsBuild();
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: (Theme.of(context).inputDecorationTheme.enabledBorder as OutlineInputBorder?)?.copyWith(
                                    borderRadius: BorderRadius.circular(8),
                                  ) ??
                                  OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                  ),
                              enabledBorder: (Theme.of(context).inputDecorationTheme.enabledBorder as OutlineInputBorder?)?.copyWith(
                                    borderRadius: BorderRadius.circular(8),
                                  ) ??
                                  OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                  ),
                              focusedBorder: (Theme.of(context).inputDecorationTheme.focusedBorder as OutlineInputBorder?)?.copyWith(
                                    borderRadius: BorderRadius.circular(8),
                                  ) ??
                                  OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline, width: 2),
                                  ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),

                        // Divider
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        ),

                        // Lista de itens
                        Flexible(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            children: _getFilteredItems().map((item) {
                              final isSelected = widget.selectedValues.contains(item.value);
                              return InkWell(
                                onTap: () => _toggleItem(item.value),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      if (item.leadingIcon != null) ...[
                                        item.leadingIcon!,
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MultiSelectDropdownItem<T>> _getFilteredItems() {
    if (_searchQuery.isEmpty) {
      return widget.items;
    }
    return widget.items.where((item) {
      return item.label.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  String _getDisplayText() {
    if (widget.selectedValues.isEmpty) {
      return widget.hintText ?? 'Selecione...';
    }

    final selectedLabels = widget.selectedValues
        .map((value) => widget.items.firstWhere((item) => item.value == value).label)
        .toList();

    if (selectedLabels.length == 1) {
      return selectedLabels.first;
    }

    return '${selectedLabels.length} selecionados';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(width: widget.width, child: CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.enabled ? _toggleDropdown : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.labelText,
            enabled: widget.enabled,
            suffixIcon: Icon(_isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
            enabledBorder: (theme.inputDecorationTheme.enabledBorder as OutlineInputBorder?)?.copyWith(
                  borderRadius: BorderRadius.circular(12),
                ) ??
                OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
            focusedBorder: (theme.inputDecorationTheme.focusedBorder as OutlineInputBorder?)?.copyWith(
                  borderRadius: BorderRadius.circular(12),
                ) ??
                OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline, width: 2),
                ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isFocused: _isOpen,
          child: widget.selectedValues.isEmpty
              ? Text(
                  _getDisplayText(),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.selectedValues.map((value) {
                    final item = widget.items.firstWhere((item) => item.value == value);
                    return Chip(
                      key: ValueKey('chip_$value'),
                      avatar: item.leadingIcon,
                      label: Text(item.label),
                      onDeleted: widget.enabled ? () => _removeChip(value) : null,
                      deleteIcon: const Icon(Icons.close, size: 18),
                      deleteButtonTooltipMessage: '', // Desabilita tooltip
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
        ),
      ),
    ));
  }
}

