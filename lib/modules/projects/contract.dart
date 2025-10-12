import 'package:supabase_flutter/supabase_flutter.dart';

/// Contrato público do módulo de projetos
/// Define as operações disponíveis para gestão de projetos
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de projetos.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class ProjectsContract {
  /// Buscar projetos do usuário (como owner ou membro)
  /// OTIMIZAÇÃO: Suporta paginação com offset e limit
  Future<List<Map<String, dynamic>>> getProjects({
    int? offset,
    int? limit,
  });

  /// Buscar projeto por ID
  Future<Map<String, dynamic>?> getProjectById(String projectId);

  /// Buscar projeto por ID com detalhes completos (cliente, criador, etc)
  Future<Map<String, dynamic>?> getProjectWithDetails(String projectId);

  /// Buscar projetos de um cliente específico
  Future<List<Map<String, dynamic>>> getProjectsByClient(String clientId);

  /// Buscar projetos de uma empresa específica
  Future<List<Map<String, dynamic>>> getProjectsByCompany(String companyId);

  /// Buscar projetos de um cliente com moeda específica
  Future<List<Map<String, dynamic>>> getProjectsByClientWithCurrency({
    required String clientId,
    required String currencyCode,
  });

  /// Criar um novo projeto
  Future<Map<String, dynamic>> createProject({
    required String name,
    required String description,
    String? clientId,
    String? companyId,
    String priority = 'medium',
    String status = 'active',
    String? currencyCode,
    DateTime? startDate,
    DateTime? dueDate,
  });

  /// Atualizar um projeto
  Future<Map<String, dynamic>> updateProject({
    required String projectId,
    required Map<String, dynamic> updates,
  });

  /// Deletar um projeto
  Future<void> deleteProject(String projectId);

  /// Atualizar updated_by e updated_at do projeto
  /// Usado quando uma task é criada, duplicada ou excluída
  Future<void> touchProject(String projectId);

  /// Buscar membros de um projeto
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId);

  /// Adicionar membro ao projeto
  Future<Map<String, dynamic>> addProjectMember({
    required String projectId,
    required String userId,
    String role = 'member',
  });

  /// Remover membro do projeto
  Future<void> removeProjectMember({
    required String projectId,
    required String userId,
  });

  /// Escutar mudanças em tempo real na tabela de projetos
  RealtimeChannel subscribeToProjects({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  });
}

