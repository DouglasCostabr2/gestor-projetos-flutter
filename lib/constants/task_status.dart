/// Constantes e helpers para status de tarefas
class TaskStatus {
  // Valores válidos no banco de dados
  static const String todo = 'todo';
  static const String inProgress = 'in_progress';
  static const String review = 'review';
  static const String waiting = 'waiting';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// Lista de todos os status válidos
  static const List<String> values = [
    todo,
    inProgress,
    review,
    waiting,
    completed,
    cancelled,
  ];

  /// Obter label em português para um status
  static String getLabel(String status) {
    switch (status) {
      case todo:
        return 'A Fazer';
      case inProgress:
        return 'Em Andamento';
      case review:
        return 'Em Revisão';
      case waiting:
        return 'Aguardando';
      case completed:
        return 'Concluída';
      case cancelled:
        return 'Cancelada';
      default:
        return status;
    }
  }

  /// Verificar se um status é válido
  static bool isValid(String status) {
    return values.contains(status);
  }

  /// Verificar se é status de espera
  static bool isWaiting(String? status) {
    if (status == null) return false;
    final normalized = status.toLowerCase();
    return normalized == waiting || normalized == 'aguardando';
  }
}

