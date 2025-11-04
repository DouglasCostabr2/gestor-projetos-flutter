/// Configuração de campos fiscais e bancários por país
class CountryFiscalConfig {
  final String countryCode;
  final String countryName;
  final List<FiscalField> fiscalFieldsIndividual; // Pessoa Física
  final List<FiscalField> fiscalFieldsBusiness;   // Pessoa Jurídica
  final List<BankField> bankFields;

  const CountryFiscalConfig({
    required this.countryCode,
    required this.countryName,
    required this.fiscalFieldsIndividual,
    required this.fiscalFieldsBusiness,
    required this.bankFields,
  });

  /// Retorna os campos fiscais apropriados para o tipo de pessoa
  List<FiscalField> getFiscalFields(String personType) {
    return personType == 'individual' ? fiscalFieldsIndividual : fiscalFieldsBusiness;
  }
}

/// Campo fiscal (documento de identificação tributária)
class FiscalField {
  final String id;
  final String label;
  final String hint;
  final String? mask;
  final bool required;
  final String? Function(String?)? validator;

  const FiscalField({
    required this.id,
    required this.label,
    required this.hint,
    this.mask,
    this.required = false,
    this.validator,
  });
}

/// Campo bancário
class BankField {
  final String id;
  final String label;
  final String hint;
  final String? mask;
  final bool required;
  final String? Function(String?)? validator;

  const BankField({
    required this.id,
    required this.label,
    required this.hint,
    this.mask,
    this.required = false,
    this.validator,
  });
}

/// Repositório de configurações fiscais por país
class CountryFiscalRepository {
  /// Helper para criar configuração simples com campos genéricos
  static CountryFiscalConfig _simpleConfig(
    String code,
    String name,
    String individualTaxLabel,
    String businessTaxLabel,
  ) {
    return CountryFiscalConfig(
      countryCode: code,
      countryName: name,
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'tax_id_individual',
          label: individualTaxLabel,
          hint: 'Individual tax identification',
          required: true,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'tax_id_business',
          label: businessTaxLabel,
          hint: 'Business tax identification',
          required: true,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Bank Name',
          hint: 'Name of your bank',
          required: true,
        ),
        BankField(
          id: 'account_number',
          label: 'Account Number',
          hint: 'Bank account number',
          required: true,
        ),
      ],
    );
  }

  static final Map<String, CountryFiscalConfig> _configs = {
    // Brasil
    'BR': CountryFiscalConfig(
      countryCode: 'BR',
      countryName: 'Brasil',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'cpf',
          label: 'CPF',
          hint: 'Ex: 123.456.789-00',
          required: true,
        ),
        FiscalField(
          id: 'rg',
          label: 'RG',
          hint: 'Ex: 12.345.678-9',
          required: false,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'cnpj',
          label: 'CNPJ',
          hint: 'Ex: 12.345.678/0001-90',
          required: true,
        ),
        FiscalField(
          id: 'state_registration',
          label: 'Inscrição Estadual',
          hint: 'Ex: 123.456.789.012',
          required: false,
        ),
        FiscalField(
          id: 'municipal_registration',
          label: 'Inscrição Municipal',
          hint: 'Ex: 12345678',
          required: false,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Nome do Banco',
          hint: 'Ex: Banco do Brasil, Itaú, Bradesco',
          required: true,
        ),
        BankField(
          id: 'bank_code',
          label: 'Código do Banco',
          hint: 'Ex: 001, 341, 237',
          required: true,
        ),
        BankField(
          id: 'agency',
          label: 'Agência',
          hint: 'Ex: 1234-5',
          required: true,
        ),
        BankField(
          id: 'account',
          label: 'Conta',
          hint: 'Ex: 12345-6',
          required: true,
        ),
        BankField(
          id: 'account_type',
          label: 'Tipo de Conta',
          hint: 'Corrente ou Poupança',
          required: false,
        ),
        BankField(
          id: 'pix_key',
          label: 'Chave PIX',
          hint: 'CPF, Email, Telefone ou Aleatória',
          required: false,
        ),
      ],
    ),

    // Estados Unidos
    'US': CountryFiscalConfig(
      countryCode: 'US',
      countryName: 'United States',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'ssn',
          label: 'SSN (Social Security Number)',
          hint: 'Ex: 123-45-6789',
          required: true,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'ein',
          label: 'EIN (Employer Identification Number)',
          hint: 'Ex: 12-3456789',
          required: true,
        ),
        FiscalField(
          id: 'state_tax_id',
          label: 'State Tax ID',
          hint: 'State-specific tax identification',
          required: false,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Bank Name',
          hint: 'Ex: Chase, Bank of America, Wells Fargo',
          required: true,
        ),
        BankField(
          id: 'routing_number',
          label: 'Routing Number',
          hint: 'Ex: 123456789 (9 digits)',
          required: true,
        ),
        BankField(
          id: 'account_number',
          label: 'Account Number',
          hint: 'Your bank account number',
          required: true,
        ),
        BankField(
          id: 'account_type',
          label: 'Account Type',
          hint: 'Checking or Savings',
          required: false,
        ),
        BankField(
          id: 'swift',
          label: 'SWIFT/BIC Code',
          hint: 'For international transfers',
          required: false,
        ),
      ],
    ),

    // Reino Unido
    'GB': CountryFiscalConfig(
      countryCode: 'GB',
      countryName: 'United Kingdom',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'nino',
          label: 'National Insurance Number',
          hint: 'Ex: QQ123456C',
          required: true,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'vat',
          label: 'VAT Number',
          hint: 'Ex: GB123456789',
          required: true,
        ),
        FiscalField(
          id: 'company_number',
          label: 'Company Registration Number',
          hint: 'Ex: 12345678',
          required: false,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Bank Name',
          hint: 'Ex: Barclays, HSBC, Lloyds',
          required: true,
        ),
        BankField(
          id: 'sort_code',
          label: 'Sort Code',
          hint: 'Ex: 12-34-56',
          required: true,
        ),
        BankField(
          id: 'account_number',
          label: 'Account Number',
          hint: 'Ex: 12345678',
          required: true,
        ),
        BankField(
          id: 'iban',
          label: 'IBAN',
          hint: 'Ex: GB82WEST12345698765432',
          required: false,
        ),
        BankField(
          id: 'swift',
          label: 'SWIFT/BIC Code',
          hint: 'Ex: BARCGB22',
          required: false,
        ),
      ],
    ),

    // Portugal
    'PT': CountryFiscalConfig(
      countryCode: 'PT',
      countryName: 'Portugal',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'nif',
          label: 'NIF (Número de Identificação Fiscal)',
          hint: 'Ex: 123456789',
          required: true,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'nipc',
          label: 'NIPC (Número de Identificação de Pessoa Coletiva)',
          hint: 'Ex: 501234567',
          required: true,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Nome do Banco',
          hint: 'Ex: CGD, Millennium BCP, Santander',
          required: true,
        ),
        BankField(
          id: 'iban',
          label: 'IBAN',
          hint: 'Ex: PT50000201231234567890154',
          required: true,
        ),
        BankField(
          id: 'swift',
          label: 'SWIFT/BIC',
          hint: 'Ex: CGDIPTPL',
          required: false,
        ),
      ],
    ),

    // Espanha
    'ES': CountryFiscalConfig(
      countryCode: 'ES',
      countryName: 'España',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'nif',
          label: 'NIF (Número de Identificación Fiscal)',
          hint: 'Ex: 12345678Z',
          required: true,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'cif',
          label: 'CIF (Código de Identificación Fiscal)',
          hint: 'Ex: A12345678',
          required: true,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Nombre del Banco',
          hint: 'Ex: BBVA, Santander, CaixaBank',
          required: true,
        ),
        BankField(
          id: 'iban',
          label: 'IBAN',
          hint: 'Ex: ES9121000418450200051332',
          required: true,
        ),
        BankField(
          id: 'swift',
          label: 'SWIFT/BIC',
          hint: 'Ex: BBVAESMM',
          required: false,
        ),
      ],
    ),

    // México
    'MX': CountryFiscalConfig(
      countryCode: 'MX',
      countryName: 'México',
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'rfc_individual',
          label: 'RFC (Persona Física)',
          hint: 'Ex: ABCD123456XYZ',
          required: true,
        ),
        FiscalField(
          id: 'curp',
          label: 'CURP',
          hint: 'Ex: ABCD123456HDFRRL09',
          required: false,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'rfc',
          label: 'RFC (Persona Moral)',
          hint: 'Ex: ABC123456XYZ',
          required: true,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Nombre del Banco',
          hint: 'Ex: BBVA México, Santander, Banorte',
          required: true,
        ),
        BankField(
          id: 'clabe',
          label: 'CLABE',
          hint: 'Ex: 012345678901234567 (18 dígitos)',
          required: true,
        ),
        BankField(
          id: 'account_number',
          label: 'Número de Cuenta',
          hint: 'Número de cuenta bancaria',
          required: false,
        ),
      ],
    ),

    // Demais países com configuração simplificada
    'CA': _simpleConfig('CA', 'Canada', 'SIN (Social Insurance Number)', 'Business Number (BN)'),
    'DE': _simpleConfig('DE', 'Deutschland', 'Steuer-ID', 'USt-IdNr. (VAT)'),
    'FR': _simpleConfig('FR', 'France', 'Numéro Fiscal', 'SIRET'),
    'IT': _simpleConfig('IT', 'Italia', 'Codice Fiscale', 'Partita IVA'),
    'AU': _simpleConfig('AU', 'Australia', 'TFN (Tax File Number)', 'ABN (Australian Business Number)'),
    'AR': _simpleConfig('AR', 'Argentina', 'CUIL', 'CUIT'),
    'JP': _simpleConfig('JP', '日本 (Japan)', 'My Number', '法人番号 (Corporate Number)'),
    'CN': _simpleConfig('CN', '中国 (China)', '身份证 (ID Card)', '统一社会信用代码 (USCC)'),
    'IN': _simpleConfig('IN', 'India', 'PAN', 'GSTIN'),
  };

  /// Configuração genérica para países não listados
  static CountryFiscalConfig getGenericConfig(String countryCode, String countryName) {
    return CountryFiscalConfig(
      countryCode: countryCode,
      countryName: countryName,
      fiscalFieldsIndividual: [
        FiscalField(
          id: 'tax_id_individual',
          label: 'Personal Tax ID',
          hint: 'Individual tax identification number',
          required: true,
        ),
        FiscalField(
          id: 'national_id',
          label: 'National ID',
          hint: 'National identification document',
          required: false,
        ),
      ],
      fiscalFieldsBusiness: [
        FiscalField(
          id: 'tax_id',
          label: 'Tax Identification Number',
          hint: 'Company tax identification number',
          required: true,
        ),
        FiscalField(
          id: 'registration_number',
          label: 'Business Registration Number',
          hint: 'Company registration number',
          required: false,
        ),
      ],
      bankFields: [
        BankField(
          id: 'bank_name',
          label: 'Bank Name',
          hint: 'Name of your bank',
          required: true,
        ),
        BankField(
          id: 'account_number',
          label: 'Account Number',
          hint: 'Bank account number',
          required: true,
        ),
        BankField(
          id: 'iban',
          label: 'IBAN',
          hint: 'International Bank Account Number',
          required: false,
        ),
        BankField(
          id: 'swift',
          label: 'SWIFT/BIC Code',
          hint: 'For international transfers',
          required: false,
        ),
        BankField(
          id: 'routing_code',
          label: 'Routing/Sort Code',
          hint: 'Bank routing or sort code',
          required: false,
        ),
      ],
    );
  }

  static CountryFiscalConfig getConfig(String countryCode, String countryName) {
    return _configs[countryCode] ?? getGenericConfig(countryCode, countryName);
  }

  static List<String> getSupportedCountries() {
    return _configs.keys.toList();
  }

  static bool isSupported(String countryCode) {
    return _configs.containsKey(countryCode);
  }
}

