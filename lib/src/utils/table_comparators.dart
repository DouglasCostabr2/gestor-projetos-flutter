/// Helpers para comparadores de ordenação em tabelas.
///
/// Estes comparadores são reutilizáveis e evitam duplicação de código
/// em diferentes páginas que usam tabelas com ordenação.
library;

/// Comparador para ordenar por título (case-insensitive).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByTitle,
///   // outros comparadores...
/// ]
/// ```
int compareByTitle(Map<String, dynamic> a, Map<String, dynamic> b) {
  return (a['title'] ?? '').toString().toLowerCase()
      .compareTo((b['title'] ?? '').toString().toLowerCase());
}

/// Comparador para ordenar por nome (case-insensitive).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByName,
///   // outros comparadores...
/// ]
/// ```
int compareByName(Map<String, dynamic> a, Map<String, dynamic> b) {
  return (a['name'] ?? '').toString().toLowerCase()
      .compareTo((b['name'] ?? '').toString().toLowerCase());
}

/// Comparador para ordenar por status.
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByStatus,
///   // outros comparadores...
/// ]
/// ```
int compareByStatus(Map<String, dynamic> a, Map<String, dynamic> b) {
  return (a['status'] ?? '').toString()
      .compareTo((b['status'] ?? '').toString());
}

/// Comparador para ordenar por prioridade (low < medium < high < urgent).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByPriority,
///   // outros comparadores...
/// ]
/// ```
int compareByPriority(Map<String, dynamic> a, Map<String, dynamic> b) {
  const priorities = {'low': 0, 'medium': 1, 'high': 2, 'urgent': 3};
  final priorityA = priorities[a['priority']] ?? 1;
  final priorityB = priorities[b['priority']] ?? 1;
  return priorityA.compareTo(priorityB);
}

/// Comparador para ordenar por data de vencimento (due_date).
/// 
/// Datas nulas são consideradas maiores (vão para o final).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByDueDate,
///   // outros comparadores...
/// ]
/// ```
int compareByDueDate(Map<String, dynamic> a, Map<String, dynamic> b) {
  final dateA = a['due_date'] != null ? DateTime.tryParse(a['due_date']) : null;
  final dateB = b['due_date'] != null ? DateTime.tryParse(b['due_date']) : null;
  
  if (dateA == null && dateB == null) return 0;
  if (dateA == null) return 1; // Nulos vão para o final
  if (dateB == null) return -1;
  
  return dateA.compareTo(dateB);
}

/// Comparador para ordenar por data de criação (created_at).
/// 
/// Datas nulas são consideradas maiores (vão para o final).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByCreatedAt,
///   // outros comparadores...
/// ]
/// ```
int compareByCreatedAt(Map<String, dynamic> a, Map<String, dynamic> b) {
  final dateA = a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
  final dateB = b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
  
  if (dateA == null && dateB == null) return 0;
  if (dateA == null) return 1;
  if (dateB == null) return -1;
  
  return dateA.compareTo(dateB);
}

/// Comparador para ordenar por data de atualização (updated_at).
/// 
/// Datas nulas são consideradas maiores (vão para o final).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByUpdatedAt,
///   // outros comparadores...
/// ]
/// ```
int compareByUpdatedAt(Map<String, dynamic> a, Map<String, dynamic> b) {
  final dateA = a['updated_at'] != null ? DateTime.tryParse(a['updated_at']) : null;
  final dateB = b['updated_at'] != null ? DateTime.tryParse(b['updated_at']) : null;
  
  if (dateA == null && dateB == null) return 0;
  if (dateA == null) return 1;
  if (dateB == null) return -1;
  
  return dateA.compareTo(dateB);
}

/// Comparador para ordenar por nome de projeto (projects.name).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByProjectName,
///   // outros comparadores...
/// ]
/// ```
int compareByProjectName(Map<String, dynamic> a, Map<String, dynamic> b) {
  return (a['projects']?['name'] ?? '').toString().toLowerCase()
      .compareTo((b['projects']?['name'] ?? '').toString().toLowerCase());
}

/// Comparador para ordenar por responsável (primeiro nome da lista de assignees).
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   compareByAssignee,
///   // outros comparadores...
/// ]
/// ```
int compareByAssignee(Map<String, dynamic> a, Map<String, dynamic> b) {
  final assigneesA = a['assignees_list'] as List<dynamic>?;
  final assigneesB = b['assignees_list'] as List<dynamic>?;
  
  final nameA = (assigneesA?.isNotEmpty ?? false) 
      ? (assigneesA!.first['full_name'] ?? '').toString().toLowerCase()
      : '';
  final nameB = (assigneesB?.isNotEmpty ?? false)
      ? (assigneesB!.first['full_name'] ?? '').toString().toLowerCase()
      : '';
  
  return nameA.compareTo(nameB);
}

/// Cria um comparador customizado para um campo específico.
/// 
/// Parâmetros:
/// - `fieldName`: Nome do campo a ser comparado
/// - `caseInsensitive`: Se true, compara strings ignorando maiúsculas/minúsculas (padrão: true)
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   createFieldComparator('description'),
///   createFieldComparator('email', caseInsensitive: false),
/// ]
/// ```
int Function(Map<String, dynamic>, Map<String, dynamic>) createFieldComparator(
  String fieldName, {
  bool caseInsensitive = true,
}) {
  return (a, b) {
    final valueA = (a[fieldName] ?? '').toString();
    final valueB = (b[fieldName] ?? '').toString();
    
    if (caseInsensitive) {
      return valueA.toLowerCase().compareTo(valueB.toLowerCase());
    }
    
    return valueA.compareTo(valueB);
  };
}

/// Cria um comparador para campos de data customizados.
/// 
/// Parâmetros:
/// - `fieldName`: Nome do campo de data a ser comparado
/// - `nullsLast`: Se true, valores nulos vão para o final (padrão: true)
/// 
/// Exemplo de uso:
/// ```dart
/// sortComparators: [
///   createDateComparator('completed_at'),
///   createDateComparator('start_date', nullsLast: false),
/// ]
/// ```
int Function(Map<String, dynamic>, Map<String, dynamic>) createDateComparator(
  String fieldName, {
  bool nullsLast = true,
}) {
  return (a, b) {
    final dateA = a[fieldName] != null ? DateTime.tryParse(a[fieldName]) : null;
    final dateB = b[fieldName] != null ? DateTime.tryParse(b[fieldName]) : null;
    
    if (dateA == null && dateB == null) return 0;
    
    if (nullsLast) {
      if (dateA == null) return 1;
      if (dateB == null) return -1;
    } else {
      if (dateA == null) return -1;
      if (dateB == null) return 1;
    }
    
    return dateA.compareTo(dateB);
  };
}

