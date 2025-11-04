import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper para enriquecer projetos/empresas com informações de responsáveis
/// 
/// Este helper centraliza a lógica de:
/// 1. Buscar tasks de projetos
/// 2. Coletar assigned_to + assignee_user_ids
/// 3. Buscar perfis em lote
/// 4. Agrupar pessoas por projeto/empresa
class ProjectAssigneesHelper {
  /// Enriquece projetos com lista de responsáveis das tasks
  /// 
  /// Busca todas as tasks dos projetos fornecidos, coleta todos os responsáveis
  /// (assigned_to + assignee_user_ids), busca os perfis em lote, e adiciona
  /// a lista de pessoas únicas em cada projeto no campo especificado.
  /// 
  /// Parâmetros:
  /// - [projects]: Lista de projetos a enriquecer
  /// - [projectIdField]: Nome do campo que contém o ID do projeto (padrão: 'id')
  /// - [outputField]: Nome do campo onde a lista de pessoas será adicionada (padrão: 'task_assignees')
  /// 
  /// Exemplo:
  /// ```dart
  /// final projects = await getProjects();
  /// await ProjectAssigneesHelper.enrichWithAssignees(projects);
  /// // Agora cada projeto tem project['task_assignees'] = [lista de pessoas]
  /// ```
  static Future<void> enrichWithAssignees(
    List<Map<String, dynamic>> projects, {
    String projectIdField = 'id',
    String outputField = 'task_assignees',
  }) async {
    if (projects.isEmpty) return;

    final projectIds = projects
        .map((p) => p[projectIdField] as String?)
        .whereType<String>()
        .toList();

    if (projectIds.isEmpty) return;

    // Buscar todas as tasks dos projetos
    final tasksResponse = await Supabase.instance.client
        .from('tasks')
        .select('project_id, assigned_to, assignee_user_ids')
        .inFilter('project_id', projectIds);

    // Coletar todos os user IDs únicos
    final allUserIds = <String>{};
    for (final task in tasksResponse) {
      final assignedTo = task['assigned_to'] as String?;
      if (assignedTo != null) allUserIds.add(assignedTo);

      final assigneeUserIds = task['assignee_user_ids'] as List?;
      if (assigneeUserIds != null) {
        allUserIds.addAll(assigneeUserIds.cast<String>());
      }
    }

    // Buscar perfis de todos os usuários em uma única query
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (allUserIds.isNotEmpty) {
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', allUserIds.toList());

      for (final profile in profilesResponse) {
        final id = profile['id'] as String?;
        if (id != null) {
          profilesMap[id] = profile;
        }
      }
    }

    // Agrupar pessoas por projeto
    final peopleByProject = <String, Set<Map<String, dynamic>>>{};

    for (final task in tasksResponse) {
      final projectId = task['project_id'] as String?;
      if (projectId != null) {
        peopleByProject.putIfAbsent(projectId, () => {});

        // Adicionar assigned_to
        final assignedTo = task['assigned_to'] as String?;
        if (assignedTo != null && profilesMap.containsKey(assignedTo)) {
          peopleByProject[projectId]!.add(profilesMap[assignedTo]!);
        }

        // Adicionar assignee_user_ids
        final assigneeUserIds = task['assignee_user_ids'] as List?;
        if (assigneeUserIds != null) {
          for (final userId in assigneeUserIds) {
            if (userId is String && profilesMap.containsKey(userId)) {
              peopleByProject[projectId]!.add(profilesMap[userId]!);
            }
          }
        }
      }
    }

    // Adicionar lista de pessoas a cada projeto
    for (final project in projects) {
      final projectId = project[projectIdField] as String?;
      if (projectId != null) {
        project[outputField] = peopleByProject[projectId]?.toList() ?? [];
      }
    }
  }

  /// Enriquece empresas com lista de responsáveis das tasks dos projetos
  /// 
  /// Similar a [enrichWithAssignees], mas para empresas.
  /// Busca projetos da empresa, depois tasks dos projetos, e agrupa pessoas por empresa.
  /// 
  /// Parâmetros:
  /// - [companies]: Lista de empresas a enriquecer
  /// - [companyIdField]: Nome do campo que contém o ID da empresa (padrão: 'id')
  /// - [outputField]: Nome do campo onde a lista de pessoas será adicionada (padrão: 'task_people')
  /// 
  /// Exemplo:
  /// ```dart
  /// final companies = await getCompanies();
  /// await ProjectAssigneesHelper.enrichCompaniesWithAssignees(companies);
  /// // Agora cada empresa tem company['task_people'] = [lista de pessoas]
  /// ```
  static Future<void> enrichCompaniesWithAssignees(
    List<Map<String, dynamic>> companies, {
    String companyIdField = 'id',
    String outputField = 'task_people',
  }) async {
    if (companies.isEmpty) return;

    final companyIds = companies
        .map((c) => c[companyIdField] as String?)
        .whereType<String>()
        .toList();

    if (companyIds.isEmpty) return;

    // Buscar todos os projetos das empresas
    final projectsResponse = await Supabase.instance.client
        .from('projects')
        .select('id, company_id')
        .inFilter('company_id', companyIds);

    if (projectsResponse.isEmpty) {
      // Sem projetos, adicionar listas vazias
      for (final company in companies) {
        company[outputField] = [];
      }
      return;
    }

    // Buscar todas as tasks dos projetos
    final projectIds = projectsResponse.map((p) => p['id'] as String).toList();

    final tasksResponse = await Supabase.instance.client
        .from('tasks')
        .select('project_id, assigned_to, assignee_user_ids')
        .inFilter('project_id', projectIds);

    // Coletar todos os user IDs únicos
    final allUserIds = <String>{};
    for (final task in tasksResponse) {
      final assignedTo = task['assigned_to'] as String?;
      if (assignedTo != null) allUserIds.add(assignedTo);

      final assigneeUserIds = task['assignee_user_ids'] as List?;
      if (assigneeUserIds != null) {
        allUserIds.addAll(assigneeUserIds.cast<String>());
      }
    }

    // Buscar perfis de todos os usuários em uma única query
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (allUserIds.isNotEmpty) {
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', allUserIds.toList());

      for (final profile in profilesResponse) {
        final id = profile['id'] as String?;
        if (id != null) {
          profilesMap[id] = profile;
        }
      }
    }

    // Agrupar pessoas por empresa
    final peopleByCompany = <String, Set<Map<String, dynamic>>>{};

    for (final task in tasksResponse) {
      final projectId = task['project_id'] as String?;
      if (projectId != null) {
        // Encontrar a empresa deste projeto
        final project = projectsResponse.firstWhere(
          (p) => p['id'] == projectId,
          orElse: () => <String, dynamic>{},
        );
        final companyId = project['company_id'] as String?;

        if (companyId != null) {
          peopleByCompany.putIfAbsent(companyId, () => {});

          // Adicionar assigned_to
          final assignedTo = task['assigned_to'] as String?;
          if (assignedTo != null && profilesMap.containsKey(assignedTo)) {
            peopleByCompany[companyId]!.add(profilesMap[assignedTo]!);
          }

          // Adicionar assignee_user_ids
          final assigneeUserIds = task['assignee_user_ids'] as List?;
          if (assigneeUserIds != null) {
            for (final userId in assigneeUserIds) {
              if (userId is String && profilesMap.containsKey(userId)) {
                peopleByCompany[companyId]!.add(profilesMap[userId]!);
              }
            }
          }
        }
      }
    }

    // Adicionar lista de pessoas a cada empresa
    for (final company in companies) {
      final companyId = company[companyIdField] as String?;
      if (companyId != null) {
        company[outputField] = peopleByCompany[companyId]?.toList() ?? [];
      }
    }
  }
}

