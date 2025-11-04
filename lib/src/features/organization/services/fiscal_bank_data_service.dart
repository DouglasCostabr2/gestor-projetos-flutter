import 'dart:convert';
import '../models/fiscal_bank_models.dart';

/// Service responsável por gerenciar dados fiscais e bancários da organização
///
/// Este service encapsula toda a lógica de:
/// - Cache em memória de dados não salvos
/// - Transformações entre JSONB e modelos tipados
/// - Carregamento e salvamento de dados
/// - Preservação de dados entre mudanças de país/tipo de pessoa
class FiscalBankDataService {
  // Cache dos dados fiscais em memória (preserva dados não salvos)
  String _currentCountry = '';
  String _currentPersonType = 'business';
  final Map<String, CountryFiscalData> _fiscalDataByCountry = {};
  final Map<String, BankData> _bankDataByCountry = {};
  final Map<String, PaymentPlatformData> _paymentPlatforms = {};

  /// Inicializa o cache com dados do banco de dados
  void initializeFiscalCache(String? fiscalDataJson) {
    if (fiscalDataJson == null || fiscalDataJson.isEmpty) {
      _fiscalDataByCountry.clear();
      _currentCountry = '';
      _currentPersonType = 'business';
      return;
    }

    try {
      final json = jsonDecode(fiscalDataJson) as Map<String, dynamic>;

      // Carregar país e tipo de pessoa atuais
      _currentCountry = json['current_country'] as String? ?? '';
      _currentPersonType = json['current_person_type'] as String? ?? 'business';

      // Carregar dados fiscais por país
      _fiscalDataByCountry.clear();
      for (var entry in json.entries) {
        if (entry.key == 'current_country' || entry.key == 'current_person_type') {
          continue;
        }

        if (entry.value is Map<String, dynamic>) {
          _fiscalDataByCountry[entry.key] = CountryFiscalData.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      _fiscalDataByCountry.clear();
      _currentCountry = '';
      _currentPersonType = 'business';
    }
  }

  /// Inicializa o cache de dados bancários
  void initializeBankCache(String? bankDataJson) {
    if (bankDataJson == null || bankDataJson.isEmpty) {
      _bankDataByCountry.clear();
      _paymentPlatforms.clear();
      return;
    }

    try {
      final json = jsonDecode(bankDataJson) as Map<String, dynamic>;

      // Carregar dados bancários por país
      _bankDataByCountry.clear();
      for (var entry in json.entries) {
        if (entry.key == 'payment_platforms') {
          continue;
        }

        if (entry.value is Map<String, dynamic>) {
          _bankDataByCountry[entry.key] = BankData.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      // Carregar plataformas de pagamento
      _paymentPlatforms.clear();
      final platformsJson = json['payment_platforms'] as Map<String, dynamic>?;
      if (platformsJson != null) {
        for (var entry in platformsJson.entries) {
          if (entry.value is Map<String, dynamic>) {
            _paymentPlatforms[entry.key] = PaymentPlatformData.fromJson(
              entry.key,
              entry.value as Map<String, dynamic>,
            );
          }
        }
      }
    } catch (e) {
      _bankDataByCountry.clear();
      _paymentPlatforms.clear();
    }
  }

  /// Obtém o país atual salvo
  String? getCurrentCountry() {
    return _currentCountry.isEmpty ? null : _currentCountry;
  }

  /// Obtém o tipo de pessoa atual salvo
  String getCurrentPersonType() {
    return _currentPersonType;
  }

  /// Obtém dados fiscais para um país e tipo de pessoa específicos
  FiscalData getFiscalData(String countryCode, String personType) {
    final countryData = _fiscalDataByCountry[countryCode];
    if (countryData == null) return FiscalData.empty();
    return countryData.getByPersonType(personType);
  }

  /// Salva dados fiscais para um país e tipo de pessoa específicos
  /// Preserva dados de outros tipos de pessoa no mesmo país
  void saveFiscalData(
    String countryCode,
    String personType,
    FiscalData data,
  ) {
    // Buscar dados existentes do país (preservar dados do outro tipo de pessoa)
    final countryData = _fiscalDataByCountry[countryCode] ?? CountryFiscalData.empty();

    // Atualizar apenas o tipo de pessoa atual, preservando o outro
    _fiscalDataByCountry[countryCode] = countryData.setByPersonType(personType, data);
  }

  /// Atualiza o país e tipo de pessoa atuais
  void updateCurrentSelection(String countryCode, String personType) {
    _currentCountry = countryCode;
    _currentPersonType = personType;
  }

  /// Obtém dados bancários para um país específico
  BankData getBankData(String countryCode) {
    return _bankDataByCountry[countryCode] ?? BankData.empty();
  }

  /// Salva dados bancários para um país específico
  void saveBankData(String countryCode, BankData data) {
    _bankDataByCountry[countryCode] = data;
  }

  /// Obtém todas as plataformas de pagamento
  Map<String, PaymentPlatformData> getPaymentPlatforms() {
    return Map.unmodifiable(_paymentPlatforms);
  }

  /// Obtém dados de uma plataforma de pagamento específica
  PaymentPlatformData? getPaymentPlatform(String platformId) {
    return _paymentPlatforms[platformId];
  }

  /// Salva dados de uma plataforma de pagamento específica
  void savePaymentPlatform(String platformId, bool enabled, String value) {
    _paymentPlatforms[platformId] = PaymentPlatformData(
      platformId: platformId,
      enabled: enabled,
      value: value,
    );
  }

  /// Converte o cache fiscal para JSON (para salvar no banco)
  String fiscalCacheToJson() {
    final json = <String, dynamic>{
      'current_country': _currentCountry,
      'current_person_type': _currentPersonType,
    };

    for (var entry in _fiscalDataByCountry.entries) {
      json[entry.key] = entry.value.toJson();
    }

    return jsonEncode(json);
  }

  /// Converte o cache bancário para JSON (para salvar no banco)
  String bankCacheToJson() {
    final json = <String, dynamic>{};

    // Adicionar dados bancários por país
    for (var entry in _bankDataByCountry.entries) {
      json[entry.key] = entry.value.toJson();
    }

    // Adicionar plataformas de pagamento
    if (_paymentPlatforms.isNotEmpty) {
      final platformsJson = <String, dynamic>{};
      for (var entry in _paymentPlatforms.entries) {
        platformsJson[entry.key] = entry.value.toJson();
      }
      json['payment_platforms'] = platformsJson;
    }

    return jsonEncode(json);
  }

  /// Limpa todos os caches (útil para testes ou logout)
  void clearCaches() {
    _currentCountry = '';
    _currentPersonType = 'business';
    _fiscalDataByCountry.clear();
    _bankDataByCountry.clear();
    _paymentPlatforms.clear();
  }

  /// Verifica se há dados fiscais para um país e tipo de pessoa
  bool hasFiscalData(String countryCode, String personType) {
    final data = getFiscalData(countryCode, personType);
    return data.isNotEmpty;
  }

  /// Verifica se há dados bancários para um país
  bool hasBankData(String countryCode) {
    final data = getBankData(countryCode);
    return data.isNotEmpty;
  }

  /// Obtém todos os países com dados fiscais salvos
  List<String> getCountriesWithFiscalData() {
    return _fiscalDataByCountry.keys.toList();
  }

  /// Obtém todos os países com dados bancários salvos
  List<String> getCountriesWithBankData() {
    return _bankDataByCountry.keys.toList();
  }
}

