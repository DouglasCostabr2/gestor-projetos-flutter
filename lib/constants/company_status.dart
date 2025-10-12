/// Constantes e helpers para status de empresas
class CompanyStatus {
  // Valores válidos no banco de dados
  static const String active = 'active';
  static const String inactive = 'inactive';

  /// Lista de todos os status válidos
  static const List<String> values = [
    active,
    inactive,
  ];

  /// Obter label em português para um status
  static String getLabel(String status) {
    switch (status) {
      case active:
        return 'Ativa';
      case inactive:
        return 'Inativa';
      default:
        return status;
    }
  }

  /// Verificar se um status é válido
  static bool isValid(String status) {
    return values.contains(status);
  }
}

