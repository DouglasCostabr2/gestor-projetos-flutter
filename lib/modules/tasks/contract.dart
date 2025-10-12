import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato público do módulo de tarefas
/// Define as operações disponíveis para gestão de tarefas
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de tarefas.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class TasksContract {
  /// Buscar todas as tarefas do usuário
  /// OTIMIZAÇÃO: Suporta paginação com offset e limit
  Future<List<Map<String, dynamic>>> getTasks({
    String? projectId,
    int? offset,
    int? limit,
  });

  /// Buscar tarefa por ID
  Future<Map<String, dynamic>?> getTaskById(String taskId);

  /// Buscar tarefa por ID com detalhes completos (projeto, cliente, perfis, etc)
  Future<Map<String, dynamic>?> getTaskWithDetails(String taskId);

  /// Buscar tarefas de um projeto
  Future<List<Map<String, dynamic>>> getProjectTasks(String projectId);

  /// Buscar tarefas principais de um projeto (sem parent_task_id)
  Future<List<Map<String, dynamic>>> getProjectMainTasks(String projectId);

  /// Buscar subtarefas de um projeto (com parent_task_id)
  Future<List<Map<String, dynamic>>> getProjectSubTasks(String projectId);

  /// Criar uma nova tarefa
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    required String projectId,
    String? assignedTo,
    String status = 'todo',
    String priority = 'medium',
    DateTime? startDate,
    DateTime? dueDate,
    int? estimatedHours,
    List<String>? tags,
    String? parentTaskId,
  });

  /// Atualizar uma tarefa
  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? assignedTo,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedAt,
    int? estimatedHours,
    int? actualHours,
    List<String>? tags,
  });

  /// Deletar uma tarefa
  Future<void> deleteTask(String taskId);

  /// Atualizar updated_by e updated_at da tarefa
  /// Usado quando comentário, checkbox, asset ou arquivo é adicionado/removido
  Future<void> touchTask(String taskId);

  /// Atualizar prioridades das tarefas baseado no prazo
  Future<void> updateTasksPriorityByDueDate();

  /// Atualizar prioridade de uma tarefa específica baseado no prazo
  Future<void> updateSingleTaskPriority(String taskId);

  /// Obter status helper para validações
  String getStatusLabel(String status);
  
  /// Verificar se status é válido
  bool isValidStatus(String status);

  /// Verificar se um status representa uma tarefa aguardando
  bool isWaitingStatus(String? status);

  /// Gerenciar status de espera (waiting)
  Future<void> setTaskWaitingStatus({
    required String taskId,
    required bool isWaiting,
  });

  /// Atualizar status de uma tarefa baseado nas subtarefas
  /// Se tem subtarefas não concluídas, fica "waiting"
  /// Se todas as subtarefas foram concluídas, volta ao status anterior
  Future<void> updateTaskStatus(String taskId);

  /// Verificar se uma tarefa pode ser concluída
  /// Retorna false se a tarefa tem subtarefas não concluídas
  Future<bool> canCompleteTask(String taskId);

  /// Escutar mudanças em tempo real nas tarefas de um projeto
  RealtimeChannel subscribeToProjectTasks({
    required String projectId,
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  });
}

