/// Contrato público do módulo de empresas
/// Define as operações disponíveis para gestão de empresas
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de empresas.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class CompaniesContract {
  /// Buscar todas as empresas de um cliente
  Future<List<Map<String, dynamic>>> getCompanies(String clientId);

  /// Buscar empresa por ID
  Future<Map<String, dynamic>?> getCompanyById(String companyId);

  /// Criar uma nova empresa
  Future<Map<String, dynamic>> createCompany({
    required String clientId,
    required String name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String status = 'active',
  });

  /// Atualizar uma empresa
  Future<Map<String, dynamic>> updateCompany({
    required String companyId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    String? website,
    String? notes,
    String? status,
  });

  /// Deletar uma empresa
  Future<void> deleteCompany(String companyId);

  /// Atualizar updated_by e updated_at da empresa
  /// Usado quando um projeto é criado, duplicado ou excluído
  Future<void> touchCompany(String companyId);

  /// Buscar projetos de uma empresa com estatísticas agregadas
  /// OTIMIZAÇÃO: Usa RPC function para evitar N+1 queries
  Future<List<Map<String, dynamic>>> getCompanyProjectsWithStats(String companyId);
}

