import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/table_utils.dart';

/// Mixin reutilizável para gerenciar estado de tabelas com filtros, ordenação e seleção.
/// 
/// Este mixin fornece:
/// - Gerenciamento de dados (original, filtrado)
/// - Sistema de busca e filtros
/// - Sistema de ordenação
/// - Seleção múltipla de itens
/// - Loading e error states
/// 
/// Exemplo de uso:
/// ```dart
/// class _MyPageState extends State<MyPage> with TableStateMixin<Map<String, dynamic>> {
///   @override
///   void initState() {
///     super.initState();
///     loadData();
///   }
/// 
///   @override
///   Future<List<Map<String, dynamic>>> fetchData() async {
///     // Buscar dados do backend
///     return await myService.fetchItems();
///   }
/// 
///   @override
///   List<String> get searchFields => ['name', 'email', 'clients.name'];
/// 
///   @override
///   List<int Function(Map<String, dynamic>, Map<String, dynamic>)> get sortComparators => [
///     TableUtils.textComparator('name'),
///     TableUtils.textComparator('email'),
///   ];
/// }
/// ```
mixin TableStateMixin<T extends Map<String, dynamic>> {
  // ============================================================================
  // MÉTODOS ABSTRATOS QUE DEVEM SER IMPLEMENTADOS PELA STATE CLASS
  // ============================================================================

  /// Método setState da State class
  void setState(VoidCallback fn);

  /// Propriedade mounted da State class
  bool get mounted;

  // ============================================================================
  // DADOS
  // ============================================================================

  /// Lista completa de dados (sem filtros aplicados)
  List<T> allData = [];

  /// Lista filtrada de dados (com filtros e busca aplicados)
  List<T> filteredData = [];

  // ============================================================================
  // ESTADOS
  // ============================================================================

  /// Se está carregando dados
  bool isLoading = true;

  /// Mensagem de erro (null se não houver erro)
  String? errorMessage;

  // ============================================================================
  // BUSCA E FILTROS
  // ============================================================================

  /// Query de busca atual
  String searchQuery = '';

  /// Tipo de filtro selecionado
  String filterType = 'none';

  /// Valor do filtro selecionado
  String? filterValue;

  /// Timer para debounce de busca
  Timer? _searchDebounceTimer;

  // ============================================================================
  // ORDENAÇÃO
  // ============================================================================

  /// Índice da coluna de ordenação atual
  int? sortColumnIndex = 0;

  /// Se a ordenação é ascendente
  bool sortAscending = true;

  // ============================================================================
  // SELEÇÃO
  // ============================================================================

  /// IDs dos itens selecionados
  final Set<String> selectedIds = <String>{};

  // ============================================================================
  // MÉTODOS ABSTRATOS (devem ser implementados pela classe que usa o mixin)
  // ============================================================================

  /// Busca dados do backend/fonte de dados.
  /// 
  /// Este método deve ser implementado pela classe que usa o mixin.
  Future<List<T>> fetchData();

  /// Campos que serão usados na busca textual.
  /// 
  /// Exemplo: ['name', 'email', 'clients.name']
  List<String> get searchFields;

  /// Comparadores de ordenação para cada coluna.
  /// 
  /// Deve retornar uma lista de comparadores na mesma ordem das colunas da tabela.
  List<int Function(T, T)> get sortComparators;

  // ============================================================================
  // MÉTODOS OPCIONAIS (podem ser sobrescritos)
  // ============================================================================

  /// Aplica filtro customizado aos dados.
  /// 
  /// Por padrão, não aplica nenhum filtro adicional.
  /// Sobrescreva este método para implementar filtros específicos.
  bool applyCustomFilter(T item) {
    return true;
  }

  /// Callback chamado após carregar dados com sucesso.
  void onDataLoaded() {}

  /// Callback chamado quando ocorre erro ao carregar dados.
  void onDataError(String error) {}

  // ============================================================================
  // MÉTODOS PÚBLICOS
  // ============================================================================

  /// Carrega dados da fonte de dados.
  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await fetchData();
      
      if (!mounted) return;

      setState(() {
        allData = data;
        isLoading = false;
        applyFilters();
      });

      onDataLoaded();
    } catch (e) {
      if (!mounted) return;

      final error = e.toString();
      setState(() {
        errorMessage = error;
        isLoading = false;
      });

      onDataError(error);
    }
  }

  /// Recarrega dados (alias para loadData).
  Future<void> reloadData() => loadData();

  /// Aplica filtros e busca aos dados.
  void applyFilters() {
    setState(() {
      var filtered = List<T>.from(allData);

      // Aplicar busca textual
      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((item) {
          return TableUtils.searchInFields(
            item,
            query: searchQuery,
            fields: searchFields,
          );
        }).toList();
      }

      // Aplicar filtro customizado
      filtered = filtered.where(applyCustomFilter).toList();

      filteredData = filtered;
      applySorting();
    });
  }

  /// Aplica ordenação aos dados filtrados.
  void applySorting() {
    if (sortColumnIndex == null) return;

    final comparators = sortComparators;
    if (sortColumnIndex! >= comparators.length) return;

    final comparator = comparators[sortColumnIndex!];

    filteredData.sort((a, b) {
      final result = comparator(a, b);
      return sortAscending ? result : -result;
    });
  }

  /// Atualiza query de busca e reaplica filtros.
  void updateSearchQuery(String query) {
    searchQuery = query;
    applyFilters();
  }

  /// Atualiza query de busca com debounce e reaplica filtros.
  /// Evita queries excessivas enquanto o usuário digita.
  void updateSearchQueryDebounced(String query, {Duration delay = const Duration(milliseconds: 300)}) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(delay, () {
      searchQuery = query;
      applyFilters();
    });
  }

  /// Cancela o timer de debounce (deve ser chamado no dispose).
  void cancelSearchDebounce() {
    _searchDebounceTimer?.cancel();
  }

  /// Atualiza tipo de filtro e reaplica filtros.
  void updateFilterType(String type) {
    filterType = type;
    filterValue = null;
    applyFilters();
  }

  /// Atualiza valor do filtro e reaplica filtros.
  void updateFilterValue(String? value) {
    filterValue = value?.isEmpty == true ? null : value;
    applyFilters();
  }

  /// Atualiza ordenação e reaplica.
  void updateSorting(int columnIndex, bool ascending) {
    setState(() {
      sortColumnIndex = columnIndex;
      sortAscending = ascending;
      applySorting();
    });
  }

  /// Atualiza seleção de itens.
  void updateSelection(Set<String> ids) {
    setState(() {
      selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  /// Seleciona todos os itens filtrados.
  void selectAll() {
    setState(() {
      selectedIds.clear();
      for (final item in filteredData) {
        final id = item['id'] as String?;
        if (id != null) {
          selectedIds.add(id);
        }
      }
    });
  }

  /// Limpa seleção.
  void clearSelection() {
    setState(() {
      selectedIds.clear();
    });
  }

  /// Limpa todos os filtros e busca.
  void clearFilters() {
    setState(() {
      searchQuery = '';
      filterType = 'none';
      filterValue = null;
      applyFilters();
    });
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  /// Obtém valores únicos de um campo.
  List<String> getUniqueValues(String field, {bool sorted = true}) {
    return TableUtils.getUniqueValues(allData, field, sorted: sorted);
  }

  /// Obtém item por ID.
  T? getItemById(String id) {
    try {
      return allData.firstWhere((item) => item['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se um item está selecionado.
  bool isSelected(String id) {
    return selectedIds.contains(id);
  }

  /// Obtém itens selecionados.
  List<T> getSelectedItems() {
    return allData.where((item) {
      final id = item['id'] as String?;
      return id != null && selectedIds.contains(id);
    }).toList();
  }
}

