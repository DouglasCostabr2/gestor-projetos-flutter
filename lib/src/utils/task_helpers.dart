import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/modules/common/organization_context.dart';

/// Enriquece uma lista de tarefas com os perfis de todos os responsáveis.
/// 
/// Esta função:
/// 1. Coleta todos os IDs de responsáveis (tanto `assigned_to` quanto `assignee_user_ids`)
/// 2. Busca os perfis desses usuários no Supabase em uma única query
/// 3. Adiciona o campo `assignees_list` a cada tarefa com os perfis completos
/// 
/// Parâmetros:
/// - `tasks`: Lista de tarefas a serem enriquecidas (modificada in-place)
/// 
/// Exemplo de uso:
/// ```dart
/// final tasks = await tasksModule.getTasks();
/// await enrichTasksWithAssignees(tasks);
/// // Agora cada tarefa tem task['assignees_list'] com os perfis
/// ```
Future<void> enrichTasksWithAssignees(List<Map<String, dynamic>> tasks) async {
  if (tasks.isEmpty) return;

  // Coletar todos os IDs de responsáveis (assigned_to + assignee_user_ids)
  final allAssigneeIds = <String>{};
  
  for (final task in tasks) {
    // Adicionar responsável principal
    final assignedTo = task['assigned_to'] as String?;
    if (assignedTo != null) {
      allAssigneeIds.add(assignedTo);
    }
    
    // Adicionar múltiplos responsáveis
    final assigneeUserIds = (task['assignee_user_ids'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    allAssigneeIds.addAll(assigneeUserIds);
  }

  // Se não há responsáveis, adicionar lista vazia e retornar
  if (allAssigneeIds.isEmpty) {
    for (final task in tasks) {
      task['assignees_list'] = <Map<String, dynamic>>[];
    }
    return;
  }

  // Buscar perfis de todos os responsáveis em uma única query
  final profilesResponse = await Supabase.instance.client
      .from('profiles')
      .select('id, full_name, email, avatar_url')
      .inFilter('id', allAssigneeIds.toList());

  // Criar mapa de perfis por ID para acesso rápido
  final profilesMap = <String, Map<String, dynamic>>{};
  for (final profile in profilesResponse) {
    profilesMap[profile['id'] as String] = profile;
  }

  // Adicionar lista de responsáveis a cada tarefa
  for (final task in tasks) {
    final assignedTo = task['assigned_to'] as String?;
    final assigneeUserIds = (task['assignee_user_ids'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    
    // Coletar todos os IDs únicos para esta tarefa
    final allIds = <String>{
      if (assignedTo != null) assignedTo,
      ...assigneeUserIds,
    };

    // Mapear IDs para perfis (filtrando nulos)
    final assigneesList = allIds
        .map((id) => profilesMap[id])
        .whereType<Map<String, dynamic>>()
        .toList();

    task['assignees_list'] = assigneesList;
  }
}

/// Enriquece uma lista de itens com os perfis dos usuários que fizeram a última atualização.
///
/// Esta função:
/// 1. Coleta todos os IDs de `updated_by` dos itens
/// 2. Busca os perfis desses usuários no Supabase em uma única query
/// 3. Adiciona o campo `updated_by_profile` a cada item com o perfil completo
///
/// Parâmetros:
/// - `items`: Lista de itens a serem enriquecidos (modificada in-place)
/// - `fieldName`: Nome do campo que contém o ID do usuário (padrão: 'updated_by')
/// - `profileFieldName`: Nome do campo onde o perfil será adicionado (padrão: 'updated_by_profile')
///
/// Exemplo de uso:
/// ```dart
/// final tasks = await tasksModule.getTasks();
/// await enrichWithUpdatedByProfiles(tasks);
/// // Agora cada tarefa tem task['updated_by_profile'] com o perfil
/// ```
Future<void> enrichWithUpdatedByProfiles(
  List<Map<String, dynamic>> items, {
  String fieldName = 'updated_by',
  String profileFieldName = 'updated_by_profile',
}) async {
  if (items.isEmpty) return;

  // Coletar todos os IDs de usuários que fizeram atualização
  final updatedByIds = items
      .map((item) => item[fieldName])
      .whereType<String>()
      .toSet();

  if (updatedByIds.isEmpty) return;

  try {
    // Buscar perfis de todos os usuários em uma única query
    final users = await Supabase.instance.client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .inFilter('id', updatedByIds.toList());

    // Criar mapa de perfis por ID para acesso rápido
    final usersMap = <String, Map<String, dynamic>>{};
    for (final user in users) {
      usersMap[user['id'] as String] = user;
    }

    // Adicionar perfil a cada item
    for (final item in items) {
      final userId = item[fieldName];
      if (userId != null && usersMap.containsKey(userId)) {
        item[profileFieldName] = usersMap[userId];
      }
    }
  } catch (e) {
    // Ignorar erro (operação não crítica)
  }
}

/// Busca todos os perfis de usuários da organização atual ordenados por nome.
///
/// Retorna uma lista de perfis com os campos:
/// - `id`: ID do usuário
/// - `full_name`: Nome completo
/// - `email`: Email
/// - `avatar_url`: URL do avatar
///
/// Exemplo de uso:
/// ```dart
/// final allUsers = await fetchAllProfiles();
/// // Usar em dropdowns, filtros, etc.
/// ```
Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
  try {
    // Obter organization_id
    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) {
      return [];
    }


    // Buscar membros ativos da organização usando RPC
    final response = await Supabase.instance.client.rpc(
      'get_organization_members_with_profiles',
      params: {'org_id': orgId},
    );

    // Transformar para o formato esperado
    final profiles = <Map<String, dynamic>>[];
    for (final member in (response as List)) {
      final m = member as Map<String, dynamic>;
      profiles.add({
        'id': m['user_id'],
        'full_name': m['full_name'],
        'email': m['email'],
        'avatar_url': m['avatar_url'],
        'role': m['role'], // Role do profiles
      });
    }

    return profiles;
  } catch (e) {
    return [];
  }
}

/// Transforma uma lista de perfis em um Map indexado por ID.
///
/// Útil para acesso rápido a perfis por ID sem precisar iterar a lista.
///
/// Parâmetros:
/// - `profiles`: Lista de perfis (cada perfil deve ter um campo 'id')
///
/// Retorna:
/// - Map onde a chave é o ID do usuário e o valor é o perfil completo
///
/// Exemplo de uso:
/// ```dart
/// final profiles = await fetchAllProfiles();
/// final profilesMap = createProfilesMap(profiles);
///
/// // Acesso rápido por ID
/// final user = profilesMap['user-id-123'];
/// print(user['full_name']);
/// ```
Map<String, Map<String, dynamic>> createProfilesMap(
  List<Map<String, dynamic>> profiles,
) {
  final map = <String, Map<String, dynamic>>{};
  for (final profile in profiles) {
    final id = profile['id'] as String?;
    if (id != null) {
      map[id] = profile;
    }
  }
  return map;
}
