/// Constantes e helpers para status de clientes
class ClientStatus {
  // Valores válidos no banco de dados (status de prospecção)
  static const String naoProspectado = 'nao_prospectado';
  static const String emProspeccao = 'em_prospeccao';
  static const String prospeccaoNegada = 'prospeccao_negada';
  static const String neutro = 'neutro';
  static const String ativo = 'ativo';
  static const String desativado = 'desativado';

  /// Lista de todos os status válidos
  static const List<String> values = [
    naoProspectado,
    emProspeccao,
    prospeccaoNegada,
    neutro,
    ativo,
    desativado,
  ];

  /// Obter label em português para um status
  static String getLabel(String status) {
    switch (status) {
      case naoProspectado:
        return 'Não Prospectado';
      case emProspeccao:
        return 'Em Prospecção';
      case prospeccaoNegada:
        return 'Prospecção Negada';
      case neutro:
        return 'Neutro';
      case ativo:
        return 'Ativo';
      case desativado:
        return 'Desativado';
      default:
        return status;
    }
  }

  /// Verificar se um status é válido
  static bool isValid(String status) {
    return values.contains(status);
  }
}

