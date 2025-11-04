import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/google_drive_oauth_service.dart';
import '../auth/module.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de tarefas
class TasksRepository implements TasksContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getTasks({
    String? projectId,
    int? offset,
    int? limit,
  }) async {
    try {
      // Obter usuário autenticado
      final currentUser = authModule.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Usuário não autenticado - retornando lista vazia');
        return [];
      }

      // Obter organização ativa
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        debugPrint('⚠️ Nenhuma organização ativa - retornando lista vazia');
        return [];
      }

      final userId = currentUser.id;

      // OTIMIZAÇÃO: Suporte a paginação
      if (offset != null && limit != null) {
        debugPrint('🔍 Carregando tarefas com paginação: offset=$offset, limit=$limit');
      }

      // SEGURANÇA: Buscar apenas tarefas que o usuário tem acesso
      // 1. Tarefas onde é assigned_to (responsável principal)
      // 2. Tarefas onde está em assignee_user_ids (múltiplos responsáveis)
      // 3. Tarefas de projetos onde é membro (project_members)
      // 4. Tarefas de projetos onde é owner

      // Buscar IDs de projetos onde o usuário é membro ou owner
      final memberProjectsResponse = await _client
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId);

      final memberProjectIds = memberProjectsResponse
          .map((m) => m['project_id'] as String)
          .toSet();

      final ownerProjectsResponse = await _client
          .from('projects')
          .select('id')
          .eq('owner_id', userId);

      final ownerProjectIds = ownerProjectsResponse
          .map((p) => p['id'] as String)
          .toSet();

      // Combinar IDs de projetos acessíveis
      final accessibleProjectIds = <String>{
        ...memberProjectIds,
        ...ownerProjectIds,
      };

      var queryBuilder = _client
          .from('tasks')
          .select('''
            *,
            projects:project_id(name, client_id),
            creator_profile:profiles!tasks_created_by_fkey(full_name, email, avatar_url),
            assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url),
            updated_by_profile:profiles!tasks_updated_by_fkey(full_name, email, avatar_url)
          ''')
          .eq('organization_id', orgId);

      if (projectId != null) {
        queryBuilder = queryBuilder.eq('project_id', projectId);
      }

      // Filtrar tarefas por acesso do usuário
      // Construir filtro OR complexo
      final filters = <String>[];

      // Responsável principal
      filters.add('assigned_to.eq.$userId');

      // Múltiplos responsáveis (usando contains)
      filters.add('assignee_user_ids.cs.{$userId}');

      // Criador da tarefa (tasks que o usuário criou)
      filters.add('created_by.eq.$userId');

      // Projetos acessíveis
      if (accessibleProjectIds.isNotEmpty) {
        filters.add('project_id.in.(${accessibleProjectIds.join(',')})');
      }

      if (filters.isNotEmpty) {
        queryBuilder = queryBuilder.or(filters.join(','));
      } else {
        // Se não tem nenhum filtro, retornar vazio
        debugPrint('⚠️ Usuário não tem acesso a nenhuma tarefa');
        return [];
      }

      var orderedQuery = queryBuilder.order('created_at', ascending: false);

      // Aplicar paginação após order
      final response = offset != null && limit != null
          ? await orderedQuery.range(offset, offset + limit - 1)
          : await orderedQuery;

      debugPrint('✅ Tarefas filtradas por usuário: ${response.length} encontradas');

      return response.map<Map<String, dynamic>>((task) {
        return {
          'id': task['id'] ?? '',
          'title': task['title'] ?? 'Tarefa sem título',
          'description': task['description'],
          'project_id': task['project_id'] ?? '',
          'created_by': task['created_by'] ?? '',
          'assigned_to': task['assigned_to'],
          'assignee_user_ids': task['assignee_user_ids'],
          'status': task['status'] ?? 'todo',
          'priority': task['priority'] ?? 'medium',
          'start_date': task['start_date'],
          'due_date': task['due_date'],
          'completed_at': task['completed_at'],
          'estimated_hours': task['estimated_hours'],
          'actual_hours': task['actual_hours'],
          'tags': task['tags'],
          'created_at': task['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': task['updated_at'] ?? DateTime.now().toIso8601String(),
          'projects': task['projects'],
          'creator_profile': task['creator_profile'],
          'assignee_profile': task['assignee_profile'],
          'updated_by_profile': task['updated_by_profile'],
          'users': task['assignee_profile'], // Alias para compatibilidade
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Erro ao buscar tarefas: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getTaskById(String taskId) async {
    try {
      final response = await _client
          .from('tasks')
          .select('*')
          .eq('id', taskId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar tarefa por ID: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> getTaskWithDetails(String taskId) async {
    try {
      final response = await _client
          .from('tasks')
          .select('''
            id, title, description, status, priority, created_at, updated_at,
            completed_at, created_by, updated_by, due_date, project_id,
            assigned_to, assignee_user_ids, parent_task_id,
            projects:project_id(id, name, client_id, clients:client_id(id, name, avatar_url)),
            assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url),
            created_by_profile:profiles!tasks_created_by_fkey(full_name, email),
            updated_by_profile:profiles!tasks_updated_by_fkey(full_name, email)
          ''')
          .eq('id', taskId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar tarefa com detalhes: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectTasks(String projectId) async {
    // Obter usuário autenticado
    final currentUser = authModule.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ Usuário não autenticado - retornando lista vazia');
      return [];
    }

    final userId = currentUser.id;

    // Verificar se o usuário tem acesso ao projeto
    final hasAccess = await _checkProjectAccess(projectId, userId);
    if (!hasAccess) {
      debugPrint('⚠️ Usuário não tem acesso ao projeto $projectId');
      return [];
    }

    // Verificar se o usuário é admin/gestor (vê todas as tarefas) ou usuário comum (vê apenas suas tarefas)
    final isAdminOrGestor = await _isAdminOrGestor(userId);

    var queryBuilder = _client
        .from('tasks')
        .select('''
          *,
          assigned_to_profile:profiles!tasks_assigned_to_fkey(full_name, avatar_url),
          created_by_profile:profiles!tasks_created_by_fkey(full_name, avatar_url)
        ''')
        .eq('project_id', projectId);

    // Se não for admin/gestor, filtrar apenas tarefas atribuídas ao usuário OU criadas por ele
    if (!isAdminOrGestor) {
      queryBuilder = queryBuilder.or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId},created_by.eq.$userId');
    }

    final response = await queryBuilder.order('created_at', ascending: false);
    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectMainTasks(String projectId) async {
    // Obter usuário autenticado
    final currentUser = authModule.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ Usuário não autenticado - retornando lista vazia');
      return [];
    }

    final userId = currentUser.id;

    // Verificar se o usuário tem acesso ao projeto
    final hasAccess = await _checkProjectAccess(projectId, userId);
    if (!hasAccess) {
      debugPrint('⚠️ Usuário não tem acesso ao projeto $projectId');
      return [];
    }

    // Verificar se o usuário é admin/gestor (vê todas as tarefas) ou usuário comum (vê apenas suas tarefas)
    final isAdminOrGestor = await _isAdminOrGestor(userId);

    var queryBuilder = _client
        .from('tasks')
        .select('''
          id, title, status, priority, assigned_to, assignee_user_ids, due_date, created_at, updated_at,
          updated_by, created_by,
          assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url),
          updated_by_profile:profiles!tasks_updated_by_fkey(full_name, email, avatar_url)
        ''')
        .eq('project_id', projectId)
        .isFilter('parent_task_id', null);

    // Se não for admin/gestor, filtrar apenas tarefas atribuídas ao usuário OU criadas por ele
    if (!isAdminOrGestor) {
      queryBuilder = queryBuilder.or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId},created_by.eq.$userId');
    }

    final response = await queryBuilder.order('created_at', ascending: false);
    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectSubTasks(String projectId) async {
    // Obter usuário autenticado
    final currentUser = authModule.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ Usuário não autenticado - retornando lista vazia');
      return [];
    }

    final userId = currentUser.id;

    // Verificar se o usuário tem acesso ao projeto
    final hasAccess = await _checkProjectAccess(projectId, userId);
    if (!hasAccess) {
      debugPrint('⚠️ Usuário não tem acesso ao projeto $projectId');
      return [];
    }

    // Verificar se o usuário é admin/gestor (vê todas as tarefas) ou usuário comum (vê apenas suas tarefas)
    final isAdminOrGestor = await _isAdminOrGestor(userId);

    var queryBuilder = _client
        .from('tasks')
        .select('''
          id, title, status, priority, assigned_to, assignee_user_ids, due_date, created_at, updated_at,
          updated_by, created_by, parent_task_id,
          assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url),
          updated_by_profile:profiles!tasks_updated_by_fkey(full_name, email, avatar_url)
        ''')
        .eq('project_id', projectId)
        .not('parent_task_id', 'is', null);

    // Se não for admin/gestor, filtrar apenas tarefas atribuídas ao usuário OU criadas por ele
    if (!isAdminOrGestor) {
      queryBuilder = queryBuilder.or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId},created_by.eq.$userId');
    }

    final response = await queryBuilder.order('created_at', ascending: false);
    return response;
  }

  @override
  Future<List<Map<String, dynamic>>> getTaskSubTasks(String taskId) async {
    // Obter usuário autenticado
    final currentUser = authModule.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ Usuário não autenticado - retornando lista vazia');
      return [];
    }

    final userId = currentUser.id;

    // Verificar se o usuário tem acesso à tarefa pai
    final hasAccess = await _checkTaskAccess(taskId, userId);
    if (!hasAccess) {
      debugPrint('⚠️ Usuário não tem acesso à tarefa $taskId');
      return [];
    }

    final response = await _client
        .from('tasks')
        .select('''
          id, title, status, priority, assigned_to, assignee_user_ids, due_date, created_at, updated_at, created_by,
          assignee_profile:profiles!tasks_assigned_to_fkey(full_name, email, avatar_url)
        ''')
        .eq('parent_task_id', taskId)
        .order('created_at', ascending: false);

    return response;
  }

  /// Verifica se o usuário é admin ou gestor
  Future<bool> _isAdminOrGestor(String userId) async {
    try {
      final profileResponse = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse == null) return false;

      final role = (profileResponse['role'] as String?)?.toLowerCase();
      return role == 'admin' || role == 'gestor';
    } catch (e) {
      debugPrint('❌ Erro ao verificar role do usuário: $e');
      return false;
    }
  }

  /// Verifica se o usuário tem acesso a um projeto
  /// Retorna true se o usuário é owner, membro ou tem tarefas no projeto
  Future<bool> _checkProjectAccess(String projectId, String userId) async {
    try {
      // Verificar se é owner do projeto
      final projectResponse = await _client
          .from('projects')
          .select('owner_id')
          .eq('id', projectId)
          .maybeSingle();

      if (projectResponse != null && projectResponse['owner_id'] == userId) {
        return true;
      }

      // Verificar se é membro do projeto
      final memberResponse = await _client
          .from('project_members')
          .select('user_id')
          .eq('project_id', projectId)
          .eq('user_id', userId)
          .maybeSingle();

      if (memberResponse != null) {
        return true;
      }

      // Verificar se tem tarefas atribuídas no projeto OU criadas pelo usuário
      final taskResponse = await _client
          .from('tasks')
          .select('id')
          .eq('project_id', projectId)
          .or('assigned_to.eq.$userId,assignee_user_ids.cs.{$userId},created_by.eq.$userId')
          .limit(1)
          .maybeSingle();

      return taskResponse != null;
    } catch (e) {
      debugPrint('❌ Erro ao verificar acesso ao projeto: $e');
      return false;
    }
  }

  /// Verifica se o usuário tem acesso a uma tarefa
  /// Retorna true se o usuário é responsável, criador, membro do projeto ou owner do projeto
  Future<bool> _checkTaskAccess(String taskId, String userId) async {
    try {
      final taskResponse = await _client
          .from('tasks')
          .select('project_id, assigned_to, assignee_user_ids, created_by')
          .eq('id', taskId)
          .maybeSingle();

      if (taskResponse == null) return false;

      // Verificar se é o criador da tarefa
      if (taskResponse['created_by'] == userId) {
        return true;
      }

      // Verificar se é responsável direto
      if (taskResponse['assigned_to'] == userId) {
        return true;
      }

      // Verificar se está na lista de responsáveis
      final assigneeUserIds = taskResponse['assignee_user_ids'] as List?;
      if (assigneeUserIds != null && assigneeUserIds.contains(userId)) {
        return true;
      }

      // Verificar acesso ao projeto
      final projectId = taskResponse['project_id'] as String?;
      if (projectId != null) {
        return await _checkProjectAccess(projectId, userId);
      }

      return false;
    } catch (e) {
      debugPrint('❌ Erro ao verificar acesso à tarefa: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    required String projectId,
    String? assignedTo,
    List<String>? assigneeUserIds,
    String status = 'todo',
    String priority = 'medium',
    DateTime? startDate,
    DateTime? dueDate,
    int? estimatedHours,
    List<String>? tags,
    String? parentTaskId,
  }) async {
    final user = authModule.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    final taskData = <String, dynamic>{
      'title': title.trim(),
      'description': description?.trim(),
      'project_id': projectId,
      'organization_id': orgId,
      'created_by': user.id,
      'assigned_to': assignedTo,
      'status': status,
      'priority': priority,
    };

    // Adicionar múltiplos responsáveis se fornecido
    if (assigneeUserIds != null && assigneeUserIds.isNotEmpty) {
      taskData['assignee_user_ids'] = assigneeUserIds;
    }

    if (parentTaskId != null) {
      taskData['parent_task_id'] = parentTaskId;
    }

    if (startDate != null) {
      taskData['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (dueDate != null) {
      taskData['due_date'] = dueDate.toIso8601String().split('T')[0];
    }

    try {
      final response = await _client
          .from('tasks')
          .insert(taskData)
          .select()
          .single();

      // Se é uma subtarefa, criar pasta no Google Drive
      if (parentTaskId != null) {
        try {
          // Buscar informações da tarefa principal, projeto e cliente
          final parentTask = await _client
              .from('tasks')
              .select('title, projects(name, clients(name), companies(name))')
              .eq('id', parentTaskId)
              .single();

          final projectData = parentTask['projects'] as Map<String, dynamic>?;
          if (projectData != null) {
            final clientData = projectData['clients'] as Map<String, dynamic>?;
            final companyData = projectData['companies'] as Map<String, dynamic>?;

            if (clientData != null) {
              final clientName = clientData['name'] as String;
              final projectName = projectData['name'] as String;
              final taskName = parentTask['title'] as String;
              final companyName = companyData?['name'] as String?;

              final drive = GoogleDriveOAuthService();
              final authed = await drive.getAuthedClient();

              // Criar pasta da subtarefa no Google Drive
              await drive.ensureSubTaskFolder(
                authed,
                clientName,
                projectName,
                taskName,
                title.trim(),
                companyName: companyName,
              );

              debugPrint('✅ Pasta da subtarefa criada no Google Drive: $title');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao criar pasta da subtarefa no Google Drive (ignorado): $e');
        }
      }

      return response;
    } catch (e) {
      debugPrint('Erro ao criar tarefa: $e');
      debugPrint('Dados enviados: $taskData');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? assignedTo,
    List<String>? assigneeUserIds,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedAt,
    int? estimatedHours,
    int? actualHours,
    List<String>? tags,
  }) async {
    // Buscar dados antigos se o título está sendo alterado
    String? oldTitle;
    String? clientName;
    String? projectName;
    String? companyName;
    String? parentTaskId;
    String? parentTaskTitle;
    if (title != null) {
      try {
        final current = await _client
            .from('tasks')
            .select('title, parent_task_id, projects(name, clients(name), companies(name))')
            .eq('id', taskId)
            .single();
        oldTitle = current['title'] as String?;
        parentTaskId = current['parent_task_id'] as String?;
        final projectData = current['projects'] as Map<String, dynamic>?;
        projectName = projectData?['name'] as String?;
        final clientData = projectData?['clients'] as Map<String, dynamic>?;
        clientName = clientData?['name'] as String?;
        final companyData = projectData?['companies'] as Map<String, dynamic>?;
        companyName = companyData?['name'] as String?;

        // Se é uma subtarefa, buscar o título da tarefa principal
        if (parentTaskId != null) {
          try {
            final parentTask = await _client
                .from('tasks')
                .select('title')
                .eq('id', parentTaskId)
                .single();
            parentTaskTitle = parentTask['title'] as String?;
          } catch (e) {
            debugPrint('Erro ao buscar título da tarefa principal: $e');
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar dados antigos da tarefa: $e');
      }
    }

    final updateData = <String, dynamic>{};

    if (title != null) updateData['title'] = title.trim();
    if (description != null) updateData['description'] = description.trim();
    if (assignedTo != null) updateData['assigned_to'] = assignedTo;
    if (status != null) {
      updateData['status'] = status;
      if (status == 'completed' && completedAt == null) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      } else if (status != 'completed') {
        updateData['completed_at'] = null;
      }
    }
    if (priority != null) updateData['priority'] = priority;
    if (estimatedHours != null) updateData['estimated_hours'] = estimatedHours;
    if (actualHours != null) updateData['actual_hours'] = actualHours;
    if (tags != null) updateData['tags'] = tags;
    if (completedAt != null) updateData['completed_at'] = completedAt.toIso8601String();

    // Adicionar múltiplos responsáveis se fornecido
    if (assigneeUserIds != null) {
      updateData['assignee_user_ids'] = assigneeUserIds;
    }

    if (startDate != null) {
      updateData['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (dueDate != null) {
      updateData['due_date'] = dueDate.toIso8601String().split('T')[0];
    }

    // Adicionar updated_by e updated_at
    final user = authModule.currentUser;
    if (user != null) {
      updateData['updated_by'] = user.id;
    }
    updateData['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from('tasks')
          .update(updateData)
          .eq('id', taskId)
          .select()
          .single();

      // Renomear pasta no Google Drive se o título foi alterado
      if (title != null && oldTitle != null && oldTitle.isNotEmpty &&
          clientName != null && clientName.isNotEmpty &&
          projectName != null && projectName.isNotEmpty) {
        if (title.trim() != oldTitle) {
          try {
            final drive = GoogleDriveOAuthService();
            final authed = await drive.getAuthedClient();

            // Se é uma subtarefa, renomear pasta de subtarefa
            if (parentTaskId != null && parentTaskTitle != null && parentTaskTitle.isNotEmpty) {
              await drive.renameSubTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                taskName: parentTaskTitle,
                oldSubTaskName: oldTitle,
                newSubTaskName: title.trim(),
                companyName: companyName,
              );
            } else {
              // Se é uma tarefa principal, renomear pasta de tarefa
              await drive.renameTaskFolder(
                client: authed,
                clientName: clientName,
                projectName: projectName,
                oldTaskName: oldTitle,
                newTaskName: title.trim(),
                companyName: companyName,
              );
            }
          } catch (e) {
            debugPrint('⚠️ Erro ao renomear pasta da tarefa no Google Drive (ignorado): $e');
          }
        }
      }

      return response;
    } catch (e) {
      debugPrint('Erro ao atualizar tarefa: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    try {
      // Buscar informações da tarefa antes de deletar
      String? taskTitle;
      String? clientName;
      String? projectName;
      String? companyName;
      String? parentTaskId;
      String? parentTaskTitle;

      try {
        final task = await _client
            .from('tasks')
            .select('title, parent_task_id, projects(name, clients(name), companies(name))')
            .eq('id', taskId)
            .single();

        taskTitle = task['title'] as String?;
        parentTaskId = task['parent_task_id'] as String?;
        final projectData = task['projects'] as Map<String, dynamic>?;
        projectName = projectData?['name'] as String?;
        final clientData = projectData?['clients'] as Map<String, dynamic>?;
        clientName = clientData?['name'] as String?;
        final companyData = projectData?['companies'] as Map<String, dynamic>?;
        companyName = companyData?['name'] as String?;

        // Se é uma subtarefa, buscar o título da tarefa principal
        if (parentTaskId != null) {
          try {
            final parentTask = await _client
                .from('tasks')
                .select('title')
                .eq('id', parentTaskId)
                .single();
            parentTaskTitle = parentTask['title'] as String?;
          } catch (e) {
            debugPrint('Erro ao buscar título da tarefa principal: $e');
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar dados da tarefa para deletar: $e');
      }

      // Deletar a tarefa do banco de dados
      await _client
          .from('tasks')
          .delete()
          .eq('id', taskId);

      // Deletar pasta no Google Drive
      if (taskTitle != null && taskTitle.isNotEmpty &&
          clientName != null && clientName.isNotEmpty &&
          projectName != null && projectName.isNotEmpty) {
        try {
          final drive = GoogleDriveOAuthService();
          final authed = await drive.getAuthedClient();

          // Se é uma subtarefa, deletar pasta de subtarefa
          if (parentTaskId != null && parentTaskTitle != null && parentTaskTitle.isNotEmpty) {
            await drive.deleteSubTaskFolder(
              client: authed,
              clientName: clientName,
              projectName: projectName,
              taskName: parentTaskTitle,
              subTaskName: taskTitle,
              companyName: companyName,
            );
          } else {
            // Se é uma tarefa principal, deletar pasta de tarefa
            await drive.deleteTaskFolder(
              client: authed,
              clientName: clientName,
              projectName: projectName,
              taskName: taskTitle,
              companyName: companyName,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar pasta da tarefa no Google Drive (ignorado): $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao deletar tarefa: $e');
      rethrow;
    }
  }

  /// Atualizar updated_by e updated_at da tarefa
  /// Usado quando comentário, checkbox, asset ou arquivo é adicionado/removido
  @override
  Future<void> touchTask(String taskId) async {
    final user = authModule.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('tasks')
          .update({
            'updated_by': user.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      debugPrint('✅ Task $taskId atualizada (touch)');
    } catch (e) {
      debugPrint('⚠️ Erro ao atualizar task (touch): $e');
    }
  }

  @override
  Future<void> updateTasksPriorityByDueDate() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final threeDaysFromNow = today.add(const Duration(days: 3));

      final tasks = await _client
          .from('tasks')
          .select('id, due_date, status, priority')
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .not('due_date', 'is', null);

      for (final task in tasks) {
        final dueDateStr = task['due_date'] as String?;
        if (dueDateStr == null) continue;

        final dueDate = DateTime.parse(dueDateStr);
        final currentPriority = task['priority'] as String? ?? 'medium';
        String newPriority = currentPriority;

        if (dueDate.isBefore(today)) {
          newPriority = 'urgent';
        } else if (dueDate.isBefore(threeDaysFromNow)) {
          if (currentPriority != 'urgent') {
            newPriority = 'high';
          }
        }

        if (newPriority != currentPriority) {
          await _client
              .from('tasks')
              .update({'priority': newPriority})
              .eq('id', task['id']);
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar prioridades: $e');
    }
  }

  @override
  Future<void> updateSingleTaskPriority(String taskId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Buscar a task
      final task = await _client
          .from('tasks')
          .select('id, due_date, status, priority')
          .eq('id', taskId)
          .single();

      final status = task['status'] as String?;
      final dueDateStr = task['due_date'] as String?;
      final currentPriority = task['priority'] as String?;

      // Não atualizar se concluída ou cancelada
      if (status == 'completed' || status == 'done' || status == 'cancelled') {
        return;
      }

      if (dueDateStr == null) return;

      final dueDate = DateTime.parse(dueDateStr);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

      String? newPriority;

      // Atrasada → Urgente
      if (dueDay.isBefore(today)) {
        newPriority = 'urgent';
      }
      // Vence hoje → Alta
      else if (dueDay.isAtSameMomentAs(today)) {
        newPriority = 'high';
      }
      // Vence amanhã → Média
      else if (dueDay.isAtSameMomentAs(tomorrow)) {
        newPriority = 'medium';
      }

      // Atualizar apenas se a prioridade mudou
      if (newPriority != null && newPriority != currentPriority) {
        await _client
            .from('tasks')
            .update({'priority': newPriority})
            .eq('id', taskId);

        debugPrint('✅ Task $taskId: $currentPriority → $newPriority (prazo: $dueDateStr)');
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar prioridade da task $taskId: $e');
    }
  }

  @override
  String getStatusLabel(String status) {
    const statusLabels = {
      'todo': 'A Fazer',
      'in_progress': 'Em Andamento',
      'review': 'Em Revisão',
      'completed': 'Concluída',
      'cancelled': 'Cancelada',
      'waiting': 'Aguardando',
    };
    return statusLabels[status] ?? status;
  }

  @override
  bool isValidStatus(String status) {
    const validStatuses = ['todo', 'in_progress', 'review', 'completed', 'cancelled', 'waiting'];
    return validStatuses.contains(status);
  }

  @override
  bool isWaitingStatus(String? status) {
    if (status == null) return false;
    final normalized = status.toLowerCase();
    return normalized == 'waiting' || normalized == 'aguardando';
  }

  @override
  Future<void> setTaskWaitingStatus({
    required String taskId,
    required bool isWaiting,
  }) async {
    try {
      await _client
          .from('tasks')
          .update({'status': isWaiting ? 'waiting' : 'todo'})
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Erro ao atualizar status de espera: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTaskStatus(String taskId) async {
    try {
      // Buscar a task atual
      final task = await _client
          .from('tasks')
          .select('id, status, previous_status')
          .eq('id', taskId)
          .maybeSingle();

      if (task == null) {
        debugPrint('⚠️ Task não encontrada: $taskId');
        return;
      }

      // Buscar todas as subtasks desta task
      final subTasks = await _client
          .from('tasks')
          .select('id, status')
          .eq('parent_task_id', taskId);

      // Se não tem subtasks, garantir que não está em "waiting"
      if (subTasks.isEmpty) {
        if (task['status'] == 'waiting') {
          final previousStatus = task['previous_status'] ?? 'todo';
          await _client
              .from('tasks')
              .update({
                'status': previousStatus,
                'previous_status': null,
              })
              .eq('id', taskId);
        }
        return;
      }

      // Verificar se todas as subtasks estão concluídas
      final allCompleted = subTasks.every((st) => st['status'] == 'completed');
      final hasIncomplete = subTasks.any((st) => st['status'] != 'completed');

      final currentStatus = task['status'] as String;

      // Se tem subtasks incompletas e não está em "waiting"
      if (hasIncomplete && currentStatus != 'waiting') {
        await _client
            .from('tasks')
            .update({
              'status': 'waiting',
              'previous_status': currentStatus,
            })
            .eq('id', taskId);
      }
      // Se todas as subtasks foram concluídas e está em "waiting"
      else if (allCompleted && currentStatus == 'waiting') {
        await _client
            .from('tasks')
            .update({
              'status': 'review',
              'previous_status': null,
            })
            .eq('id', taskId);
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar status da task: $e');
    }
  }

  @override
  Future<bool> canCompleteTask(String taskId) async {
    try {
      // Buscar todas as subtasks desta task
      final subTasks = await _client
          .from('tasks')
          .select('id, status')
          .eq('parent_task_id', taskId);

      // Se não tem subtasks, pode concluir
      if (subTasks.isEmpty) {
        return true;
      }

      // Verificar se todas as subtasks estão concluídas
      final allCompleted = subTasks.every((st) => st['status'] == 'completed');

      return allCompleted;
    } catch (e) {
      debugPrint('❌ Erro ao verificar se pode concluir task: $e');
      return true; // Em caso de erro, permitir conclusão
    }
  }

  @override
  RealtimeChannel subscribeToProjectTasks({
    required String projectId,
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
  }) {
    final channel = _client
        .channel('tasks_channel_$projectId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'project_id',
            value: projectId,
          ),
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    return channel;
  }
}

final TasksContract tasksModule = TasksRepository();

