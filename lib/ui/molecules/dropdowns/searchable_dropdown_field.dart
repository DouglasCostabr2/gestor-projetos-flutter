import 'package:flutter/material.dart';

/// Modelo para item de dropdown pesquisável
class SearchableDropdownItem<T> {
  final T value;
  final String label;
  final String? searchableText; // Texto adicional para busca (opcional)

  const SearchableDropdownItem({
    required this.value,
    required this.label,
    this.searchableText,
  });
}

/// Widget genérico para dropdown com busca (Material 3 DropdownMenu)
///
/// Características:
/// - Type-safe com generics
/// - Busca e filtro integrados
/// - Largura responsiva automática
/// - Suporta loading state
/// - Controller opcional (gerenciado internamente se não fornecido)
///
/// Exemplo de uso básico:
/// ```dart
/// SearchableDropdownField<String>(
///   value: _selectedCategory,
///   items: categories.map((cat) => SearchableDropdownItem(
///     value: cat['id'],
///     label: cat['name'],
///   )).toList(),
///   onChanged: (value) => setState(() => _selectedCategory = value),
///   labelText: 'Categoria',
///   hintText: 'Digite para buscar...',
/// )
/// ```
///
/// Exemplo com loading:
/// ```dart
/// SearchableDropdownField<String>(
///   value: _selectedCity,
///   items: _cities.map((city) => SearchableDropdownItem(
///     value: city['id'],
///     label: city['name'],
///   )).toList(),
///   onChanged: (value) => setState(() => _selectedCity = value),
///   labelText: 'Cidade',
///   isLoading: _loadingCities,
///   enabled: !_loadingCities && _selectedState != null,
/// )
/// ```
///
/// Exemplo com texto de busca customizado:
/// ```dart
/// SearchableDropdownField<String>(
///   value: _selectedUser,
///   items: users.map((user) => SearchableDropdownItem(
///     value: user['id'],
///     label: user['name'],
///     searchableText: '${user['name']} ${user['email']}', // Busca por nome ou email
///   )).toList(),
///   onChanged: (value) => setState(() => _selectedUser = value),
/// )
/// ```
class SearchableDropdownField<T> extends StatefulWidget {
  /// Valor atual selecionado
  final T? value;

  /// Lista de itens do dropdown
  final List<SearchableDropdownItem<T>> items;

  /// Callback quando o valor muda
  final ValueChanged<T?>? onChanged;

  /// Texto do label
  final String? labelText;

  /// Texto de hint
  final String? hintText;

  /// Se está carregando dados
  final bool isLoading;

  /// Se o campo está habilitado
  final bool enabled;

  /// Largura customizada (null = responsiva automática)
  final double? width;

  /// Controller customizado (opcional, será criado internamente se não fornecido)
  final TextEditingController? controller;

  /// Se deve habilitar filtro
  final bool enableFilter;

  /// Se deve habilitar busca
  final bool enableSearch;

  /// Se deve focar ao tocar
  final bool requestFocusOnTap;

  const SearchableDropdownField({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.controller,
    this.enableFilter = true,
    this.enableSearch = true,
    this.requestFocusOnTap = true,
  });

  @override
  State<SearchableDropdownField<T>> createState() => _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T> extends State<SearchableDropdownField<T>> {
  late TextEditingController _controller;
  bool _controllerCreatedInternally = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _controllerCreatedInternally = true;
    }
  }

  @override
  void dispose() {
    if (_controllerCreatedInternally) {
      _controller.dispose();
    }
    super.dispose();
  }

  String _getHintText() {
    if (widget.isLoading) {
      return 'Carregando...';
    }
    if (!widget.enabled) {
      return 'Desabilitado';
    }
    return widget.hintText ?? 'Digite para buscar...';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = widget.width ?? constraints.maxWidth;

        return DropdownMenu<T>(
          controller: _controller,
          initialSelection: widget.value,
          label: widget.labelText != null ? Text(widget.labelText!) : null,
          hintText: _getHintText(),
          enableFilter: widget.enableFilter,
          enableSearch: widget.enableSearch,
          requestFocusOnTap: widget.requestFocusOnTap,
          enabled: widget.enabled && !widget.isLoading,
          width: effectiveWidth,
          dropdownMenuEntries: widget.items.map((item) {
            return DropdownMenuEntry<T>(
              value: item.value,
              label: item.label,
            );
          }).toList(),
          onSelected: widget.enabled && !widget.isLoading ? widget.onChanged : null,
        );
      },
    );
  }
}

