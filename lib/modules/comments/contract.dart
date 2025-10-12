/// Contrato público do módulo de comentários
/// Define as operações disponíveis para gestão de comentários em tarefas
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de comentários.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class CommentsContract {
  /// Criar um novo comentário
  Future<Map<String, dynamic>> createComment({
    required String taskId,
    required String content,
  });

  /// Buscar comentários de uma tarefa
  Future<List<Map<String, dynamic>>> listByTask(String taskId);

  /// Atualizar um comentário
  Future<Map<String, dynamic>> updateComment({
    required String commentId,
    required String content,
  });

  /// Deletar um comentário
  Future<void> deleteComment(String commentId);
}

