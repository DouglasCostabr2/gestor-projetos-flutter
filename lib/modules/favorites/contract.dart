/// Contrato público do módulo de favoritos
/// Define as operações disponíveis para gestão de favoritos de usuários
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de favoritos.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class FavoritesContract {
  /// Adicionar um item aos favoritos do usuário
  /// 
  /// [itemType] pode ser: 'project', 'task' ou 'subtask'
  /// [itemId] é o UUID do item a ser favoritado
  /// 
  /// Retorna true se foi adicionado com sucesso, false se já estava favoritado
  Future<bool> addFavorite({
    required String itemType,
    required String itemId,
  });

  /// Remover um item dos favoritos do usuário
  /// 
  /// [itemType] pode ser: 'project', 'task' ou 'subtask'
  /// [itemId] é o UUID do item a ser desfavoritado
  /// 
  /// Retorna true se foi removido com sucesso, false se não estava favoritado
  Future<bool> removeFavorite({
    required String itemType,
    required String itemId,
  });

  /// Verificar se um item está favoritado pelo usuário
  /// 
  /// [itemType] pode ser: 'project', 'task' ou 'subtask'
  /// [itemId] é o UUID do item a verificar
  /// 
  /// Retorna true se o item está favoritado, false caso contrário
  Future<bool> isFavorite({
    required String itemType,
    required String itemId,
  });

  /// Buscar todos os favoritos do usuário
  /// 
  /// [itemType] (opcional) filtra por tipo: 'project', 'task' ou 'subtask'
  /// Se não informado, retorna todos os favoritos
  /// 
  /// Retorna lista de favoritos com informações básicas
  Future<List<Map<String, dynamic>>> getUserFavorites({
    String? itemType,
  });

  /// Buscar projetos favoritados com detalhes completos
  /// 
  /// Retorna lista de projetos favoritados com todas as informações
  /// (nome, cliente, status, etc)
  Future<List<Map<String, dynamic>>> getFavoriteProjects();

  /// Buscar tarefas favoritadas com detalhes completos
  /// 
  /// Retorna lista de tarefas favoritadas com todas as informações
  /// (título, projeto, status, prioridade, etc)
  Future<List<Map<String, dynamic>>> getFavoriteTasks();

  /// Buscar subtarefas favoritadas com detalhes completos
  /// 
  /// Retorna lista de subtarefas favoritadas com todas as informações
  /// (título, tarefa pai, projeto, status, etc)
  Future<List<Map<String, dynamic>>> getFavoriteSubTasks();

  /// Toggle (alternar) favorito de um item
  /// 
  /// Se o item está favoritado, remove. Se não está, adiciona.
  /// 
  /// [itemType] pode ser: 'project', 'task' ou 'subtask'
  /// [itemId] é o UUID do item
  /// 
  /// Retorna true se foi adicionado, false se foi removido
  Future<bool> toggleFavorite({
    required String itemType,
    required String itemId,
  });
}

