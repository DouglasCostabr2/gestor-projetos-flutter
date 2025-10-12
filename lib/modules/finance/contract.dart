/// Contrato público do módulo financeiro
/// Define as operações disponíveis para gestão financeira
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo financeiro.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class FinanceContract {
  /// Buscar dados financeiros de um projeto
  Future<Map<String, dynamic>?> getProjectFinancials(String projectId);

  /// Atualizar dados financeiros de um projeto
  Future<void> updateProjectFinancials({
    required String projectId,
    required String currencyCode,
    required int valueCents,
  });

  /// Buscar custos adicionais de um projeto
  Future<List<Map<String, dynamic>>> getProjectAdditionalCosts(String projectId);

  /// Adicionar custo adicional a um projeto
  Future<Map<String, dynamic>> addProjectCost({
    required String projectId,
    required String description,
    required String currencyCode,
    required int amountCents,
  });

  /// Remover custo adicional de um projeto
  Future<void> removeProjectCost(String costId);

  /// Buscar itens do catálogo vinculados a um projeto
  Future<List<Map<String, dynamic>>> getProjectCatalogItems(String projectId);

  /// Calcular total de um projeto (valor + custos + catálogo)
  Future<Map<String, dynamic>> calculateProjectTotal(String projectId);

  /// Buscar pagamentos de múltiplos projetos
  Future<List<Map<String, dynamic>>> getPaymentsByProjects(List<String> projectIds);

  /// Buscar pagamentos de funcionários
  Future<List<Map<String, dynamic>>> getEmployeePayments(String employeeId);

  /// Buscar pagamentos de um projeto específico
  Future<List<Map<String, dynamic>>> getProjectPayments(String projectId);

  /// Criar pagamento
  Future<Map<String, dynamic>> createPayment({
    required String projectId,
    required int amountCents,
    required String currencyCode,
  });

  /// Criar pagamento de funcionário
  Future<Map<String, dynamic>> createEmployeePayment({
    required String employeeId,
    required String projectId,
    required int amountCents,
    required String currencyCode,
    required String description,
    String status = 'pending',
  });
}

