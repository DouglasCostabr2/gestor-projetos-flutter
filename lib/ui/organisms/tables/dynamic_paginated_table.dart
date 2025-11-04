import 'package:flutter/material.dart';
import 'reusable_data_table.dart';
import '../../atoms/loaders/loaders.dart';
import '../../atoms/buttons/buttons.dart';

// Constantes para cálculo de altura da tabela
const double _kTableHeaderHeight = 56.0;
const double _kTableRowHeight = 48.0;
const double _kPaginationHeight = 80.0;
const double _kSpacingBetweenTableAndPagination = 24.0;
const double _kExtraMargin = 20.0;
const double _kTotalReservedHeight = _kSpacingBetweenTableAndPagination + _kPaginationHeight + _kExtraMargin;
const int _kMinItemsPerPage = 5;

/// Widget genérico para tabelas com paginação dinâmica baseada na altura disponível.
/// 
/// Este componente:
/// - Calcula automaticamente quantos itens cabem na tela baseado na altura disponível
/// - Gerencia a paginação internamente
/// - Exibe controles de paginação com informações de itens exibidos
/// - Integra-se com o ReusableDataTable
/// 
/// Exemplo de uso:
/// ```dart
/// DynamicPaginatedTable<Map<String, dynamic>>(
///   items: _filteredData,
///   columns: [
///     DataTableColumn(label: 'Nome', sortable: true),
///     DataTableColumn(label: 'Email', sortable: true),
///   ],
///   cellBuilders: [
///     (item) => Text(item['name'] ?? ''),
///     (item) => Text(item['email'] ?? ''),
///   ],
///   getId: (item) => item['id'] as String,
///   itemLabel: 'projeto(s)', // ou 'cliente(s)', 'tarefa(s)', etc.
/// )
/// ```
class DynamicPaginatedTable<T> extends StatefulWidget {
  /// Lista completa de itens a serem exibidos
  final List<T> items;

  /// Colunas da tabela
  final List<DataTableColumn> columns;

  /// Construtores de células para cada coluna
  final List<Widget Function(T)> cellBuilders;

  /// Função para obter o ID único de cada item
  final String Function(T) getId;

  /// Label para o tipo de item (ex: 'projeto(s)', 'cliente(s)', 'tarefa(s)')
  final String itemLabel;

  /// IDs dos itens selecionados
  final Set<String> selectedIds;

  /// Callback quando a seleção muda
  final void Function(Set<String>)? onSelectionChanged;

  /// Callback quando uma linha é clicada
  final void Function(T)? onRowTap;

  /// Ações disponíveis para cada item
  final List<DataTableAction<T>>? actions;

  /// Índice da coluna de ordenação (controle externo)
  final int? externalSortColumnIndex;

  /// Direção da ordenação (controle externo)
  final bool externalSortAscending;

  /// Callback quando a ordenação muda
  final void Function(int columnIndex, bool ascending)? onSort;

  /// Comparadores de ordenação para cada coluna
  final List<int Function(T, T)>? sortComparators;

  /// Widget a ser exibido quando está carregando
  final Widget? loadingWidget;

  /// Widget a ser exibido quando não há itens
  final Widget? emptyWidget;

  /// Widget a ser exibido quando há erro
  final Widget? errorWidget;

  /// Se está carregando
  final bool isLoading;

  /// Se há erro
  final bool hasError;

  /// Callback quando a página muda
  final void Function(int page)? onPageChanged;

  /// Se deve aplicar opacidade em tasks concluídas (apenas para tabelas de tasks)
  final bool dimCompletedTasks;

  /// Função para obter o status de um item (necessário quando dimCompletedTasks = true)
  final String? Function(T)? getStatus;

  /// Se deve mostrar a coluna de checkboxes
  final bool showCheckboxes;

  const DynamicPaginatedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.cellBuilders,
    required this.getId,
    required this.itemLabel,
    this.selectedIds = const {},
    this.onSelectionChanged,
    this.onRowTap,
    this.actions,
    this.externalSortColumnIndex,
    this.externalSortAscending = true,
    this.onSort,
    this.sortComparators,
    this.loadingWidget,
    this.emptyWidget,
    this.errorWidget,
    this.isLoading = false,
    this.hasError = false,
    this.onPageChanged,
    this.dimCompletedTasks = false,
    this.getStatus,
    this.showCheckboxes = true,
  }) : assert(
         cellBuilders.length == columns.length,
         'O número de cellBuilders deve ser igual ao número de columns',
       ),
       assert(
         !dimCompletedTasks || getStatus != null,
         'Se dimCompletedTasks for true, getStatus deve ser fornecido',
       );

  @override
  State<DynamicPaginatedTable<T>> createState() => _DynamicPaginatedTableState<T>();
}

class _DynamicPaginatedTableState<T> extends State<DynamicPaginatedTable<T>> {
  int _currentPage = 0;
  int _itemsPerPage = _kMinItemsPerPage;
  int _previousItemsLength = 0;

  int get _totalPages => (widget.items.length / _itemsPerPage).ceil();

  @override
  void didUpdateWidget(DynamicPaginatedTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se a lista de itens mudou (filtro aplicado, por exemplo), resetar para primeira página
    if (widget.items.length != _previousItemsLength) {
      _previousItemsLength = widget.items.length;
      if (_currentPage > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _currentPage = 0);
            widget.onPageChanged?.call(0);
          }
        });
      }
    }
  }

  List<T> _getPaginatedItems() {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, widget.items.length);
    return widget.items.sublist(start, end);
  }

  Widget _buildPaginationControls() {
    final startItem = widget.items.isEmpty ? 0 : _currentPage * _itemsPerPage + 1;
    final endItem = ((_currentPage + 1) * _itemsPerPage).clamp(0, widget.items.length);
    final totalItems = widget.items.length;

    debugPrint('📄 DynamicPaginatedTable [${widget.itemLabel}]: Pagination - startItem=$startItem, endItem=$endItem, totalItems=$totalItems');
    debugPrint('📄 DynamicPaginatedTable [${widget.itemLabel}]: Pagination - currentPage=$_currentPage, totalPages=$_totalPages');

    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('📄 DynamicPaginatedTable [${widget.itemLabel}]: Pagination Container constraints = $constraints');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border.all(color: const Color(0xFF3E3E3E)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalItems == 0
                    ? 'Nenhum item'
                    : 'Exibindo $startItem-$endItem de $totalItems ${widget.itemLabel} • Página ${_currentPage + 1} de ${_totalPages > 0 ? _totalPages : 1}',
                style: const TextStyle(color: Colors.white70),
              ),
              Row(
                children: [
                  IconOnlyButton(
                    icon: Icons.first_page,
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage = 0);
                            widget.onPageChanged?.call(0);
                          }
                        : null,
                    iconColor: Colors.white,
                    tooltip: 'Primeira página',
                  ),
                  IconOnlyButton(
                    icon: Icons.chevron_left,
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage--);
                            widget.onPageChanged?.call(_currentPage);
                          }
                        : null,
                    iconColor: Colors.white,
                    tooltip: 'Página anterior',
                  ),
                  IconOnlyButton(
                    icon: Icons.chevron_right,
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            setState(() => _currentPage++);
                            widget.onPageChanged?.call(_currentPage);
                          }
                        : null,
                    iconColor: Colors.white,
                    tooltip: 'Próxima página',
                  ),
                  IconOnlyButton(
                    icon: Icons.last_page,
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            final lastPage = _totalPages - 1;
                            setState(() => _currentPage = lastPage);
                            widget.onPageChanged?.call(lastPage);
                          }
                        : null,
                    iconColor: Colors.white,
                    tooltip: 'Última página',
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  /// Constrói skeleton loading para a tabela
  Widget _buildTableSkeleton() {
    // Calcular número de colunas baseado nos parâmetros disponíveis
    final columnCount = widget.columns.length +
        (widget.selectedIds.isNotEmpty || widget.onSelectionChanged != null ? 1 : 0) +
        (widget.actions != null && widget.actions!.isNotEmpty ? 1 : 0);

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 10, // Mostrar 10 linhas skeleton
      itemBuilder: (context, index) => TableRowSkeleton(
        columnCount: columnCount,
        height: 52,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: LayoutBuilder constraints = $constraints');

        // Verificar se temos altura válida
        if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
          debugPrint('⚠️ DynamicPaginatedTable [${widget.itemLabel}]: Altura inválida! hasBoundedHeight=${constraints.hasBoundedHeight}, maxHeight=${constraints.maxHeight}');
          // Se não temos altura válida, usar altura mínima
          return SizedBox(
            height: 150.0,
            child: widget.isLoading
                ? (widget.loadingWidget ?? const Center(child: CircularProgressIndicator()))
                : (widget.hasError
                    ? (widget.errorWidget ?? const Center(child: Text('Erro ao carregar dados')))
                    : (widget.items.isEmpty
                        ? (widget.emptyWidget ?? const Center(child: Text('Nenhum item encontrado')))
                        : const Center(child: Text('Aguardando layout...')))),
          );
        }

        // Calcular altura disponível para a tabela
        // Subtraindo: spacing + pagination + margem extra
        // Garantir altura mínima de 150px
        final rawAvailableHeight = constraints.maxHeight - _kTotalReservedHeight;
        final availableHeight = rawAvailableHeight < 150.0 ? 150.0 : rawAvailableHeight;

        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: rawAvailableHeight = $rawAvailableHeight');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: availableHeight = $availableHeight');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: _kTotalReservedHeight = $_kTotalReservedHeight');

        // Calcular quantidade de itens por página baseado na altura disponível
        // Fórmula: (altura disponível - altura do header) / altura de cada linha
        final calculatedItemsPerPage = ((availableHeight - _kTableHeaderHeight) / _kTableRowHeight).floor();
        final dynamicItemsPerPage = calculatedItemsPerPage > 0 ? calculatedItemsPerPage : _kMinItemsPerPage;

        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: calculatedItemsPerPage = $calculatedItemsPerPage');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: dynamicItemsPerPage = $dynamicItemsPerPage');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: _itemsPerPage = $_itemsPerPage');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: _currentPage = $_currentPage');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: _totalPages = $_totalPages');
        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: total items = ${widget.items.length}');

        // Atualizar _itemsPerPage se mudou
        if (_itemsPerPage != dynamicItemsPerPage) {
          debugPrint('⚠️ DynamicPaginatedTable [${widget.itemLabel}]: _itemsPerPage mudou de $_itemsPerPage para $dynamicItemsPerPage');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _itemsPerPage = dynamicItemsPerPage;
                // Ajustar página atual se necessário
                final totalPages = _totalPages;
                if (_currentPage >= totalPages && totalPages > 0) {
                  debugPrint('⚠️ DynamicPaginatedTable [${widget.itemLabel}]: Ajustando página de $_currentPage para ${totalPages - 1}');
                  _currentPage = totalPages - 1;
                  widget.onPageChanged?.call(_currentPage);
                }
              });
            }
          });
        }

        debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: Construindo Column com tabela e paginação');

        return Column(
          children: [
            // Área da tabela com altura dinâmica
            Builder(
              builder: (context) {
                debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: SizedBox da tabela - height = $availableHeight');
                return SizedBox(
                  height: availableHeight,
                  child: Builder(builder: (context) {
                    debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: Building table content');
                    debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: isLoading = ${widget.isLoading}');
                    debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: hasError = ${widget.hasError}');
                    debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: items.isEmpty = ${widget.items.isEmpty}');

                    if (widget.isLoading) {
                      return widget.loadingWidget ?? _buildTableSkeleton();
                    }

                    if (widget.hasError) {
                      return widget.errorWidget ?? const Center(child: Text('Erro ao carregar dados'));
                    }

                    if (widget.items.isEmpty) {
                      return widget.emptyWidget ?? const Center(child: Text('Nenhum item encontrado'));
                    }

                    final paginatedItems = _getPaginatedItems();
                    debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: paginatedItems.length = ${paginatedItems.length}');

                    return ReusableDataTable<T>(
                      items: paginatedItems,
                      selectedIds: widget.selectedIds,
                      onSelectionChanged: widget.onSelectionChanged,
                      columns: widget.columns,
                      onSort: widget.onSort,
                      externalSortColumnIndex: widget.externalSortColumnIndex,
                      externalSortAscending: widget.externalSortAscending,
                      sortComparators: widget.sortComparators,
                      cellBuilders: widget.cellBuilders,
                      getId: widget.getId,
                      onRowTap: widget.onRowTap,
                      actions: widget.actions,
                      dimCompletedTasks: widget.dimCompletedTasks,
                      getStatus: widget.getStatus,
                      showCheckboxes: widget.showCheckboxes,
                    );
                  }),
                );
              }
            ),

            Builder(
              builder: (context) {
                debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: SizedBox antes da paginação - height = 24');
                return const SizedBox(height: 24);
              }
            ),
            Builder(
              builder: (context) {
                debugPrint('🔍 DynamicPaginatedTable [${widget.itemLabel}]: Construindo controles de paginação');
                return _buildPaginationControls();
              }
            ),
          ],
        );
      },
    );
  }
}

