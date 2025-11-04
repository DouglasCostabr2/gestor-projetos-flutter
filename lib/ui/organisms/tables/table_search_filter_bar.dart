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
class TableSearchFilterBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasBulkActions = selectedCount > 0 && bulkActions != null && bulkActions!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Mostrar ações em lote se houver itens selecionados
          if (hasBulkActions) ...[
            OutlineButton(
              onPressed: bulkActions!.first.onPressed,
              label: '$selectedCount selecionado${selectedCount > 1 ? 's' : ''}',
              icon: bulkActions!.first.icon,
            ),
            const Spacer(),
          ] else ...[
            // Campo de busca (largura fixa máxima de 300px)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: onSearchChanged,
              ),
            ),

            if (showFilters && filterTypeOptions.isNotEmpty) ...[
              const SizedBox(width: 16),

              // Tipo de filtro
              SizedBox(
                width: 180,
                child: DropdownMenu<String>(
                  initialSelection: filterType,
                  label: Text(filterTypeLabel),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: filterTypeOptions.map((option) {
                    return DropdownMenuEntry(
                      value: option.value,
                      label: option.label,
                    );
                  }).toList(),
                  onSelected: onFilterTypeChanged,
                ),
              ),

              // Valor do filtro (só mostra se não for "none")
              if (filterType != null && filterType != 'none' && filterValueOptions != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownMenu<String>(
                    key: ValueKey(filterType), // Força reconstrução ao mudar tipo
                    initialSelection: filterValue,
                    label: Text(filterValueLabel ?? 'Filtrar'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: [
                      const DropdownMenuEntry(value: '', label: 'Todos'),
                      ...filterValueOptions!.map((option) {
                        final label = filterValueLabelBuilder != null
                            ? filterValueLabelBuilder!(option)
                            : option;
                        return DropdownMenuEntry(value: option, label: label);
                      }),
                    ],
                    onSelected: onFilterValueChanged,
                  ),
                ),
              ],
            ],

            // Botão de ação (sempre à direita)
            if (actionButton != null)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 16),
                    actionButton!,
                  ],
                ),
              )
            else
              const Spacer(),
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

