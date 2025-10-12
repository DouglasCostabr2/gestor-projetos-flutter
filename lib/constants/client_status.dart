/// Constantes e helpers para status de clientes
class ClientStatus {
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
        return 'Ativo';
      case inactive:
        return 'Inativo';
      default:
        return status;
    }
  }

  /// Verificar se um status é válido
  static bool isValid(String status) {
    return values.contains(status);
  }
}

