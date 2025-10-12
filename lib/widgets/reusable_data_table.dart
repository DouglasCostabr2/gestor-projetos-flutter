import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';

/// Widget reutilizável de DataTable com checkboxes, ações e ordenação
///
/// Exemplo de uso:
/// ```dart
/// ReusableDataTable<Map<String, dynamic>>(
///   items: _companies,
///   selectedIds: _selected,
///   onSelectionChanged: (ids) => setState(() => _selected = ids),
///   columns: [
///     DataTableColumn(label: 'Nome', flex: 2, sortable: true),
///     DataTableColumn(label: 'Email', flex: 2, sortable: true),
///     DataTableColumn(label: 'Telefone', flex: 1),
///   ],
///   cellBuilders: [
///     (item) => Text(item['name'] ?? ''),
///     (item) => Text(item['email'] ?? '-'),
///     (item) => Text(item['phone'] ?? '-'),
///   ],
///   sortComparators: [
///     (a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()),
///     (a, b) => (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()),
///     null, // Coluna não ordenável
///   ],
///   getId: (item) => item['id'] as String,
///   onRowTap: (item) => Navigator.push(...),
///   actions: [
///     DataTableAction(
///       icon: Icons.edit,
///       tooltip: 'Editar',
///       onPressed: (item) => _edit(item),
///     ),
///     DataTableAction(
///       icon: Icons.delete,
///       tooltip: 'Excluir',
///       onPressed: (item) => _delete(item),
///       showWhen: (item) => canDelete,
///     ),
///   ],
/// )
/// ```
class ReusableDataTable<T> extends StatefulWidget {
  /// Lista de itens a serem exibidos
  final List<T> items;

  /// IDs dos itens selecionados
  final Set<String> selectedIds;

  /// Callback quando a seleção muda
  final ValueChanged<Set<String>>? onSelectionChanged;

  /// Definição das colunas
  final List<DataTableColumn> columns;

  /// Builders para as células de cada coluna
  final List<Widget Function(T item)> cellBuilders;

  /// Comparadores para ordenação (um para cada coluna, null se não ordenável)
  final List<int Function(T a, T b)?>? sortComparators;

  /// Callback quando uma coluna é clicada para ordenação
  /// Se fornecido, a ordenação será controlada externamente
  /// Parâmetros: (columnIndex, ascending)
  final void Function(int columnIndex, bool ascending)? onSort;

  /// Índice da coluna atualmente ordenada (para controle externo)
  final int? externalSortColumnIndex;

  /// Direção da ordenação atual (para controle externo)
  final bool? externalSortAscending;

  /// Função para obter o ID de um item
  final String Function(T item) getId;

  /// Callback quando uma linha é clicada
  final void Function(T item)? onRowTap;

  /// Ações disponíveis para cada linha
  final List<DataTableAction<T>>? actions;

  /// Se deve mostrar a coluna de checkboxes
  final bool showCheckboxes;

  const ReusableDataTable({
    super.key,
    required this.items,
    required this.selectedIds,
    this.onSelectionChanged,
    required this.columns,
    required this.cellBuilders,
    this.sortComparators,
    this.onSort,
    this.externalSortColumnIndex,
    this.externalSortAscending,
    required this.getId,
    this.onRowTap,
    this.actions,
    this.showCheckboxes = true,
  }) : assert(columns.length == cellBuilders.length, 'Número de colunas deve ser igual ao número de cellBuilders'),
       assert(sortComparators == null || columns.length == sortComparators.length, 'Número de colunas deve ser igual ao número de sortComparators'),
       assert(onSort == null || (externalSortColumnIndex != null && externalSortAscending != null), 'Se onSort for fornecido, externalSortColumnIndex e externalSortAscending também devem ser fornecidos');

  @override
  State<ReusableDataTable<T>> createState() => _ReusableDataTableState<T>();
}

class _ReusableDataTableState<T> extends State<ReusableDataTable<T>> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late List<T> _sortedItems;

  @override
  void initState() {
    super.initState();
    _sortedItems = List.from(widget.items);

    // Aplicar ordenação inicial automaticamente pela primeira coluna ordenável
    // APENAS se não houver controle externo de ordenação
    if (widget.onSort == null && widget.sortComparators != null) {
      for (int i = 0; i < widget.sortComparators!.length; i++) {
        if (widget.sortComparators![i] != null) {
          _sortColumnIndex = i;
          _sortAscending = true; // Sempre crescente por padrão
          _sortItems(i);
          break; // Para após encontrar a primeira coluna ordenável
        }
      }
    }
  }

  @override
  void didUpdateWidget(ReusableDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _sortedItems = List.from(widget.items);
      if (_sortColumnIndex != null) {
        _sortItems(_sortColumnIndex!);
      }
    }
  }

  void _sortItems(int columnIndex) {
    if (widget.sortComparators == null) return;
    final comparator = widget.sortComparators![columnIndex];
    if (comparator == null) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortedItems.sort((a, b) {
        final result = comparator(a, b);
        // Invertido: ascending=true → crescente (result), ascending=false → decrescente (-result)
        return _sortAscending ? result : -result;
      });
    });
  }

  void _onSortColumn(int columnIndex) {
    // Se há controle externo de ordenação, delegar para o callback
    if (widget.onSort != null) {
      final isCurrentColumn = (widget.externalSortColumnIndex == columnIndex);
      final newAscending = isCurrentColumn ? !(widget.externalSortAscending ?? true) : true;
      widget.onSort!(columnIndex, newAscending);
      return;
    }

    // Ordenação interna
    if (_sortColumnIndex == columnIndex) {
      setState(() {
        _sortAscending = !_sortAscending;
        _sortedItems = _sortedItems.reversed.toList();
      });
    } else {
      _sortItems(columnIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Calcular número de colunas e larguras
    final Map<int, TableColumnWidth> columnWidths = {};
    int currentIndex = 0;

    // Coluna de checkbox com largura fixa de 60px
    if (widget.showCheckboxes) {
      columnWidths[currentIndex] = const FixedColumnWidth(60);
      currentIndex++;
    }

    // Colunas de dados com largura flexível ou fixa
    for (int i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i];
      if (column.fixedWidth != null) {
        columnWidths[currentIndex] = FixedColumnWidth(column.fixedWidth!);
      } else if (column.flex != null) {
        columnWidths[currentIndex] = FlexColumnWidth(column.flex!.toDouble());
      } else {
        columnWidths[currentIndex] = const FlexColumnWidth();
      }
      currentIndex++;
    }

    // Coluna de ações com largura fixa
    if (widget.actions != null && widget.actions!.isNotEmpty) {
      final maxActions = widget.actions!.length;
      columnWidths[currentIndex] = FixedColumnWidth(maxActions * 48.0 + 16);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Table(
                columnWidths: columnWidths,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      if (widget.showCheckboxes)
                        TableCell(
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            child: GenericCheckbox(
                              value: widget.selectedIds.isEmpty
                                  ? false
                                  : (widget.selectedIds.length == _sortedItems.length ? true : null),
                              onChanged: widget.onSelectionChanged == null ? null : (v) {
                                if (v == true) {
                                  widget.onSelectionChanged!(_sortedItems.map(widget.getId).toSet());
                                } else {
                                  widget.onSelectionChanged!({});
                                }
                              },
                              tristate: true,
                            ),
                          ),
                        ),
                      ...List.generate(widget.columns.length, (index) {
                        final col = widget.columns[index];
                        final isSortable = widget.sortComparators != null && widget.sortComparators![index] != null;

                        // Usar valores externos se disponíveis, senão usar valores internos
                        final sortColumnIndex = widget.onSort != null ? widget.externalSortColumnIndex : _sortColumnIndex;
                        final sortAscending = widget.onSort != null ? (widget.externalSortAscending ?? true) : _sortAscending;
                        final isSorted = sortColumnIndex == index;

                        return TableCell(
                          child: InkWell(
                            onTap: isSortable ? () => _onSortColumn(index) : null,
                            child: Container(
                              height: 56,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      col.label,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isSortable)
                                    Icon(
                                      isSorted
                                          ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                                          : Icons.unfold_more,
                                      size: 16,
                                      color: isSorted ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (widget.actions != null && widget.actions!.isNotEmpty)
                        TableCell(
                          child: Container(
                            height: 56,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ações',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Data Rows
                  ..._sortedItems.map((item) {
                    final id = widget.getId(item);
                    final isSelected = widget.selectedIds.contains(id);

                    return TableRow(
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                      ),
                      children: [
                        if (widget.showCheckboxes)
                          TableCell(
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              child: GenericCheckbox(
                                value: isSelected,
                                onChanged: widget.onSelectionChanged == null ? null : (v) {
                                  final newSelection = Set<String>.from(widget.selectedIds);
                                  if (v == true) {
                                    newSelection.add(id);
                                  } else {
                                    newSelection.remove(id);
                                  }
                                  widget.onSelectionChanged!(newSelection);
                                },
                              ),
                            ),
                          ),
                        ...List.generate(
                          widget.cellBuilders.length,
                          (index) => TableCell(
                            child: InkWell(
                              onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(item),
                              child: Container(
                                height: 52,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: widget.cellBuilders[index](item),
                              ),
                            ),
                          ),
                        ),
                        if (widget.actions != null && widget.actions!.isNotEmpty)
                          TableCell(
                            child: Container(
                              height: 52,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: PopupMenuButton<DataTableAction<T>>(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'Ações',
                                itemBuilder: (context) {
                                  final visibleActions = widget.actions!
                                      .where((action) => action.showWhen?.call(item) ?? true)
                                      .toList();

                                  return visibleActions.map((action) {
                                    return PopupMenuItem<DataTableAction<T>>(
                                      value: action,
                                      child: Row(
                                        children: [
                                          Icon(action.icon, size: 20),
                                          const SizedBox(width: 12),
                                          Text(action.label),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                                onSelected: (action) => action.onPressed(item),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Definição de uma coluna do DataTable
class DataTableColumn {
  final String label;
  final int? flex;
  final double? fixedWidth;
  final bool sortable;

  const DataTableColumn({
    required this.label,
    this.flex,
    this.fixedWidth,
    this.sortable = false,
  }) : assert(
    flex == null || fixedWidth == null,
    'Não é possível definir flex e fixedWidth ao mesmo tempo',
  );
}

/// Definição de uma ação do DataTable
class DataTableAction<T> {
  final IconData icon;
  final String label;
  final void Function(T item) onPressed;
  final bool Function(T item)? showWhen;

  const DataTableAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.showWhen,
  });
}

