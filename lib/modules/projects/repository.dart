import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de projetos
class ProjectsRepository implements ProjectsContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getProjects({
    int? offset,
    int? limit,
  }) async {
    try {
      // Obter usuário autenticado
      final currentUser = authModule.currentUser;
      if (currentUser == null) {
        return [];
      }

      // Obter organização ativa
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        return [];
      }

      final userId = currentUser.id;

      // OTIMIZAÇÃO: Suporte a paginação
      if (offset != null && limit != null) {
      }

      // SEGURANÇA: Buscar apenas projetos que o usuário tem acesso
      // 1. Projetos onde é owner
      // 2. Projetos onde é membro (project_members)
      // 3. Projetos onde tem tarefas atribuídas

      // Primeiro, buscar IDs de projetos onde o usuário é membro
      final memberProjectsResponse = await _client
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId);

      final memberProjectIds = memberProjectsResponse
          .map((m) => m['project_id'] as String)
          .toSet();

      // Buscar IDs de projetos onde o usuário tem tarefas
      final taskProjectsResponse = await _client
          .from('tasks')
          .select('project_id')
          .or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId}');

      final taskProjectIds = taskProjectsResponse
          .map((t) => t['project_id'] as String?)
          .whereType<String>()
          .toSet();

      // Combinar todos os IDs de projetos acessíveis
      final accessibleProjectIds = <String>{
        ...memberProjectIds,
        ...taskProjectIds,
      };

      // Buscar projetos
      var queryBuilder = _client
          .from('projects')
          .select('''
            *,
            profiles:owner_id(full_name, avatar_url),
            clients:client_id(name, company, email, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .eq('organization_id', orgId);

      // Filtrar: owner OU está na lista de projetos acessíveis
      if (accessibleProjectIds.isNotEmpty) {
        queryBuilder = queryBuilder.or('owner_id.eq.$userId,id.in.(${accessibleProjectIds.join(',')})');
      } else {
        // Se não tem projetos acessíveis, mostrar apenas os que é owner
        queryBuilder = queryBuilder.eq('owner_id', userId);
      }

      var orderedQuery = queryBuilder.order('created_at', ascending: false);

      // Aplicar paginação após order
      final response = offset != null && limit != null
          ? await orderedQuery.range(offset, offset + limit - 1)
          : await orderedQuery;


      return response.map<Map<String, dynamic>>((project) {
        return {
          'id': project['id'] ?? '',
          'name': project['name'] ?? 'Projeto sem nome',
          'description': project['description'],
          'description_json': project['description_json'],
          'owner_id': project['owner_id'] ?? '',
          'client_id': project['client_id'],
          'company_id': project['company_id'],
          'status': project['status'] ?? 'active',
          'priority': project['priority'] ?? 'medium',
          'start_date': project['start_date'],
          'due_date': project['due_date'],
          'created_at': project['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': project['updated_at'] ?? DateTime.now().toIso8601String(),
          'updated_by': project['updated_by'],
          'value_cents': project['value_cents'],
          'currency_code': project['currency_code'] ?? 'BRL',
          'profiles': project['profiles'],
          'clients': project['clients'],
          'updated_by_profile': project['updated_by_profile'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getProjectById(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select('*')
          .eq('id', projectId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getProjectWithDetails(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select('''
            id, name, description, description_json, status, currency_code, value_cents, client_id, company_id, owner_id,
            created_at, updated_at, created_by, updated_by,
            clients:client_id(name, avatar_url),
            created_by_profile:created_by(full_name, email),
            updated_by_profile:updated_by(full_name, email)
          ''')
          .eq('id', projectId)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByClient(String clientId) async {
    try {
      final response = await _client
          .from('projects')
          .select('''
            *,
            profiles!projects_owner_id_fkey(full_name, avatar_url),
            clients!projects_client_id_fkey(name, company)
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByCompany(String companyId) async {
    try {
      final response = await _client
          .from('projects')
          .select('''
            *,
            profiles!projects_owner_id_fkey(full_name, avatar_url),
            companies!projects_company_id_fkey(name, client_id)
          ''')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByClientWithCurrency({
    required String clientId,
    required String currencyCode,
  }) async {
    try {
      final response = await _client
          .from('projects')
          .select('id, name, value_cents')
          .eq('client_id', clientId)
          .eq('currency_code', currencyCode);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
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
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    final projectData = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'owner_id': user.id,
      'organization_id': orgId,
      'client_id': clientId,
      'priority': priority,
      'status': status,
    };

    if (companyId != null) {
      projectData['company_id'] = companyId;
    }
    if (currencyCode != null) {
      projectData['currency_code'] = currencyCode;
    }
    if (startDate != null) {
      projectData['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (dueDate != null) {
      projectData['due_date'] = dueDate.toIso8601String().split('T')[0];
    }

    try {
      final response = await _client
          .from('projects')
          .insert(projectData)
          .select()
          .single();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateProject({
    required String projectId,
    required Map<String, dynamic> updates,
  }) async {
    // Buscar dados antigos se o nome está sendo alterado
    String? oldName;
    String? clientName;
    String? companyName;
    if (updates.containsKey('name')) {
      try {
        final current = await _client
            .from('projects')
            .select('name, clients(name), companies(name)')
            .eq('id', projectId)
            .single();
        oldName = current['name'] as String?;
        final clientData = current['clients'] as Map<String, dynamic>?;
        clientName = clientData?['name'] as String?;
        final companyData = current['companies'] as Map<String, dynamic>?;
        companyName = companyData?['name'] as String?;
      } catch (e) {
        // Ignorar erro (operação não crítica)
      }
    }

    // Adicionar updated_by e updated_at
    final user = authModule.currentUser;
    if (user != null) {
      updates['updated_by'] = user.id;
    }
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from('projects')
        .update(updates)
        .eq('id', projectId)
        .select()
        .single();

    // Renomear pasta no Google Drive se o nome foi alterado
    if (updates.containsKey('name') && oldName != null && oldName.isNotEmpty &&
        clientName != null && clientName.isNotEmpty) {
      final newName = updates['name'] as String?;
      if (newName != null && newName.trim() != oldName) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();
          await drive.renameProjectFolder(
            client: authed,
            clientName: clientName,
            oldProjectName: oldName,
            newProjectName: newName.trim(),
            companyName: companyName,
          );
        } catch (e) {
          // Ignorar erro (operação não crítica)
        }
      }
    }

    return response;
  }

  @override
  Future<void> deleteProject(String projectId) async {
    await _client
        .from('projects')
        .delete()
        .eq('id', projectId);
  }

  /// Atualizar updated_by e updated_at do projeto
  /// Usado quando uma task é criada, duplicada ou excluída
  @override
  Future<void> touchProject(String projectId) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('projects')
          .update({
            'updated_by': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', projectId);
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
    final response = await _client
        .from('project_members')
        .select('''
          *,
          profiles:user_id(full_name, avatar_url, email)
        ''')
        .eq('project_id', projectId);
    return response;
  }

  @override
  Future<Map<String, dynamic>> addProjectMember({
    required String projectId,
    required String userId,
    String role = 'member',
  }) async {
    final response = await _client
        .from('project_members')
        .insert({
          'project_id': projectId,
          'user_id': userId,
          'role': role,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<void> removeProjectMember({
    required String projectId,
    required String userId,
  }) async {
    await _client
        .from('project_members')
        .delete()
        .eq('project_id', projectId)
        .eq('user_id', userId);
  }

  @override
  RealtimeChannel subscribeToProjects({
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    final channel = _client
        .channel('projects_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'projects',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'projects',
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'projects',
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    return channel;
  }
}

final ProjectsContract projectsModule = ProjectsRepository();

