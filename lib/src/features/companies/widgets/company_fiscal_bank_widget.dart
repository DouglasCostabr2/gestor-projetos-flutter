import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../modules/modules.dart';
import '../../../features/organization/models/country_fiscal_config.dart';
import '../../../features/organization/models/fiscal_bank_models.dart';
import '../../../features/organization/services/fiscal_bank_data_service.dart';
import '../../../features/organization/utils/form_controller_manager.dart';
import '../../../features/organization/widgets/widgets.dart';

/// Widget para gerenciar dados fiscais e bancários de uma empresa
/// Similar ao FiscalAndBankPage mas adaptado para empresas
class CompanyFiscalBankWidget extends StatefulWidget {
  final String companyId;
  final Map<String, dynamic>? initialFiscalData;
  final Map<String, dynamic>? initialBankData;
  final String? initialFiscalCountry;
  final bool showSaveButton; // Se true, mostra botão "Salvar Dados Fiscais e Bancários"

  const CompanyFiscalBankWidget({
    super.key,
    required this.companyId,
    this.initialFiscalData,
    this.initialBankData,
    this.initialFiscalCountry,
    this.showSaveButton = true, // Por padrão, mostra o botão
  });

  @override
  State<CompanyFiscalBankWidget> createState() => CompanyFiscalBankWidgetState();
}

class CompanyFiscalBankWidgetState extends State<CompanyFiscalBankWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Service para gerenciar dados fiscais e bancários
  final _dataService = FiscalBankDataService();

  // Gerenciadores de controllers
  final _fiscalControllerManager = FormControllerManager();
  final _bankControllerManager = FormControllerManager();
  final _paymentPlatformControllerManager = FormControllerManager();

  String? _selectedCountryCode;
  String? _selectedCountryName;
  CountryFiscalConfig? _countryConfig;

  // Tipo de pessoa: 'individual' (Pessoa Física) ou 'business' (Pessoa Jurídica)
  String _personType = 'business';

  final Map<String, bool> _paymentPlatformEnabled = {};

  // Lista de plataformas de pagamento suportadas
  static final List<Map<String, String>> _paymentPlatforms = [
    {'id': 'paypal', 'label': 'PayPal', 'hint': 'Ex: seu-email@paypal.com'},
    {'id': 'stripe', 'label': 'Stripe', 'hint': 'Ex: acct_1234567890'},
    {'id': 'mercado_pago', 'label': 'Mercado Pago', 'hint': 'Ex: seu-email@mercadopago.com'},
    {'id': 'payoneer', 'label': 'Payoneer', 'hint': 'Ex: seu-email@payoneer.com'},
    {'id': 'wise', 'label': 'Wise (TransferWise)', 'hint': 'Ex: seu-email@wise.com'},
    {'id': 'other_platform', 'label': 'Outras Plataformas', 'hint': 'Ex: Venmo, Cash App, etc.'},
  ];

  // Lista completa de todos os países do mundo (195 países reconhecidos pela ONU)
  static final List<Map<String, String>> _countries = [
    {'code': 'AF', 'name': 'Afeganistão'},
    {'code': 'ZA', 'name': 'África do Sul'},
    {'code': 'AL', 'name': 'Albânia'},
    {'code': 'DE', 'name': 'Alemanha'},
    {'code': 'AD', 'name': 'Andorra'},
    {'code': 'AO', 'name': 'Angola'},
    {'code': 'AG', 'name': 'Antígua e Barbuda'},
    {'code': 'SA', 'name': 'Arábia Saudita'},
    {'code': 'DZ', 'name': 'Argélia'},
    {'code': 'AR', 'name': 'Argentina'},
    {'code': 'AM', 'name': 'Armênia'},
    {'code': 'AU', 'name': 'Austrália'},
    {'code': 'AT', 'name': 'Áustria'},
    {'code': 'AZ', 'name': 'Azerbaijão'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'BB', 'name': 'Barbados'},
    {'code': 'BH', 'name': 'Bahrein'},
    {'code': 'BE', 'name': 'Bélgica'},
    {'code': 'BZ', 'name': 'Belize'},
    {'code': 'BJ', 'name': 'Benin'},
    {'code': 'BY', 'name': 'Bielorrússia'},
    {'code': 'BO', 'name': 'Bolívia'},
    {'code': 'BA', 'name': 'Bósnia e Herzegovina'},
    {'code': 'BW', 'name': 'Botsuana'},
    {'code': 'BR', 'name': 'Brasil'},
    {'code': 'BN', 'name': 'Brunei'},
    {'code': 'BG', 'name': 'Bulgária'},
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'BI', 'name': 'Burundi'},
    {'code': 'BT', 'name': 'Butão'},
    {'code': 'CV', 'name': 'Cabo Verde'},
    {'code': 'CM', 'name': 'Camarões'},
    {'code': 'KH', 'name': 'Camboja'},
    {'code': 'CA', 'name': 'Canadá'},
    {'code': 'QA', 'name': 'Catar'},
    {'code': 'KZ', 'name': 'Cazaquistão'},
    {'code': 'TD', 'name': 'Chade'},
    {'code': 'CL', 'name': 'Chile'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'CY', 'name': 'Chipre'},
    {'code': 'CO', 'name': 'Colômbia'},
    {'code': 'KM', 'name': 'Comores'},
    {'code': 'CG', 'name': 'Congo'},
    {'code': 'KP', 'name': 'Coreia do Norte'},
    {'code': 'KR', 'name': 'Coreia do Sul'},
    {'code': 'CI', 'name': 'Costa do Marfim'},
    {'code': 'CR', 'name': 'Costa Rica'},
    {'code': 'HR', 'name': 'Croácia'},
    {'code': 'CU', 'name': 'Cuba'},
    {'code': 'DK', 'name': 'Dinamarca'},
    {'code': 'DJ', 'name': 'Djibuti'},
    {'code': 'DM', 'name': 'Dominica'},
    {'code': 'EG', 'name': 'Egito'},
    {'code': 'SV', 'name': 'El Salvador'},
    {'code': 'AE', 'name': 'Emirados Árabes Unidos'},
    {'code': 'EC', 'name': 'Equador'},
    {'code': 'ER', 'name': 'Eritreia'},
    {'code': 'SK', 'name': 'Eslováquia'},
    {'code': 'SI', 'name': 'Eslovênia'},
    {'code': 'ES', 'name': 'Espanha'},
    {'code': 'US', 'name': 'Estados Unidos'},
    {'code': 'EE', 'name': 'Estônia'},
    {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'ET', 'name': 'Etiópia'},
    {'code': 'FJ', 'name': 'Fiji'},
    {'code': 'PH', 'name': 'Filipinas'},
    {'code': 'FI', 'name': 'Finlândia'},
    {'code': 'FR', 'name': 'França'},
    {'code': 'GA', 'name': 'Gabão'},
    {'code': 'GM', 'name': 'Gâmbia'},
    {'code': 'GH', 'name': 'Gana'},
    {'code': 'GE', 'name': 'Geórgia'},
    {'code': 'GD', 'name': 'Granada'},
    {'code': 'GR', 'name': 'Grécia'},
    {'code': 'GT', 'name': 'Guatemala'},
    {'code': 'GY', 'name': 'Guiana'},
    {'code': 'GN', 'name': 'Guiné'},
    {'code': 'GQ', 'name': 'Guiné Equatorial'},
    {'code': 'GW', 'name': 'Guiné-Bissau'},
    {'code': 'HT', 'name': 'Haiti'},
    {'code': 'HN', 'name': 'Honduras'},
    {'code': 'HU', 'name': 'Hungria'},
    {'code': 'YE', 'name': 'Iêmen'},
    {'code': 'MH', 'name': 'Ilhas Marshall'},
    {'code': 'SB', 'name': 'Ilhas Salomão'},
    {'code': 'IN', 'name': 'Índia'},
    {'code': 'ID', 'name': 'Indonésia'},
    {'code': 'IQ', 'name': 'Iraque'},
    {'code': 'IR', 'name': 'Irã'},
    {'code': 'IE', 'name': 'Irlanda'},
    {'code': 'IS', 'name': 'Islândia'},
    {'code': 'IL', 'name': 'Israel'},
    {'code': 'IT', 'name': 'Itália'},
    {'code': 'JM', 'name': 'Jamaica'},
    {'code': 'JP', 'name': 'Japão'},
    {'code': 'JO', 'name': 'Jordânia'},
    {'code': 'KI', 'name': 'Kiribati'},
    {'code': 'KW', 'name': 'Kuwait'},
    {'code': 'LA', 'name': 'Laos'},
    {'code': 'LS', 'name': 'Lesoto'},
    {'code': 'LV', 'name': 'Letônia'},
    {'code': 'LB', 'name': 'Líbano'},
    {'code': 'LR', 'name': 'Libéria'},
    {'code': 'LY', 'name': 'Líbia'},
    {'code': 'LI', 'name': 'Liechtenstein'},
    {'code': 'LT', 'name': 'Lituânia'},
    {'code': 'LU', 'name': 'Luxemburgo'},
    {'code': 'MK', 'name': 'Macedônia do Norte'},
    {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MY', 'name': 'Malásia'},
    {'code': 'MW', 'name': 'Malawi'},
    {'code': 'MV', 'name': 'Maldivas'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'MT', 'name': 'Malta'},
    {'code': 'MA', 'name': 'Marrocos'},
    {'code': 'MU', 'name': 'Maurício'},
    {'code': 'MR', 'name': 'Mauritânia'},
    {'code': 'MX', 'name': 'México'},
    {'code': 'MM', 'name': 'Mianmar'},
    {'code': 'FM', 'name': 'Micronésia'},
    {'code': 'MZ', 'name': 'Moçambique'},
    {'code': 'MD', 'name': 'Moldávia'},
    {'code': 'MC', 'name': 'Mônaco'},
    {'code': 'MN', 'name': 'Mongólia'},
    {'code': 'ME', 'name': 'Montenegro'},
    {'code': 'NA', 'name': 'Namíbia'},
    {'code': 'NR', 'name': 'Nauru'},
    {'code': 'NP', 'name': 'Nepal'},
    {'code': 'NI', 'name': 'Nicarágua'},
    {'code': 'NE', 'name': 'Níger'},
    {'code': 'NG', 'name': 'Nigéria'},
    {'code': 'NO', 'name': 'Noruega'},
    {'code': 'NZ', 'name': 'Nova Zelândia'},
    {'code': 'OM', 'name': 'Omã'},
    {'code': 'NL', 'name': 'Países Baixos'},
    {'code': 'PW', 'name': 'Palau'},
    {'code': 'PA', 'name': 'Panamá'},
    {'code': 'PG', 'name': 'Papua-Nova Guiné'},
    {'code': 'PK', 'name': 'Paquistão'},
    {'code': 'PY', 'name': 'Paraguai'},
    {'code': 'PE', 'name': 'Peru'},
    {'code': 'PL', 'name': 'Polônia'},
    {'code': 'PT', 'name': 'Portugal'},
    {'code': 'KE', 'name': 'Quênia'},
    {'code': 'KG', 'name': 'Quirguistão'},
    {'code': 'GB', 'name': 'Reino Unido'},
    {'code': 'CF', 'name': 'República Centro-Africana'},
    {'code': 'CD', 'name': 'República Democrática do Congo'},
    {'code': 'DO', 'name': 'República Dominicana'},
    {'code': 'CZ', 'name': 'República Tcheca'},
    {'code': 'RO', 'name': 'Romênia'},
    {'code': 'RW', 'name': 'Ruanda'},
    {'code': 'RU', 'name': 'Rússia'},
    {'code': 'WS', 'name': 'Samoa'},
    {'code': 'SM', 'name': 'San Marino'},
    {'code': 'LC', 'name': 'Santa Lúcia'},
    {'code': 'KN', 'name': 'São Cristóvão e Nevis'},
    {'code': 'ST', 'name': 'São Tomé e Príncipe'},
    {'code': 'VC', 'name': 'São Vicente e Granadinas'},
    {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'SN', 'name': 'Senegal'},
    {'code': 'SL', 'name': 'Serra Leoa'},
    {'code': 'RS', 'name': 'Sérvia'},
    {'code': 'SG', 'name': 'Singapura'},
    {'code': 'SY', 'name': 'Síria'},
    {'code': 'SO', 'name': 'Somália'},
    {'code': 'LK', 'name': 'Sri Lanka'},
    {'code': 'SD', 'name': 'Sudão'},
    {'code': 'SS', 'name': 'Sudão do Sul'},
    {'code': 'SE', 'name': 'Suécia'},
    {'code': 'CH', 'name': 'Suíça'},
    {'code': 'SR', 'name': 'Suriname'},
    {'code': 'TJ', 'name': 'Tadjiquistão'},
    {'code': 'TH', 'name': 'Tailândia'},
    {'code': 'TZ', 'name': 'Tanzânia'},
    {'code': 'TL', 'name': 'Timor-Leste'},
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'TO', 'name': 'Tonga'},
    {'code': 'TT', 'name': 'Trinidad e Tobago'},
    {'code': 'TN', 'name': 'Tunísia'},
    {'code': 'TM', 'name': 'Turcomenistão'},
    {'code': 'TR', 'name': 'Turquia'},
    {'code': 'TV', 'name': 'Tuvalu'},
    {'code': 'UA', 'name': 'Ucrânia'},
    {'code': 'UG', 'name': 'Uganda'},
    {'code': 'UY', 'name': 'Uruguai'},
    {'code': 'UZ', 'name': 'Uzbequistão'},
    {'code': 'VU', 'name': 'Vanuatu'},
    {'code': 'VA', 'name': 'Vaticano'},
    {'code': 'VE', 'name': 'Venezuela'},
    {'code': 'VN', 'name': 'Vietnã'},
    {'code': 'ZM', 'name': 'Zâmbia'},
    {'code': 'ZW', 'name': 'Zimbábue'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fiscalControllerManager.disposeAll();
    _bankControllerManager.disposeAll();
    _paymentPlatformControllerManager.disposeAll();
    super.dispose();
  }

  /// Método público para salvar dados fiscais/bancários
  /// Retorna true se salvou com sucesso, false caso contrário
  Future<bool> saveFiscalBankData() async {
    try {
      await _save();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // Carregar estrutura hierárquica de dados fiscais
      final fiscalData = widget.initialFiscalData;
      String? fiscalDataStr;

      if (fiscalData != null) {
        fiscalDataStr = jsonEncode(fiscalData);
      }

      if (fiscalDataStr != null && fiscalDataStr.isNotEmpty) {
        // Inicializar o cache do service com os dados do banco
        _dataService.initializeFiscalCache(fiscalDataStr);

        // Carregar país e tipo de pessoa atuais
        _selectedCountryCode = _dataService.getCurrentCountry();
        _personType = _dataService.getCurrentPersonType();
      } else {
        _dataService.initializeFiscalCache(null);
      }

      // Configurar país inicial se houver
      if (_selectedCountryCode != null && _selectedCountryCode!.isNotEmpty) {
        final countryData = _countries.firstWhere(
          (c) => c['code'] == _selectedCountryCode,
          orElse: () => {'code': _selectedCountryCode!, 'name': _selectedCountryCode!},
        );
        _selectedCountryName = countryData['name'];

        _countryConfig = CountryFiscalRepository.getConfig(
          _selectedCountryCode!,
          _selectedCountryName ?? _selectedCountryCode!,
        );

        if (_countryConfig != null) {
          final fields = _countryConfig!.getFiscalFields(_personType);

          // Buscar dados específicos do país e tipo de pessoa atual usando o service
          final personTypeData = _dataService.getFiscalData(_selectedCountryCode!, _personType);

          // Criar controllers usando o manager
          _fiscalControllerManager.recreateControllersFromFields(
            fields,
            (field) => field.id,
            initialValues: personTypeData.fields,
          );
        }
      } else {
        // Inicializar vazio se não houver país selecionado
        _selectedCountryCode = null;
        _selectedCountryName = null;
        _countryConfig = null;
      }

      // Carregar estrutura hierárquica de dados bancários
      final bankData = widget.initialBankData;
      String? bankDataStr;

      if (bankData != null) {
        bankDataStr = jsonEncode(bankData);
      }

      // Inicializar cache bancário no service
      _dataService.initializeBankCache(bankDataStr);

      if (_countryConfig != null && _selectedCountryCode != null) {
        // Buscar dados bancários específicos do país atual usando o service
        final countryBankData = _dataService.getBankData(_selectedCountryCode!);

        // Criar controllers bancários usando o manager
        _bankControllerManager.recreateControllersFromFields(
          _countryConfig!.bankFields,
          (field) => field.id,
          initialValues: countryBankData.fields,
        );

        // Carregar plataformas de pagamento
        final platformIds = _paymentPlatforms.map((p) => p['id']!).toList();
        final platformValues = <String, String>{};

        for (var platformId in platformIds) {
          final platformData = _dataService.getPaymentPlatform(platformId);
          if (platformData != null) {
            platformValues[platformId] = platformData.value;
            _paymentPlatformEnabled[platformId] = platformData.enabled;
          } else {
            platformValues[platformId] = '';
            _paymentPlatformEnabled[platformId] = false;
          }
        }

        _paymentPlatformControllerManager.recreateControllers(
          platformIds,
          initialValues: platformValues,
        );
      } else {
        // Inicializar controllers de plataformas de pagamento se não houver país
        final platformIds = _paymentPlatforms.map((p) => p['id']!).toList();
        _paymentPlatformControllerManager.createControllers(platformIds);
        for (var platformId in platformIds) {
          _paymentPlatformEnabled[platformId] = false;
        }
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onCountrySelected(String? countryCode) {
    if (countryCode == null) return;

    setState(() {
      _selectedCountryCode = countryCode;
      final countryData = _countries.firstWhere(
        (c) => c['code'] == countryCode,
        orElse: () => {'code': countryCode, 'name': countryCode},
      );
      _selectedCountryName = countryData['name'];

      _countryConfig = CountryFiscalRepository.getConfig(
        countryCode,
        _selectedCountryName ?? countryCode,
      );

      // Buscar dados salvos para este país
      final personTypeData = _dataService.getFiscalData(countryCode, _personType);
      final fiscalFields = _countryConfig!.getFiscalFields(_personType);
      _fiscalControllerManager.recreateControllersFromFields(
        fiscalFields,
        (field) => field.id,
        initialValues: personTypeData.fields,
      );

      // Buscar dados bancários
      final countryBankData = _dataService.getBankData(countryCode);
      _bankControllerManager.recreateControllersFromFields(
        _countryConfig!.bankFields,
        (field) => field.id,
        initialValues: countryBankData.fields,
      );
    });
  }

  void _onPersonTypeChanged(String newPersonType) {
    // Salvar dados atuais antes de mudar
    if (_selectedCountryCode != null && _countryConfig != null) {
      final currentPersonTypeData = FiscalData(
        fields: _fiscalControllerManager.getValues(),
      );

      _dataService.saveFiscalData(
        _selectedCountryCode!,
        _personType,
        currentPersonTypeData,
      );
    }

    setState(() {
      _personType = newPersonType;

      if (_countryConfig != null && _selectedCountryCode != null) {
        final personTypeData = _dataService.getFiscalData(
          _selectedCountryCode!,
          _personType,
        );

        final fiscalFields = _countryConfig!.getFiscalFields(_personType);
        _fiscalControllerManager.recreateControllersFromFields(
          fiscalFields,
          (field) => field.id,
          initialValues: personTypeData.fields,
        );
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountryCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um país')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Salvar dados fiscais atuais
      final fiscalValues = _fiscalControllerManager.getValues();

      final personTypeData = FiscalData(
        fields: fiscalValues,
      );

      _dataService.saveFiscalData(
        _selectedCountryCode!,
        _personType,
        personTypeData,
      );

      _dataService.updateCurrentSelection(_selectedCountryCode!, _personType);
      final fiscalDataJson = _dataService.fiscalCacheToJson();

      // Salvar dados bancários
      final bankValues = _bankControllerManager.getValues();

      final countryBankData = BankData(
        fields: bankValues,
      );

      _dataService.saveBankData(_selectedCountryCode!, countryBankData);

      // Salvar plataformas de pagamento
      for (var platformId in _paymentPlatformControllerManager.getAllControllers().keys) {
        final isEnabled = _paymentPlatformEnabled[platformId] ?? false;
        final value = _paymentPlatformControllerManager.getValue(platformId);
        _dataService.savePaymentPlatform(platformId, isEnabled, value);
      }

      final bankDataJson = _dataService.bankCacheToJson();

      // Atualizar empresa
      await companiesModule.updateFiscalBankData(
        companyId: widget.companyId,
        fiscalCountry: _selectedCountryCode!,
        fiscalData: jsonDecode(fiscalDataJson),
        bankData: jsonDecode(bankDataJson),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados fiscais e bancários salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao salvar: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0 ? constraints.maxHeight - 32 : 0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Informação sobre a funcionalidade
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.public,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌍 Dados Fiscais e Bancários Multi-país',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure informações fiscais e bancárias para qualquer país do mundo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seletor de País
            CountrySelectorSection(
              selectedCountryCode: _selectedCountryCode,
              countries: _countries,
              canEdit: !_saving,
              saving: _saving,
              onCountrySelected: _onCountrySelected,
            ),

            if (_selectedCountryCode != null && _countryConfig != null) ...[
              const SizedBox(height: 24),

              // Campos Fiscais
              FiscalFieldsSection(
                countryConfig: _countryConfig,
                selectedCountryName: _selectedCountryName,
                personType: _personType,
                fiscalControllers: _fiscalControllerManager.getAllControllers(),
                canEdit: !_saving,
                saving: _saving,
                dataService: _dataService,
                selectedCountryCode: _selectedCountryCode,
                onPersonTypeChanged: _onPersonTypeChanged,
              ),

              const SizedBox(height: 24),

              // Campos Bancários
              BankFieldsSection(
                countryConfig: _countryConfig,
                selectedCountryName: _selectedCountryName,
                bankControllers: _bankControllerManager.getAllControllers(),
                canEdit: !_saving,
                saving: _saving,
              ),

              const SizedBox(height: 24),

              // Plataformas de Pagamento
              PaymentPlatformsSection(
                paymentPlatforms: _paymentPlatforms,
                paymentPlatformControllers: _paymentPlatformControllerManager.getAllControllers(),
                paymentPlatformEnabled: _paymentPlatformEnabled,
                canEdit: !_saving,
                saving: _saving,
                onPlatformEnabledChanged: (entry) {
                  setState(() {
                    _paymentPlatformEnabled[entry.key] = entry.value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Botão Salvar (condicional)
              if (widget.showSaveButton)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Salvando...' : 'Salvar Dados Fiscais e Bancários'),
                  ),
                ),
                ], // fecha o spread do if
              ], // children do Column
            ), // Column
          ), // Form
        ), // ConstrainedBox
      ); // SingleChildScrollView - return do builder
      },
    ); // LayoutBuilder
  }
}

