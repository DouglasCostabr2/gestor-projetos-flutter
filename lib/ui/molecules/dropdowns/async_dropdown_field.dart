import 'package:flutter/material.dart';
import 'searchable_dropdown_field.dart';

/// Widget genérico para dropdown que carrega dados assincronamente
///
/// Características:
/// - Type-safe com generics
/// - Carregamento assíncrono com loading state
/// - Tratamento de erros com botão retry
/// - Recarregamento automático quando dependências mudam
/// - Design Material 3 (DropdownMenu)
///
/// Exemplo de uso básico:
/// ```dart
/// AsyncDropdownField<String>(
///   value: _clientId,
///   loadItems: () async {
///     final response = await supabase.from('clients').select();
///     return response.map((item) => SearchableDropdownItem(
///       value: item['id'] as String,
///       label: item['name'] as String,
///     )).toList();
///   },
///   onChanged: (value) => setState(() => _clientId = value),
///   labelText: 'Cliente',
/// )
/// ```
///
/// Exemplo com dependências (recarrega quando _clientId muda):
/// ```dart
/// AsyncDropdownField<String>(
///   value: _companyId,
///   loadItems: () async {
///     if (_clientId == null) return [];
///     final response = await supabase
///       .from('companies')
///       .select()
///       .eq('client_id', _clientId!);
///     return response.map((item) => SearchableDropdownItem(
///       value: item['id'] as String,
///       label: item['name'] as String,
///     )).toList();
///   },
///   onChanged: (value) => setState(() => _companyId = value),
///   labelText: 'Empresa',
///   dependencies: [_clientId], // Recarrega quando _clientId muda
///   enabled: _clientId != null,
/// )
/// ```
class AsyncDropdownField<T> extends StatefulWidget {
  /// Valor atual selecionado
  final T? value;

  /// Função que carrega os itens assincronamente
  final Future<List<SearchableDropdownItem<T>>> Function() loadItems;

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

  /// Lista de dependências - quando qualquer uma mudar, recarrega os itens
  final List<Object?>? dependencies;

  /// Mensagem quando não há itens
  final String? emptyMessage;

  /// Mensagem de erro customizada
  final String? errorMessage;

  const AsyncDropdownField({
    super.key,
    this.value,
    required this.loadItems,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.width,
    this.dependencies,
    this.emptyMessage,
    this.errorMessage,
  });

  @override
  State<AsyncDropdownField<T>> createState() => _AsyncDropdownFieldState<T>();
}

class _AsyncDropdownFieldState<T> extends State<AsyncDropdownField<T>> {
  bool _isLoading = true;
  bool _hasError = false;
  List<SearchableDropdownItem<T>> _items = [];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(AsyncDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Recarrega se as dependências mudaram
    if (widget.dependencies != null && oldWidget.dependencies != null) {
      bool dependenciesChanged = false;
      for (int i = 0; i < widget.dependencies!.length; i++) {
        if (i >= oldWidget.dependencies!.length || 
            widget.dependencies![i] != oldWidget.dependencies![i]) {
          dependenciesChanged = true;
          break;
        }
      }
      if (dependenciesChanged) {
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorText = null;
    });

    try {
      final items = await widget.loadItems();
      if (!mounted) return;
      
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorText = widget.errorMessage ?? 'Erro ao carregar dados';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return SearchableDropdownField<T>(
        value: null,
        items: const [],
        enabled: false,
        labelText: widget.labelText,
        hintText: 'Carregando...',
        isLoading: true,
        width: widget.width,
      );
    }

    // Error state
    if (_hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SearchableDropdownField<T>(
            value: null,
            items: const [],
            enabled: false,
            labelText: widget.labelText,
            width: widget.width,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _errorText ?? 'Erro ao carregar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar novamente'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Empty state
    if (_items.isEmpty) {
      return SearchableDropdownField<T>(
        value: null,
        items: const [],
        enabled: false,
        labelText: widget.labelText,
        hintText: widget.emptyMessage ?? 'Nenhum item disponível',
        width: widget.width,
      );
    }

    // Normal state
    return SearchableDropdownField<T>(
      value: widget.value,
      items: _items,
      onChanged: widget.onChanged,
      labelText: widget.labelText,
      hintText: widget.hintText,
      enabled: widget.enabled,
      width: widget.width,
    );
  }
}

