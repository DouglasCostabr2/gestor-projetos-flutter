/// Constantes e helpers para status de projetos
class ProjectStatus {
  // Valores válidos no banco de dados
  static const String notStarted = 'not_started';
  static const String negotiation = 'negotiation';
  static const String inProgress = 'in_progress';
  static const String paused = 'paused';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// Lista de todos os status válidos
  static const List<String> values = [
    notStarted,
    negotiation,
    inProgress,
    paused,
    completed,
    cancelled,
  ];

  /// Obter label em português para um status
  static String getLabel(String status) {
    switch (status) {
      case notStarted:
        return 'Não iniciado';
      case negotiation:
        return 'Em negociação';
      case inProgress:
        return 'Em andamento';
      case paused:
        return 'Pausado';
      case completed:
        return 'Concluído';
      case cancelled:
        return 'Cancelado';
      // Compatibilidade com status antigos
      case 'active':
      case 'ativo':
        return 'Em andamento';
      case 'inactive':
      case 'inativo':
        return 'Pausado';
      default:
        return status;
    }
  }

  /// Normalizar status antigos para novos
  static String normalize(String status) {
    switch (status) {
      case 'active':
      case 'ativo':
        return inProgress;
      case 'inactive':
      case 'inativo':
        return paused;
      default:
        return status;
    }
  }

  /// Verificar se um status é válido
  static bool isValid(String status) {
    return values.contains(status) || 
           status == 'active' || 
           status == 'inactive' ||
           status == 'ativo' ||
           status == 'inativo';
  }
}

