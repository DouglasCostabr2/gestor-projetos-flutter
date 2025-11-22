import 'package:flutter/material.dart';
import '../../atoms/buttons/buttons.dart';

/// Widget reutilizável para barra de busca e filtros em tabelas
///
/// Exemplo de uso:
/// ```dart
/// TableSearchFilterBar(
///   searchHint: 'Buscar cliente',
///   onSearchChanged: (value) => setState(() => _searchQuery = value),
///   filterType: _filterType,
///   filterTypeLabel: 'Tipo de filtro',
///   filterTypeOptions: const [
///     FilterOption(value: 'none', label: 'Nenhum'),
///     FilterOption(value: 'country', label: 'País'),
///     FilterOption(value: 'state', label: 'Estado'),
///   ],
///   onFilterTypeChanged: (value) {
///     setState(() {
///       _filterType = value;
///       _filterValue = null;
///     });
///   },
///   filterValue: _filterValue,
///   filterValueLabel: _getFilterLabel(),
///   filterValueOptions: _getFilterOptions(),
///   onFilterValueChanged: (value) {
///     setState(() => _filterValue = value);
///     _applyFilters();
///   },
/// )
/// ```
class TableSearchFilterBar extends StatefulWidget {
  /// Hint do campo de busca
  final String searchHint;
  
  /// Callback quando o texto de busca muda
  final ValueChanged<String> onSearchChanged;
  
  /// Valor atual do tipo de filtro
  final String? filterType;
  
  /// Label do dropdown de tipo de filtro
  final String filterTypeLabel;
  
  /// Opções do dropdown de tipo de filtro
  final List<FilterOption> filterTypeOptions;
  
  /// Callback quando o tipo de filtro muda
  final ValueChanged<String?>? onFilterTypeChanged;
  
  /// Valor atual do filtro
  final String? filterValue;
  
  /// Label do dropdown de valor do filtro
  final String? filterValueLabel;
  
  /// Opções do dropdown de valor do filtro
  final List<String>? filterValueOptions;

  /// Callback quando o valor do filtro muda
  final ValueChanged<String?>? onFilterValueChanged;

  /// Função para customizar o label de cada valor do filtro
  /// Se não fornecida, usa o próprio valor como label
  final String Function(String)? filterValueLabelBuilder;

  /// Se deve mostrar os filtros (padrão: true)
  final bool showFilters;

  /// Botão de ação (ex: Adicionar)
  final Widget? actionButton;

  /// Número de itens selecionados
  final int selectedCount;

  /// Ações em lote (aparecem quando há itens selecionados)
  final List<BulkAction>? bulkActions;

  const TableSearchFilterBar({
    super.key,
    required this.searchHint,
    required this.onSearchChanged,
    this.filterType,
    this.filterTypeLabel = 'Tipo de filtro',
    this.filterTypeOptions = const [],
    this.onFilterTypeChanged,
    this.filterValue,
    this.filterValueLabel,
    this.filterValueOptions,
    this.onFilterValueChanged,
    this.filterValueLabelBuilder,
    this.showFilters = true,
    this.actionButton,
    this.selectedCount = 0,
    this.bulkActions,
  });

  @override
  State<TableSearchFilterBar> createState() => _TableSearchFilterBarState();
}

class _TableSearchFilterBarState extends State<TableSearchFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Listener para atualizar o botão "X" quando o texto mudar
    _searchController.addListener(() {
      setState(() {}); // Atualiza para mostrar/esconder o botão "X"
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBulkActions = widget.selectedCount > 0 && widget.bulkActions != null && widget.bulkActions!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Mostrar ações em lote se houver itens selecionados
          if (hasBulkActions) ...[
            OutlineButton(
              onPressed: widget.bulkActions!.first.onPressed,
              label: '${widget.selectedCount} selecionado${widget.selectedCount > 1 ? 's' : ''}',
              icon: widget.bulkActions!.first.icon,
            ),
            const Spacer(),
          ] else ...[
            // Campo de busca (largura fixa máxima de 300px)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearchChanged('');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),

            if (widget.showFilters && widget.filterTypeOptions.isNotEmpty) ...[
              const SizedBox(width: 16),

              // Tipo de filtro
              SizedBox(
                width: 180,
                child: DropdownMenu<String>(
                  initialSelection: widget.filterType,
                  label: Text(widget.filterTypeLabel),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: widget.filterTypeOptions.map((option) {
                    return DropdownMenuEntry(
                      value: option.value,
                      label: option.label,
                    );
                  }).toList(),
                  onSelected: widget.onFilterTypeChanged,
                ),
              ),

              // Valor do filtro (só mostra se não for "none")
              if (widget.filterType != null && widget.filterType != 'none' && widget.filterValueOptions != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownMenu<String>(
                    key: ValueKey(widget.filterType), // Força reconstrução ao mudar tipo
                    initialSelection: widget.filterValue,
                    label: Text(widget.filterValueLabel ?? 'Filtrar'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: [
                      const DropdownMenuEntry(value: '', label: 'Todos'),
                      ...widget.filterValueOptions!.map((option) {
                        final label = widget.filterValueLabelBuilder != null
                            ? widget.filterValueLabelBuilder!(option)
                            : option;
                        return DropdownMenuEntry(value: option, label: label);
                      }),
                    ],
                    onSelected: widget.onFilterValueChanged,
                  ),
                ),
              ],
            ],

            // Botão de ação (sempre à direita)
            if (widget.actionButton != null) ...[
              const Spacer(),
              const SizedBox(width: 16),
              widget.actionButton!,
            ],
          ],
        ],
      ),
    );
  }
}

/// Opção de filtro
class FilterOption {
  final String value;
  final String label;

  const FilterOption({
    required this.value,
    required this.label,
  });
}

/// Ação em lote
class BulkAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const BulkAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
}

