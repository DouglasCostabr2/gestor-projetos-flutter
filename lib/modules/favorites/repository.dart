import 'package:supabase_flutter/supabase_flutter.dart';
import 'contract.dart';

/// Implementação do módulo de favoritos
class FavoritesRepository implements FavoritesContract {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obter ID do usuário autenticado
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  Future<bool> addFavorite({
    required String itemType,
    required String itemId,
  }) async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Verificar se já está favoritado
      final exists = await isFavorite(itemType: itemType, itemId: itemId);
      if (exists) {
        return false; // Já estava favoritado
      }

      // Inserir favorito
      await _supabase.from('user_favorites').insert({
        'user_id': _userId,
        'item_type': itemType,
        'item_id': itemId,
      });

      return true; // Adicionado com sucesso
    } catch (e) {
      throw Exception('Erro ao adicionar favorito: $e');
    }
  }

  @override
  Future<bool> removeFavorite({
    required String itemType,
    required String itemId,
  }) async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Deletar favorito
      final response = await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', _userId!)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .select();

      return response.isNotEmpty; // true se deletou algo
    } catch (e) {
      throw Exception('Erro ao remover favorito: $e');
    }
  }

  @override
  Future<bool> isFavorite({
    required String itemType,
    required String itemId,
  }) async {
    if (_userId == null) {
      return false; // Usuário não autenticado não tem favoritos
    }

    try {
      final response = await _supabase
          .from('user_favorites')
          .select('id')
          .eq('user_id', _userId!)
          .eq('item_type', itemType)
          .eq('item_id', itemId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw Exception('Erro ao verificar favorito: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserFavorites({
    String? itemType,
  }) async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      var query = _supabase
          .from('user_favorites')
          .select()
          .eq('user_id', _userId!);

      if (itemType != null) {
        query = query.eq('item_type', itemType);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar favoritos: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteProjects() async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Buscar IDs dos projetos favoritados
      final favorites = await getUserFavorites(itemType: 'project');

      if (favorites.isEmpty) {
        return [];
      }

      final projectIds = favorites.map((f) => f['item_id'] as String).toList();

      // Buscar detalhes dos projetos
      final response = await _supabase
          .from('projects')
          .select('''
            id,
            name,
            description,
            status,
            priority,
            start_date,
            due_date,
            created_at,
            updated_at,
            updated_by,
            value_cents,
            currency_code,
            owner_id,
            client_id,
            profiles:owner_id(id, full_name, avatar_url),
            clients:client_id(id, name, company, email, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .inFilter('id', projectIds)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar projetos favoritos: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteTasks() async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Buscar IDs das tarefas favoritadas (apenas tarefas principais, sem parent_task_id)
      final favorites = await getUserFavorites(itemType: 'task');

      if (favorites.isEmpty) {
        return [];
      }

      final taskIds = favorites.map((f) => f['item_id'] as String).toList();

      // Buscar detalhes das tarefas
      final response = await _supabase
          .from('tasks')
          .select('''
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at,
            updated_at,
            updated_by,
            completed_at,
            project_id,
            assigned_to,
            assignee_user_ids,
            parent_task_id,
            projects:project_id(id, name, client_id),
            assignee_profile:assigned_to(id, full_name, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .inFilter('id', taskIds)
          .isFilter('parent_task_id', null) // Apenas tarefas principais
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar tarefas favoritas: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFavoriteSubTasks() async {
    if (_userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Buscar IDs das subtarefas favoritadas
      final favorites = await getUserFavorites(itemType: 'subtask');
      if (favorites.isEmpty) {
        return [];
      }

      final subTaskIds = favorites.map((f) => f['item_id'] as String).toList();

      // Buscar detalhes das subtarefas
      final response = await _supabase
          .from('tasks')
          .select('''
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at,
            updated_at,
            updated_by,
            completed_at,
            project_id,
            assigned_to,
            assignee_user_ids,
            parent_task_id,
            projects:project_id(id, name, client_id),
            parent_task:parent_task_id(id, title),
            assignee_profile:assigned_to(id, full_name, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .inFilter('id', subTaskIds)
          .not('parent_task_id', 'is', null) // Apenas subtarefas
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao buscar subtarefas favoritas: $e');
    }
  }

  @override
  Future<bool> toggleFavorite({
    required String itemType,
    required String itemId,
  }) async {
    final isFav = await isFavorite(itemType: itemType, itemId: itemId);
    
    if (isFav) {
      await removeFavorite(itemType: itemType, itemId: itemId);
      return false; // Foi removido
    } else {
      await addFavorite(itemType: itemType, itemId: itemId);
      return true; // Foi adicionado
    }
  }
}

/// Instância global do módulo de favoritos
final favoritesModule = FavoritesRepository();

