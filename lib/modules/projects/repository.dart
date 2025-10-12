import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
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
      // OTIMIZAÇÃO: Suporte a paginação
      if (offset != null && limit != null) {
        debugPrint('🔍 Carregando projetos com paginação: offset=$offset, limit=$limit');
      }

      var queryBuilder = _client
          .from('projects')
          .select('''
            *,
            profiles:owner_id(full_name, avatar_url),
            clients:client_id(name, company, email, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''');

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
          'owner_id': project['owner_id'] ?? '',
          'client_id': project['client_id'],
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
      debugPrint('Erro ao buscar projetos: $e');
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
      debugPrint('Erro ao buscar projeto por ID: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getProjectWithDetails(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select('''
            id, name, description, status, currency_code, client_id, owner_id,
            created_at, updated_at, created_by, updated_by,
            clients:client_id(name),
            created_by_profile:created_by(full_name, email),
            updated_by_profile:updated_by(full_name, email)
          ''')
          .eq('id', projectId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar projeto com detalhes: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByClient(String clientId) async {
    try {
      debugPrint('Buscando projetos do cliente: $clientId');
      final response = await _client
          .from('projects')
          .select('''
            *,
            profiles!projects_owner_id_fkey(full_name, avatar_url),
            clients!projects_client_id_fkey(name, company)
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      debugPrint('Projetos do cliente encontrados: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar projetos do cliente: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByCompany(String companyId) async {
    try {
      debugPrint('Buscando projetos da empresa: $companyId');
      final response = await _client
          .from('projects')
          .select('''
            *,
            profiles!projects_owner_id_fkey(full_name, avatar_url),
            companies!projects_company_id_fkey(name, client_id)
          ''')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);

      debugPrint('Projetos da empresa encontrados: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar projetos da empresa: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsByClientWithCurrency({
    required String clientId,
    required String currencyCode,
  }) async {
    try {
      debugPrint('Buscando projetos do cliente $clientId com moeda $currencyCode');
      final response = await _client
          .from('projects')
          .select('id, name, value_cents')
          .eq('client_id', clientId)
          .eq('currency_code', currencyCode);

      debugPrint('Projetos encontrados: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar projetos do cliente com moeda: $e');
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

    final projectData = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'owner_id': user.id,
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
      debugPrint('Erro ao criar projeto: $e');
      debugPrint('Dados enviados: $projectData');
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
        debugPrint('Erro ao buscar dados antigos do projeto: $e');
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
          debugPrint('⚠️ Erro ao renomear pasta do projeto no Google Drive (ignorado): $e');
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
      debugPrint('✅ Projeto $projectId atualizado (touch)');
    } catch (e) {
      debugPrint('⚠️ Erro ao atualizar projeto (touch): $e');
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

