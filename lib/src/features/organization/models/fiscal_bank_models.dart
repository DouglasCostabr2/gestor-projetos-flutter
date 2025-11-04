/// Modelo para dados de uma plataforma de pagamento
class PaymentPlatformData {
  final String platformId;
  final bool enabled;
  final String value;

  const PaymentPlatformData({
    required this.platformId,
    required this.enabled,
    required this.value,
  });

  factory PaymentPlatformData.fromJson(String platformId, Map<String, dynamic> json) {
    return PaymentPlatformData(
      platformId: platformId,
      enabled: json['enabled'] as bool? ?? false,
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'value': value,
    };
  }

  PaymentPlatformData copyWith({
    String? platformId,
    bool? enabled,
    String? value,
  }) {
    return PaymentPlatformData(
      platformId: platformId ?? this.platformId,
      enabled: enabled ?? this.enabled,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentPlatformData &&
          runtimeType == other.runtimeType &&
          platformId == other.platformId &&
          enabled == other.enabled &&
          value == other.value;

  @override
  int get hashCode => platformId.hashCode ^ enabled.hashCode ^ value.hashCode;
}

/// Modelo para dados fiscais (individual ou business)
class FiscalData {
  final Map<String, String> fields;

  const FiscalData({
    required this.fields,
  });

  factory FiscalData.empty() {
    return const FiscalData(fields: {});
  }

  factory FiscalData.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return FiscalData.empty();
    }

    final fields = <String, String>{};
    for (var entry in json.entries) {
      fields[entry.key] = entry.value?.toString() ?? '';
    }

    return FiscalData(fields: fields);
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(fields);
  }

  String? getField(String fieldId) => fields[fieldId];

  FiscalData setField(String fieldId, String value) {
    final newFields = Map<String, String>.from(fields);
    if (value.isEmpty) {
      newFields.remove(fieldId);
    } else {
      newFields[fieldId] = value;
    }
    return FiscalData(fields: newFields);
  }

  FiscalData setFields(Map<String, String> newFields) {
    final updatedFields = Map<String, String>.from(fields);
    for (var entry in newFields.entries) {
      if (entry.value.isEmpty) {
        updatedFields.remove(entry.key);
      } else {
        updatedFields[entry.key] = entry.value;
      }
    }
    return FiscalData(fields: updatedFields);
  }

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiscalData &&
          runtimeType == other.runtimeType &&
          _mapEquals(fields, other.fields);

  @override
  int get hashCode => fields.hashCode;

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Modelo para dados bancários
class BankData {
  final Map<String, String> fields;

  const BankData({
    required this.fields,
  });

  factory BankData.empty() {
    return const BankData(fields: {});
  }

  factory BankData.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return BankData.empty();
    }

    final fields = <String, String>{};
    for (var entry in json.entries) {
      fields[entry.key] = entry.value?.toString() ?? '';
    }

    return BankData(fields: fields);
  }

  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(fields);
  }

  String? getField(String fieldId) => fields[fieldId];

  BankData setField(String fieldId, String value) {
    final newFields = Map<String, String>.from(fields);
    if (value.isEmpty) {
      newFields.remove(fieldId);
    } else {
      newFields[fieldId] = value;
    }
    return BankData(fields: newFields);
  }

  BankData setFields(Map<String, String> newFields) {
    final updatedFields = Map<String, String>.from(fields);
    for (var entry in newFields.entries) {
      if (entry.value.isEmpty) {
        updatedFields.remove(entry.key);
      } else {
        updatedFields[entry.key] = entry.value;
      }
    }
    return BankData(fields: updatedFields);
  }

  bool get isEmpty => fields.isEmpty;
  bool get isNotEmpty => fields.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankData &&
          runtimeType == other.runtimeType &&
          _mapEquals(fields, other.fields);

  @override
  int get hashCode => fields.hashCode;

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Modelo para dados fiscais de um país (individual + business)
class CountryFiscalData {
  final FiscalData individual;
  final FiscalData business;

  const CountryFiscalData({
    required this.individual,
    required this.business,
  });

  factory CountryFiscalData.empty() {
    return CountryFiscalData(
      individual: FiscalData.empty(),
      business: FiscalData.empty(),
    );
  }

  factory CountryFiscalData.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return CountryFiscalData.empty();
    }

    return CountryFiscalData(
      individual: FiscalData.fromJson(json['individual'] as Map<String, dynamic>?),
      business: FiscalData.fromJson(json['business'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'individual': individual.toJson(),
      'business': business.toJson(),
    };
  }

  FiscalData getByPersonType(String personType) {
    return personType == 'individual' ? individual : business;
  }

  CountryFiscalData setByPersonType(String personType, FiscalData data) {
    if (personType == 'individual') {
      return CountryFiscalData(individual: data, business: business);
    } else {
      return CountryFiscalData(individual: individual, business: data);
    }
  }
}

/// Modelo completo para todos os dados fiscais e bancários
class FiscalBankFullData {
  final String currentCountry;
  final String currentPersonType;
  final Map<String, CountryFiscalData> fiscalDataByCountry;
  final Map<String, BankData> bankDataByCountry;
  final Map<String, PaymentPlatformData> paymentPlatforms;

  const FiscalBankFullData({
    required this.currentCountry,
    required this.currentPersonType,
    required this.fiscalDataByCountry,
    required this.bankDataByCountry,
    required this.paymentPlatforms,
  });

  factory FiscalBankFullData.empty() {
    return const FiscalBankFullData(
      currentCountry: '',
      currentPersonType: 'individual',
      fiscalDataByCountry: {},
      bankDataByCountry: {},
      paymentPlatforms: {},
    );
  }

  FiscalData getCurrentFiscalData() {
    if (currentCountry.isEmpty) return FiscalData.empty();
    final countryData = fiscalDataByCountry[currentCountry];
    if (countryData == null) return FiscalData.empty();
    return countryData.getByPersonType(currentPersonType);
  }

  BankData getCurrentBankData() {
    if (currentCountry.isEmpty) return BankData.empty();
    return bankDataByCountry[currentCountry] ?? BankData.empty();
  }

  FiscalBankFullData setCurrentCountry(String country) {
    return FiscalBankFullData(
      currentCountry: country,
      currentPersonType: currentPersonType,
      fiscalDataByCountry: fiscalDataByCountry,
      bankDataByCountry: bankDataByCountry,
      paymentPlatforms: paymentPlatforms,
    );
  }

  FiscalBankFullData setCurrentPersonType(String personType) {
    return FiscalBankFullData(
      currentCountry: currentCountry,
      currentPersonType: personType,
      fiscalDataByCountry: fiscalDataByCountry,
      bankDataByCountry: bankDataByCountry,
      paymentPlatforms: paymentPlatforms,
    );
  }
}

