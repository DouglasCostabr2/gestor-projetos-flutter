/// Contrato público do módulo de rastreamento de tempo
/// Define as operações disponíveis para gerenciar registros de tempo em tarefas
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de time tracking.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class TimeTrackingContract {
  /// Iniciar uma nova sessão de tempo para uma tarefa
  /// 
  /// Retorna o ID do time_log criado
  /// Throws Exception se o usuário não estiver autenticado ou não for o responsável
  Future<String> startTimeLog({
    required String taskId,
  });

  /// Pausar/Finalizar uma sessão de tempo em andamento
  ///
  /// Atualiza o end_time e calcula a duração
  /// Opcionalmente salva uma descrição da atividade realizada
  /// Retorna o time_log atualizado
  Future<Map<String, dynamic>> stopTimeLog({
    required String timeLogId,
    String? description,
  });

  /// Buscar a sessão de tempo ativa (em andamento) de uma tarefa para o usuário atual
  /// 
  /// Retorna null se não houver sessão ativa
  Future<Map<String, dynamic>?> getActiveTimeLog({
    required String taskId,
  });

  /// Buscar todos os registros de tempo de uma tarefa
  /// 
  /// Retorna lista ordenada por start_time (mais recente primeiro)
  Future<List<Map<String, dynamic>>> getTaskTimeLogs({
    required String taskId,
  });

  /// Buscar o tempo total gasto em uma tarefa (em segundos)
  /// 
  /// Retorna a soma de todas as sessões finalizadas
  Future<int> getTotalTimeSpent({
    required String taskId,
  });

  /// Deletar um registro de tempo
  /// 
  /// Apenas o dono do registro pode deletar
  Future<void> deleteTimeLog({
    required String timeLogId,
  });

  /// Atualizar manualmente um registro de tempo
  ///
  /// Permite editar start_time, end_time, description
  /// Recalcula automaticamente a duração
  Future<Map<String, dynamic>> updateTimeLog({
    required String timeLogId,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
  });

  /// Buscar estatísticas de tempo de um usuário
  /// 
  /// Retorna tempo total, número de sessões, média por sessão, etc.
  Future<Map<String, dynamic>> getUserTimeStats({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  });
}

