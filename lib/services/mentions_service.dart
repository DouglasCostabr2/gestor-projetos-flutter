import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço para gerenciar menções (@mentions) no sistema
class MentionsService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Extrai IDs de usuários mencionados de um texto
  /// Formato esperado: @[Nome do Usuário](user_id)
  List<String> extractMentionedUserIds(String text) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(2)!).toList();
  }

  /// Extrai menções com nome e ID
  List<Map<String, String>> extractMentions(String text) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    final matches = regex.allMatches(text);
    return matches.map((m) => {
      'name': m.group(1)!,
      'userId': m.group(2)!,
    }).toList();
  }

  /// Formata texto para exibição, substituindo menções por texto simples
  String formatForDisplay(String text) {
    final regex = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');
    return text.replaceAllMapped(regex, (match) => '@${match.group(1)}');
  }

  // ============================================================================
  // COMMENT MENTIONS
  // ============================================================================

  /// Salva menções de um comentário
  Future<void> saveCommentMentions({
    required String commentId,
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);
    if (mentionedUserIds.isEmpty) return;

    // Remover menções antigas
    await _client
        .from('comment_mentions')
        .delete()
        .eq('comment_id', commentId);

    // Inserir novas menções
    final mentions = mentionedUserIds.map((userId) => {
      'comment_id': commentId,
      'mentioned_user_id': userId,
      'mentioned_by_user_id': currentUser.id,
    }).toList();

    if (mentions.isNotEmpty) {
      await _client.from('comment_mentions').insert(mentions);
    }
  }

  /// Lista menções de um comentário
  Future<List<Map<String, dynamic>>> getCommentMentions(String commentId) async {
    final response = await _client
        .from('comment_mentions')
        .select('*, mentioned_user:profiles!comment_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('comment_id', commentId);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista comentários onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getCommentMentionsForUser(String userId) async {
    final response = await _client
        .from('comment_mentions')
        .select('*, comment:task_comments!comment_mentions_comment_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // TASK MENTIONS
  // ============================================================================

  /// Salva menções de uma tarefa
  Future<void> saveTaskMentions({
    required String taskId,
    required String fieldName, // 'title', 'description', 'briefing'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('task_mentions')
        .delete()
        .eq('task_id', taskId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'task_id': taskId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('task_mentions').insert(mentions);
    }
  }

  /// Lista menções de uma tarefa
  Future<List<Map<String, dynamic>>> getTaskMentions(String taskId) async {
    final response = await _client
        .from('task_mentions')
        .select('*, mentioned_user:profiles!task_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('task_id', taskId);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista tarefas onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getTaskMentionsForUser(String userId) async {
    final response = await _client
        .from('task_mentions')
        .select('*, task:tasks!task_mentions_task_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // PROJECT MENTIONS
  // ============================================================================

  /// Salva menções de um projeto
  Future<void> saveProjectMentions({
    required String projectId,
    required String fieldName, // 'title', 'description'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('project_mentions')
        .delete()
        .eq('project_id', projectId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'project_id': projectId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('project_mentions').insert(mentions);
    }
  }

  /// Lista menções de um projeto
  Future<List<Map<String, dynamic>>> getProjectMentions(String projectId) async {
    final response = await _client
        .from('project_mentions')
        .select('*, mentioned_user:profiles!project_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('project_id', projectId);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista projetos onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getProjectMentionsForUser(String userId) async {
    final response = await _client
        .from('project_mentions')
        .select('*, project:projects!project_mentions_project_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // PRODUCT MENTIONS
  // ============================================================================

  /// Salva menções de um produto
  Future<void> saveProductMentions({
    required String productId,
    required String fieldName, // 'description'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('product_mentions')
        .delete()
        .eq('product_id', productId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'product_id': productId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('product_mentions').insert(mentions);
    }
  }

  /// Lista menções de um produto
  Future<List<Map<String, dynamic>>> getProductMentions(String productId) async {
    final response = await _client
        .from('product_mentions')
        .select('*, mentioned_user:profiles!product_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('product_id', productId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista produtos onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getProductMentionsForUser(String userId) async {
    final response = await _client
        .from('product_mentions')
        .select('*, product:products!product_mentions_product_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // PACKAGE MENTIONS
  // ============================================================================

  /// Salva menções de um pacote
  Future<void> savePackageMentions({
    required String packageId,
    required String fieldName, // 'description'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('package_mentions')
        .delete()
        .eq('package_id', packageId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'package_id': packageId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('package_mentions').insert(mentions);
    }
  }

  /// Lista menções de um pacote
  Future<List<Map<String, dynamic>>> getPackageMentions(String packageId) async {
    final response = await _client
        .from('package_mentions')
        .select('*, mentioned_user:profiles!package_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('package_id', packageId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista pacotes onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getPackageMentionsForUser(String userId) async {
    final response = await _client
        .from('package_mentions')
        .select('*, package:packages!package_mentions_package_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // CLIENT MENTIONS
  // ============================================================================

  /// Salva menções de um cliente
  Future<void> saveClientMentions({
    required String clientId,
    required String fieldName, // 'notes'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('client_mentions')
        .delete()
        .eq('client_id', clientId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'client_id': clientId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('client_mentions').insert(mentions);
    }
  }

  /// Lista menções de um cliente
  Future<List<Map<String, dynamic>>> getClientMentions(String clientId) async {
    final response = await _client
        .from('client_mentions')
        .select('*, mentioned_user:profiles!client_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('client_id', clientId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista clientes onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getClientMentionsForUser(String userId) async {
    final response = await _client
        .from('client_mentions')
        .select('*, client:clients!client_mentions_client_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // COMPANY MENTIONS
  // ============================================================================

  /// Salva menções de uma empresa
  Future<void> saveCompanyMentions({
    required String companyId,
    required String fieldName, // 'notes'
    required String content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Usuário não autenticado');
    }

    final mentionedUserIds = extractMentionedUserIds(content);

    // Remover menções antigas deste campo
    await _client
        .from('company_mentions')
        .delete()
        .eq('company_id', companyId)
        .eq('field_name', fieldName);

    // Inserir novas menções
    if (mentionedUserIds.isNotEmpty) {
      final mentions = mentionedUserIds.map((userId) => {
        'company_id': companyId,
        'mentioned_user_id': userId,
        'mentioned_by_user_id': currentUser.id,
        'field_name': fieldName,
      }).toList();

      await _client.from('company_mentions').insert(mentions);
    }
  }

  /// Lista menções de uma empresa
  Future<List<Map<String, dynamic>>> getCompanyMentions(String companyId) async {
    final response = await _client
        .from('company_mentions')
        .select('*, mentioned_user:profiles!company_mentions_mentioned_user_id_fkey(id, full_name, email, avatar_url)')
        .eq('company_id', companyId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lista empresas onde o usuário foi mencionado
  Future<List<Map<String, dynamic>>> getCompanyMentionsForUser(String userId) async {
    final response = await _client
        .from('company_mentions')
        .select('*, company:companies!company_mentions_company_id_fkey(*)')
        .eq('mentioned_user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Busca usuários para autocomplete
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) {
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .order('full_name', ascending: true)
          .limit(10);
      
      return List<Map<String, dynamic>>.from(response);
    }

    final lowerQuery = query.toLowerCase();
    final response = await _client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .or('full_name.ilike.%$lowerQuery%,email.ilike.%$lowerQuery%')
        .order('full_name', ascending: true)
        .limit(10);
    
    return List<Map<String, dynamic>>.from(response);
  }
}

/// Instância global do serviço de menções
final mentionsService = MentionsService();

