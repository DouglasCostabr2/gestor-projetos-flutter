/// Utilitários reutilizáveis para manipulação de dados em tabelas.
/// 
/// Este arquivo contém funções genéricas para:
/// - Filtros de busca e filtros específicos
/// - Ordenação de dados
/// - Extração de valores únicos
/// - Comparadores comuns
class TableUtils {
  TableUtils._(); // Construtor privado para classe utilitária

  // ============================================================================
  // FILTROS DE BUSCA
  // ============================================================================

  /// Aplica busca textual em múltiplos campos de um item.
  /// 
  /// Exemplo:
  /// ```dart
  /// final filtered = items.where((item) => 
  ///   TableUtils.searchInFields(
  ///     item,
  ///     query: 'João',
  ///     fields: ['name', 'email', 'phone'],
  ///   )
  /// ).toList();
  /// ```
  static bool searchInFields(
    Map<String, dynamic> item, {
    required String query,
    required List<String> fields,
    bool caseSensitive = false,
  }) {
    if (query.isEmpty) return true;

    final searchQuery = caseSensitive ? query : query.toLowerCase();

    for (final field in fields) {
      final value = _getNestedValue(item, field);
      if (value == null) continue;

      final stringValue = caseSensitive 
          ? value.toString() 
          : value.toString().toLowerCase();

      if (stringValue.contains(searchQuery)) {
        return true;
      }
    }

    return false;
  }

  /// Obtém valor de campo aninhado usando notação de ponto.
  /// 
  /// Exemplo: 'clients.name' retorna item['clients']['name']
  static dynamic _getNestedValue(Map<String, dynamic> item, String field) {
    final parts = field.split('.');
    dynamic value = item;

    for (final part in parts) {
      if (value is Map<String, dynamic>) {
        value = value[part];
      } else {
        return null;
      }
    }

    return value;
  }

  // ============================================================================
  // FILTROS ESPECÍFICOS
  // ============================================================================

  /// Aplica filtro por valor exato em um campo.
  static bool filterByExactValue(
    Map<String, dynamic> item,
    String field,
    dynamic value,
  ) {
    return _getNestedValue(item, field) == value;
  }

  /// Aplica filtro por faixa de valores numéricos.
  /// 
  /// Exemplo:
  /// ```dart
  /// TableUtils.filterByNumericRange(
  ///   item,
  ///   'value',
  ///   min: 1000,
  ///   max: 10000,
  /// )
  /// ```
  static bool filterByNumericRange(
    Map<String, dynamic> item,
    String field, {
    num? min,
    num? max,
  }) {
    final value = _getNestedValue(item, field);
    if (value == null || value is! num) return false;

    if (min != null && value < min) return false;
    if (max != null && value > max) return false;

    return true;
  }

  /// Aplica filtro por faixa de datas.
  static bool filterByDateRange(
    Map<String, dynamic> item,
    String field, {
    DateTime? start,
    DateTime? end,
  }) {
    final value = _getNestedValue(item, field);
    if (value == null) return false;

    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return false;

    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;

    return true;
  }

  /// Aplica filtro customizado usando uma função predicado.
  static List<T> applyCustomFilter<T>(
    List<T> items,
    bool Function(T item) predicate,
  ) {
    return items.where(predicate).toList();
  }

  // ============================================================================
  // ORDENAÇÃO
  // ============================================================================

  /// Ordena lista por campo específico.
  /// 
  /// Exemplo:
  /// ```dart
  /// TableUtils.sortByField(
  ///   items,
  ///   'name',
  ///   ascending: true,
  /// );
  /// ```
  static void sortByField(
    List<Map<String, dynamic>> items,
    String field, {
    bool ascending = true,
  }) {
    items.sort((a, b) {
      final valueA = _getNestedValue(a, field);
      final valueB = _getNestedValue(b, field);

      final result = _compareValues(valueA, valueB);
      return ascending ? result : -result;
    });
  }

  /// Compara dois valores de forma genérica.
  static int _compareValues(dynamic a, dynamic b) {
    // Null handling
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    // String comparison
    if (a is String && b is String) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    // Numeric comparison
    if (a is num && b is num) {
      return a.compareTo(b);
    }

    // DateTime comparison
    if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }

    // String parsing for DateTime
    if (a is String && b is String) {
      final dateA = DateTime.tryParse(a);
      final dateB = DateTime.tryParse(b);
      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB);
      }
    }

    // Fallback to string comparison
    return a.toString().compareTo(b.toString());
  }

  // ============================================================================
  // COMPARADORES COMUNS
  // ============================================================================

  /// Cria comparador para campo de texto.
  static int Function(Map<String, dynamic>, Map<String, dynamic>) textComparator(
    String field, {
    bool caseSensitive = false,
  }) {
    return (a, b) {
      final valueA = _getNestedValue(a, field)?.toString() ?? '';
      final valueB = _getNestedValue(b, field)?.toString() ?? '';

      if (caseSensitive) {
        return valueA.compareTo(valueB);
      } else {
        return valueA.toLowerCase().compareTo(valueB.toLowerCase());
      }
    };
  }

  /// Cria comparador para campo numérico.
  static int Function(Map<String, dynamic>, Map<String, dynamic>) numericComparator(
    String field,
  ) {
    return (a, b) {
      final valueA = _getNestedValue(a, field) as num? ?? 0;
      final valueB = _getNestedValue(b, field) as num? ?? 0;
      return valueA.compareTo(valueB);
    };
  }

  /// Cria comparador para campo de data.
  static int Function(Map<String, dynamic>, Map<String, dynamic>) dateComparator(
    String field,
  ) {
    return (a, b) {
      final valueA = _getNestedValue(a, field);
      final valueB = _getNestedValue(b, field);

      DateTime? dateA;
      DateTime? dateB;

      if (valueA is DateTime) {
        dateA = valueA;
      } else if (valueA is String) {
        dateA = DateTime.tryParse(valueA);
      }

      if (valueB is DateTime) {
        dateB = valueB;
      } else if (valueB is String) {
        dateB = DateTime.tryParse(valueB);
      }

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    };
  }

  // ============================================================================
  // EXTRAÇÃO DE VALORES ÚNICOS
  // ============================================================================

  /// Extrai valores únicos de um campo específico.
  /// 
  /// Exemplo:
  /// ```dart
  /// final uniqueStatuses = TableUtils.getUniqueValues(
  ///   projects,
  ///   'status',
  ///   sorted: true,
  /// );
  /// ```
  static List<String> getUniqueValues(
    List<Map<String, dynamic>> items,
    String field, {
    bool sorted = true,
    bool excludeEmpty = true,
  }) {
    final values = items
        .map((item) => _getNestedValue(item, field))
        .whereType<String>()
        .where((value) => !excludeEmpty || value.isNotEmpty)
        .toSet()
        .toList();

    if (sorted) {
      values.sort();
    }

    return values;
  }

  /// Extrai valores únicos com contagem.
  /// 
  /// Retorna um mapa onde a chave é o valor e o valor é a contagem.
  static Map<String, int> getUniqueValuesWithCount(
    List<Map<String, dynamic>> items,
    String field,
  ) {
    final counts = <String, int>{};

    for (final item in items) {
      final value = _getNestedValue(item, field)?.toString();
      if (value != null && value.isNotEmpty) {
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }

    return counts;
  }
}

