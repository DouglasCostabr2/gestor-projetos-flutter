/// Contrato público do módulo de monitoramento
/// Define as operações disponíveis para monitoramento de usuários e atividades
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de monitoramento.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class MonitoringContract {
  /// Buscar todos os dados de monitoramento de forma otimizada
  /// Retorna lista de usuários com suas tasks e pagamentos agregados
  Future<List<Map<String, dynamic>>> fetchMonitoringData();

  /// Buscar atividades de um usuário específico
  Future<Map<String, dynamic>> getUserActivities(String userId);

  /// Buscar estatísticas gerais do sistema
  Future<Map<String, dynamic>> getSystemStatistics();

  /// Filtrar usuários por role
  List<Map<String, dynamic>> filterByRole(List<Map<String, dynamic>> users, String? role);

  /// Filtrar usuários por busca (nome ou email)
  List<Map<String, dynamic>> filterBySearch(List<Map<String, dynamic>> users, String query);

  /// Ordenar usuários por critério
  List<Map<String, dynamic>> sortUsers(List<Map<String, dynamic>> users, String sortBy);
}

