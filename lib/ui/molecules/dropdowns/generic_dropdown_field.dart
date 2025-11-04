import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Modelo para item de dropdown genérico
class DropdownItem<T> {
  final T value;
  final String label;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const DropdownItem({
    required this.value,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
  });
}

/// Widget genérico para dropdown simples com lista estática (Material 3 DropdownMenu)
///
/// Características:
/// - Type-safe com generics
/// - Design Material 3 (igual ao TableSearchFilterBar)
/// - Suporta valores nullable
/// - Callback para mudanças
/// - Suporta ícones leading/trailing
/// - Largura responsiva ou fixa
///
/// Exemplo de uso:
/// ```dart
/// GenericDropdownField<String>(
///   value: _selectedValue,
///   items: [
///     DropdownItem(value: 'opt1', label: 'Opção 1'),
///     DropdownItem(value: 'opt2', label: 'Opção 2'),
///   ],
///   onChanged: (value) => setState(() => _selectedValue = value),
///   labelText: 'Selecione uma opção',
///   enabled: !_saving,
/// )
/// ```
///
/// Exemplo com valores nullable:
/// ```dart
/// GenericDropdownField<String?>(
///   value: _selectedValue,
///   items: [
///     DropdownItem(value: null, label: 'Nenhum'),
///     DropdownItem(value: 'opt1', label: 'Opção 1'),
///   ],
///   onChanged: (value) => setState(() => _selectedValue = value),
///   labelText: 'Opcional',
/// )
/// ```
///
/// Exemplo com ícones:
/// ```dart
/// GenericDropdownField<String>(
///   value: _status,
///   items: [
///     DropdownItem(value: 'active', label: 'Ativo', leadingIcon: Icon(Icons.check_circle)),
///     DropdownItem(value: 'inactive', label: 'Inativo', leadingIcon: Icon(Icons.cancel)),
///   ],
///   onChanged: (value) => setState(() => _status = value),
/// )
/// ```
class GenericDropdownField<T> extends StatefulWidget {
  /// Valor atual selecionado
  final T? value;

  /// Lista de itens do dropdown
  final List<DropdownItem<T>> items;

  /// Callback quando o valor muda
  final ValueChanged<T?>? onChanged;

  /// Texto do label
  final String? labelText;

  /// Texto de hint
  final String? hintText;

  /// Se o campo está habilitado
  final bool enabled;

  /// Largura do dropdown (null = responsiva automática)
  final double? width;

  /// Estilo de texto para o valor selecionado
  final TextStyle? textStyle;

  /// Callback chamado antes de mudar o valor (para validações assíncronas)
  /// Retorna true se pode mudar, false caso contrário
  final Future<bool> Function(T? newValue)? onBeforeChanged;

  /// Mensagem de erro a ser exibida quando onBeforeChanged retorna false
  final String? validationErrorMessage;

  /// Se true, o dropdown abre para cima em vez de para baixo
  final bool openUpwards;

  const GenericDropdownField({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.width,
    this.textStyle,
    this.onBeforeChanged,
    this.validationErrorMessage,
    this.openUpwards = false,
  });

  @override
  State<GenericDropdownField<T>> createState() => _GenericDropdownFieldState<T>();
}

class _GenericDropdownFieldState<T> extends State<GenericDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  T? _currentValue;

  // Filtro por digitação
  String _filterText = '';
  Timer? _filterResetTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(GenericDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  void dispose() {
    // Limpar overlay sem chamar setState (widget está sendo destruído)
    _overlayEntry?.remove();
    _overlayEntry = null;
    _filterResetTimer?.cancel();
    _scrollController.dispose();
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
    if (!mounted) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _filterText = '';
    _filterResetTimer?.cancel();
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _handleKeyPress(String char) {
    if (!_isOpen) return;

    setState(() {
      _filterText += char.toLowerCase();
    });

    // Reset timer
    _filterResetTimer?.cancel();
    _filterResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isOpen) {
        setState(() {
          _filterText = '';
        });
        _rebuildOverlay();
      }
    });

    // Rebuild overlay
    _rebuildOverlay();

    // Scroll para o primeiro item filtrado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _rebuildOverlay() {
    if (!_isOpen || _overlayEntry == null) return;
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _clearFilter() {
    if (_filterText.isEmpty) return;

    setState(() {
      _filterText = '';
    });
    _filterResetTimer?.cancel();

    // Rebuild overlay
    _rebuildOverlay();
  }

  List<DropdownItem<T>> _getFilteredItems() {
    if (_filterText.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      return item.label.toLowerCase().contains(_filterText);
    }).toList();
  }

  Future<void> _handleChange(T? newValue) async {
    _closeDropdown();

    // Se tem validação antes de mudar
    if (widget.onBeforeChanged != null) {
      final messenger = ScaffoldMessenger.of(context);
      final canChange = await widget.onBeforeChanged!(newValue);

      if (!canChange) {
        if (!mounted) return;

        // Mostra mensagem de erro
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.validationErrorMessage ?? 'Não é possível alterar este valor.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // Force rebuild para resetar o dropdown
        if (mounted) {
          setState(() {});
        }
        return;
      }
    }

    // Atualiza o valor
    if (mounted) {
      setState(() {
        _currentValue = newValue;
      });
    }

    widget.onChanged?.call(newValue);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Mesma cor do focusedBorder do tema (25% entre outlineVariant e branco)
    final focusBorderColor = Color.lerp(colorScheme.outlineVariant, Colors.white, 0.25)!;

    // Detectar se deve abrir para cima automaticamente
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - position.dy - size.height;
    final spaceAbove = position.dy;
    const maxDropdownHeight = 300.0;

    // Se não tem espaço suficiente embaixo mas tem em cima, abre para cima
    final shouldOpenUpwards = widget.openUpwards ||
        (spaceBelow < maxDropdownHeight && spaceAbove > spaceBelow);

    // Widget do menu dropdown
    // Se abre para cima: bordas superiores arredondadas, inferiores retas
    // Se abre para baixo: bordas inferiores arredondadas, superiores retas
    final menuWidget = Material(
      elevation: 8,
      borderRadius: shouldOpenUpwards
          ? const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.zero,
              bottomRight: Radius.zero,
            )
          : const BorderRadius.only(
              topLeft: Radius.zero,
              topRight: Radius.zero,
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: maxDropdownHeight),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: shouldOpenUpwards
              ? const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.zero,
                  bottomRight: Radius.zero,
                )
              : const BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.zero,
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
          border: Border.all(
            color: focusBorderColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de filtro
            if (_filterText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtrando: "$_filterText"',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _clearFilter,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            // Lista de itens filtrados (usando builder para performance)
            Flexible(
              child: Builder(
                builder: (context) {
                  final filteredItems = _getFilteredItems();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = _currentValue == item.value;
                      return InkWell(
                        onTap: () => _handleChange(item.value),
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
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return OverlayEntry(
      builder: (context) => KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            // ESC fecha o dropdown
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _closeDropdown();
              return;
            }

            // Backspace limpa o filtro
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_filterText.isNotEmpty) {
                setState(() {
                  _filterText = _filterText.substring(0, _filterText.length - 1);
                });
                _filterResetTimer?.cancel();
                _filterResetTimer = Timer(const Duration(seconds: 2), () {
                  if (mounted && _isOpen) {
                    setState(() {
                      _filterText = '';
                    });
                    _rebuildOverlay();
                  }
                });
                _rebuildOverlay();
              }
              return;
            }

            // Enter seleciona o primeiro item filtrado
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              final filteredItems = _getFilteredItems();
              if (filteredItems.isNotEmpty) {
                _handleChange(filteredItems.first.value);
              }
              return;
            }

            // Captura caracteres alfanuméricos e espaço
            final char = event.character;
            if (char != null && char.length == 1) {
              final isAlphanumeric = RegExp(r'[a-zA-Z0-9\s]').hasMatch(char);
              if (isAlphanumeric) {
                _handleKeyPress(char);
              }
            }
          }
        },
        child: GestureDetector(
          onTap: _closeDropdown,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned(
                width: size.width,
                child: shouldOpenUpwards
                    ? CompositedTransformFollower(
                        link: _layerLink,
                        showWhenUnlinked: false,
                        offset: const Offset(0, 1),
                        followerAnchor: Alignment.bottomLeft,
                        targetAnchor: Alignment.topLeft,
                        child: menuWidget,
                      )
                    : CompositedTransformFollower(
                        link: _layerLink,
                        showWhenUnlinked: false,
                        offset: Offset(0, size.height - 1),
                        child: menuWidget,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayText() {
    if (_currentValue == null) {
      return widget.hintText ?? 'Selecione...';
    }

    final selectedItem = widget.items.firstWhere(
      (item) => item.value == _currentValue,
      orElse: () => DropdownItem(value: _currentValue as T, label: widget.hintText ?? 'Selecione...'),
    );

    return selectedItem.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Mesma cor do focusedBorder do tema (25% entre outlineVariant e branco)
    final focusBorderColor = Color.lerp(colorScheme.outlineVariant, Colors.white, 0.25)!;

    // Calcular se deve abrir para cima (para definir bordas corretas)
    bool shouldOpenUpwards = widget.openUpwards;
    if (!shouldOpenUpwards && _isOpen) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final screenHeight = MediaQuery.of(context).size.height;
        final spaceBelow = screenHeight - position.dy - size.height;
        final spaceAbove = position.dy;
        const maxDropdownHeight = 300.0;
        shouldOpenUpwards = spaceBelow < maxDropdownHeight && spaceAbove > spaceBelow;
      }
    }

    // Bordas do input quando aberto: retas na direção do menu
    final openBorderRadius = shouldOpenUpwards
        ? const BorderRadius.only(
            topLeft: Radius.zero,
            topRight: Radius.zero,
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.zero,
            bottomRight: Radius.zero,
          );

    return SizedBox(width: widget.width, child: CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.enabled ? _toggleDropdown : null,
        borderRadius: _isOpen ? openBorderRadius : BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.labelText,
            enabled: widget.enabled,
            suffixIcon: Icon(
              _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: _isOpen ? focusBorderColor : null,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: _isOpen
                ? OutlineInputBorder(
                    borderRadius: openBorderRadius,
                    borderSide: BorderSide(color: focusBorderColor, width: 1),
                  )
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: focusBorderColor, width: 2),
                  ),
            border: _isOpen
                ? OutlineInputBorder(
                    borderRadius: openBorderRadius,
                    borderSide: BorderSide(color: focusBorderColor, width: 1),
                  )
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          isFocused: _isOpen,
          child: Text(
            _getDisplayText(),
            style: _currentValue == null
                ? theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )
                : widget.textStyle ?? theme.textTheme.bodyLarge,
          ),
        ),
      ),
    ));
  }
}

