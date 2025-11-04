import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de cache para usuários
/// 
/// Mantém uma lista de usuários em memória para evitar múltiplas
/// requisições ao Supabase durante o autocomplete de menções
class UsersCacheService {
  static final UsersCacheService _instance = UsersCacheService._internal();
  factory UsersCacheService() => _instance;
  UsersCacheService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Cache de usuários
  List<Map<String, dynamic>>? _cachedUsers;
  DateTime? _lastFetchTime;
  
  // Tempo de validade do cache (5 minutos)
  static const _cacheDuration = Duration(minutes: 5);

  /// Carrega usuários do cache ou do Supabase
  Future<List<Map<String, dynamic>>> getUsers({bool forceRefresh = false}) async {
    // Se forceRefresh ou cache expirado, buscar do Supabase
    if (forceRefresh || _shouldRefreshCache()) {
      await _fetchUsers();
    }

    return _cachedUsers ?? [];
  }

  /// Verifica se o cache deve ser atualizado
  bool _shouldRefreshCache() {
    if (_cachedUsers == null || _lastFetchTime == null) {
      return true;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference > _cacheDuration;
  }

  /// Busca usuários do Supabase
  Future<void> _fetchUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, full_name, email, avatar_url, role')
          .order('full_name');

      _cachedUsers = List<Map<String, dynamic>>.from(response);
      _lastFetchTime = DateTime.now();
    } catch (e) {
      // Em caso de erro, manter cache antigo se existir
      _cachedUsers ??= [];
    }
  }

  /// Filtra usuários por query
  List<Map<String, dynamic>> filterUsers(String query) {
    if (_cachedUsers == null) return [];

    final lowerQuery = query.toLowerCase();
    return _cachedUsers!.where((user) {
      final name = (user['full_name'] as String? ?? '').toLowerCase();
      final email = (user['email'] as String? ?? '').toLowerCase();
      return name.contains(lowerQuery) || email.contains(lowerQuery);
    }).toList();
  }

  /// Limpa o cache
  void clearCache() {
    _cachedUsers = null;
    _lastFetchTime = null;
  }

  /// Adiciona ou atualiza um usuário no cache
  void updateUserInCache(Map<String, dynamic> user) {
    if (_cachedUsers == null) return;

    final index = _cachedUsers!.indexWhere((u) => u['id'] == user['id']);
    if (index >= 0) {
      _cachedUsers![index] = user;
    } else {
      _cachedUsers!.add(user);
      _cachedUsers!.sort((a, b) {
        final nameA = a['full_name'] as String? ?? '';
        final nameB = b['full_name'] as String? ?? '';
        return nameA.compareTo(nameB);
      });
    }
  }

  /// Remove um usuário do cache
  void removeUserFromCache(String userId) {
    if (_cachedUsers == null) return;
    _cachedUsers!.removeWhere((u) => u['id'] == userId);
  }
}

