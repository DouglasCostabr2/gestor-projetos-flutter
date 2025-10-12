/// Contrato público do módulo de usuários
/// Define as operações disponíveis para gestão de perfis e usuários
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de usuários.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class UsersContract {
  /// Buscar perfil do usuário atual
  Future<Map<String, dynamic>?> getCurrentProfile();

  /// Atualizar perfil do usuário
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? avatarUrl,
  });

  /// Buscar perfil de um usuário específico por ID
  Future<Map<String, dynamic>?> getProfileById(String userId);

  /// Buscar todos os perfis (para seleção de usuários)
  Future<List<Map<String, dynamic>>> getAllProfiles();

  /// Buscar perfis de funcionários (usuários com role específico)
  Future<List<Map<String, dynamic>>> getEmployeeProfiles();
}

