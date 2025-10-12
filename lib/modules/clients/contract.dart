/// Contrato público do módulo de clientes
/// Define as operações disponíveis para gestão de clientes
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de clientes.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class ClientsContract {
  /// Buscar todos os clientes do usuário
  Future<List<Map<String, dynamic>>> getClients();

  /// Buscar cliente por ID
  Future<Map<String, dynamic>?> getClientById(String clientId);

  /// Criar um novo cliente
  Future<Map<String, dynamic>> createClient({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String status = 'active',
    String? avatarUrl,
    String? categoryId,
  });

  /// Atualizar um cliente
  Future<Map<String, dynamic>> updateClient({
    required String clientId,
    String? name,
    String? email,
    String? phone,
    String? company,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String? status,
  });

  /// Deletar um cliente
  Future<void> deleteClient(String clientId);
}

