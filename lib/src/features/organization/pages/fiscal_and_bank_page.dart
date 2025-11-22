import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../modules/modules.dart';
import '../../../state/app_state_scope.dart';
import '../models/country_fiscal_config.dart';
import '../models/fiscal_bank_models.dart';
import '../services/fiscal_bank_data_service.dart';
import '../utils/form_controller_manager.dart';
import '../widgets/widgets.dart';
import '../../../../core/di/service_locator.dart';

class FiscalAndBankPage extends StatefulWidget {
  const FiscalAndBankPage({super.key});

  @override
  State<FiscalAndBankPage> createState() => _FiscalAndBankPageState();
}

class _FiscalAndBankPageState extends State<FiscalAndBankPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  DateTime? _lastCountryChange; // Timestamp da última mudança de país

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
  String _personType = 'business'; // Padrão: Pessoa Jurídica

  final Map<String, bool> _paymentPlatformEnabled = {}; // Controla se cada plataforma está habilitada

  // Informações de auditoria
  LatestAuditInfo? _latestAudit;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _fiscalControllerManager.disposeAll();
    _bankControllerManager.disposeAll();
    _paymentPlatformControllerManager.disposeAll();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;

      if (orgId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Buscar dados atualizados diretamente do banco
      final org = await organizationsModule.getOrganization(orgId);

      if (org != null) {
        // Carregar estrutura hierárquica de dados fiscais
        final fiscalData = org['fiscal_data'];
        String? fiscalDataStr;

        if (fiscalData != null) {
          if (fiscalData is String) {
            fiscalDataStr = fiscalData;
          } else if (fiscalData is Map) {
            fiscalDataStr = jsonEncode(fiscalData);
          }
        }

        if (fiscalDataStr != null && fiscalDataStr.isNotEmpty) {
          // Inicializar o cache do service com os dados do banco
          _dataService.initializeFiscalCache(fiscalDataStr);

          // Carregar país e tipo de pessoa atuais
          _selectedCountryCode = _dataService.getCurrentCountry();
          _personType = _dataService.getCurrentPersonType();
        }

        if (_selectedCountryCode != null && _selectedCountryCode!.isNotEmpty) {
          final countryData = _countries.firstWhere(
            (c) => c['code'] == _selectedCountryCode,
            orElse: () => {'code': _selectedCountryCode!, 'name': _selectedCountryCode!},
          );
          _selectedCountryName = countryData['name']?.toString();

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
        final bankData = org['bank_data'];
        String? bankDataStr;

        if (bankData != null) {
          if (bankData is String) {
            bankDataStr = bankData;
          } else if (bankData is Map) {
            bankDataStr = jsonEncode(bankData);
          }
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

          // Carregar dados de plataformas de pagamento
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
        }

        // Inicializar controllers de plataformas de pagamento se ainda não existirem
        if (_paymentPlatformControllerManager.length == 0) {
          final platformIds = _paymentPlatforms.map((p) => p['id']!).toList();
          _paymentPlatformControllerManager.createControllers(platformIds);
          for (var platformId in platformIds) {
            _paymentPlatformEnabled[platformId] = false; // Desabilitado por padrão
          }
        }

        // Carregar informações de auditoria
        final auditRepo = serviceLocator.get<FiscalBankAuditRepository>();
        _latestAudit = await auditRepo.getLatestAudit(orgId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCountrySelected(String? countryCode) async {
    if (countryCode == null) return;

    // Bloquear mudanças muito rápidas (menos de 300ms)
    // Isso acontece quando o dropdown muda sozinho durante rebuild
    final now = DateTime.now();
    if (_lastCountryChange != null) {
      final timeSinceLastChange = now.difference(_lastCountryChange!);
      if (timeSinceLastChange.inMilliseconds < 300) {
        return;
      }
    }
    _lastCountryChange = now;

    // Os dados já estão carregados no service, não precisamos buscar novamente

    setState(() {
      _selectedCountryCode = countryCode;
      final countryData = _countries.firstWhere(
        (c) => c['code'] == countryCode,
        orElse: () => {'code': countryCode, 'name': countryCode},
      );
      _selectedCountryName = countryData['name']?.toString();

      _countryConfig = CountryFiscalRepository.getConfig(
        countryCode,
        _selectedCountryName ?? countryCode,
      );

      // Buscar dados salvos para este país e tipo de pessoa usando o service
      final personTypeData = _dataService.getFiscalData(countryCode, _personType);

      final fiscalFields = _countryConfig!.getFiscalFields(_personType);
      _fiscalControllerManager.recreateControllersFromFields(
        fiscalFields,
        (field) => field.id,
        initialValues: personTypeData.fields,
      );

      // Buscar dados bancários salvos para este país usando o service
      final countryBankData = _dataService.getBankData(countryCode);

      _bankControllerManager.recreateControllersFromFields(
        _countryConfig!.bankFields,
        (field) => field.id,
        initialValues: countryBankData.fields,
      );
    });
  }

  /// Handler para mudança de tipo de pessoa (Física/Jurídica)
  void _onPersonTypeChanged(String newPersonType) {
    // Salvar os dados atuais dos controllers ANTES de alternar
    // Isso preserva o que o usuário digitou mas não salvou ainda
    if (_selectedCountryCode != null && _countryConfig != null) {
      // Salvar dados do tipo de pessoa ATUAL (antes de mudar)
      final currentPersonTypeData = FiscalData(
        fields: _fiscalControllerManager.getValues(),
      );

      // Salvar no service (preserva dados do outro tipo de pessoa automaticamente)
      _dataService.saveFiscalData(
        _selectedCountryCode!,
        _personType,
        currentPersonTypeData,
      );
    }

    setState(() {
      _personType = newPersonType;

      // Recriar controllers com os campos apropriados
      if (_countryConfig != null && _selectedCountryCode != null) {
        // Buscar dados salvos para este país e novo tipo de pessoa usando o service
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
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;
      if (orgId == null) throw Exception('Nenhuma organização ativa');

      // Buscar dados existentes para preservar histórico
      final org = await organizationsModule.getOrganization(orgId);

      // Salvar dados fiscais atuais no service
      final personTypeData = FiscalData(
        fields: _fiscalControllerManager.getValues(),
      );

      _dataService.saveFiscalData(
        _selectedCountryCode!,
        _personType,
        personTypeData,
      );

      // Atualizar país e tipo de pessoa atuais no service
      _dataService.updateCurrentSelection(_selectedCountryCode!, _personType);

      // Obter JSON para salvar no banco
      final fiscalDataJson = _dataService.fiscalCacheToJson();

      // Salvar dados bancários atuais no service
      final countryBankData = BankData(
        fields: _bankControllerManager.getValues(),
      );

      _dataService.saveBankData(_selectedCountryCode!, countryBankData);

      // Salvar dados de plataformas de pagamento (preservar dados mesmo quando desabilitado)
      for (var platformId in _paymentPlatformControllerManager.getAllControllers().keys) {
        final isEnabled = _paymentPlatformEnabled[platformId] ?? false;
        final value = _paymentPlatformControllerManager.getValue(platformId);

        _dataService.savePaymentPlatform(platformId, isEnabled, value);
      }

      // Obter JSON bancário para salvar no banco
      final bankDataJson = _dataService.bankCacheToJson();

      await organizationsModule.updateOrganization(
        organizationId: orgId,
        fiscalCountry: _selectedCountryCode!,
        fiscalData: fiscalDataJson,
        bankData: bankDataJson,
      );

      // Registrar auditoria
      final auditRepo = serviceLocator.get<FiscalBankAuditRepository>();
      final currentUser = appState.profile;
      final authUser = authModule.currentUser;

      if (currentUser != null && authUser != null) {

        // Detectar mudanças
        final existingFiscalData = org?['fiscal_data'];
        Map<String, dynamic> oldFiscalData = {};

        if (existingFiscalData != null) {
          if (existingFiscalData is String && existingFiscalData.isNotEmpty) {
            oldFiscalData = Map<String, dynamic>.from(jsonDecode(existingFiscalData));
          } else if (existingFiscalData is Map) {
            oldFiscalData = Map<String, dynamic>.from(existingFiscalData);
          }
        }

        final existingBankData = org?['bank_data'];
        Map<String, dynamic> oldBankData = {};

        if (existingBankData != null) {
          if (existingBankData is String && existingBankData.isNotEmpty) {
            oldBankData = Map<String, dynamic>.from(jsonDecode(existingBankData));
          } else if (existingBankData is Map) {
            oldBankData = Map<String, dynamic>.from(existingBankData);
          }
        }

        final changedFields = <String>[];

        // Detectar mudanças em dados fiscais
        Map<String, dynamic>? oldCountryFiscalData;
        if (oldFiscalData.containsKey(_selectedCountryCode)) {
          final temp = oldFiscalData[_selectedCountryCode];
          if (temp is Map) {
            oldCountryFiscalData = Map<String, dynamic>.from(temp);
          }
        }

        Map<String, dynamic>? oldPersonTypeData;
        if (oldCountryFiscalData != null && oldCountryFiscalData.containsKey(_personType)) {
          final temp = oldCountryFiscalData[_personType];
          if (temp is Map) {
            oldPersonTypeData = Map<String, dynamic>.from(temp);
          }
        }

        if (oldPersonTypeData != personTypeData.fields) {
          changedFields.addAll(_fiscalControllerManager.getAllControllers().keys);
        }

        // Detectar mudanças em dados bancários
        Map<String, dynamic>? oldCountryBankData;
        if (oldBankData.containsKey(_selectedCountryCode)) {
          final temp = oldBankData[_selectedCountryCode];
          if (temp is Map) {
            oldCountryBankData = Map<String, dynamic>.from(temp);
          }
        }

        if (oldCountryBankData != countryBankData.fields) {
          changedFields.addAll(_bankControllerManager.getAllControllers().keys);
        }

        // Detectar mudanças em plataformas de pagamento
        for (var platformId in _paymentPlatformControllerManager.getAllControllers().keys) {
          final oldPlatformData = oldBankData['payment_platforms'] is Map
              ? (oldBankData['payment_platforms'] as Map)[platformId]
              : null;
          final newPlatformData = _dataService.getPaymentPlatform(platformId);

          final oldValue = oldPlatformData is Map ? oldPlatformData['value'] : oldPlatformData;
          final newValue = newPlatformData?.value;

          if (oldValue != newValue) {
            changedFields.add(platformId);
          }
        }

        // Converter para Map<String, dynamic> corretamente
        final changedFieldsMap = <String, dynamic>{
          'fields': changedFields,
        };


        final previousValuesMap = <String, dynamic>{
          'fiscal': oldPersonTypeData != null ? Map<String, dynamic>.from(oldPersonTypeData) : <String, dynamic>{},
          'bank': oldCountryBankData != null ? Map<String, dynamic>.from(oldCountryBankData) : <String, dynamic>{},
        };


        final newValuesMap = <String, dynamic>{
          'fiscal': personTypeData.toJson(),
          'bank': countryBankData.toJson(),
        };

        try {
          await auditRepo.createAuditLog(
            organizationId: orgId,
            userId: authUser.id,
            userName: currentUser['full_name'] as String? ?? authUser.email ?? 'Usuário',
            userEmail: authUser.email,
            actionType: 'update',
            countryCode: _selectedCountryCode,
            personType: _personType,
            changedFields: changedFieldsMap,
            previousValues: previousValuesMap,
            newValues: newValuesMap,
          );

          // Atualizar informações de auditoria na UI
          _latestAudit = await auditRepo.getLatestAudit(orgId);
        } catch (auditError) {
          // Mostrar erro de auditoria em um dialog
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Erro de Auditoria'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Erro ao criar registro de auditoria:'),
                      const SizedBox(height: 8),
                      Text(
                        auditError.toString(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            );
          }
        }
      }

      await appState.refreshOrganizations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Log error for debugging

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );

        // Mostrar dialog com detalhes do erro
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro Detalhado'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: SelectableText(
                  'ERRO:\n${e.toString()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Widget para exibir informações de auditoria (última alteração)
  Widget _buildAuditInfo() {
    if (_latestAudit == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _latestAudit!.getFormattedDescription(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _latestAudit!.getRelativeTime(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.canManageOrganization;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.public,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dados Fiscais e Bancários',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure informações para qualquer país do mundo',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Informação de última alteração
              if (_latestAudit != null) _buildAuditInfo(),

              const SizedBox(height: 32),

              CountrySelectorSection(
                selectedCountryCode: _selectedCountryCode,
                countries: _countries,
                canEdit: canEdit,
                saving: _saving,
                onCountrySelected: _onCountrySelected,
              ),

              if (_selectedCountryCode != null && _countryConfig != null) ...[
                const SizedBox(height: 32),
                FiscalFieldsSection(
                  countryConfig: _countryConfig,
                  selectedCountryName: _selectedCountryName,
                  personType: _personType,
                  fiscalControllers: _fiscalControllerManager.getAllControllers(),
                  canEdit: canEdit,
                  saving: _saving,
                  dataService: _dataService,
                  selectedCountryCode: _selectedCountryCode,
                  onPersonTypeChanged: _onPersonTypeChanged,
                ),
                const SizedBox(height: 32),
                BankFieldsSection(
                  countryConfig: _countryConfig,
                  selectedCountryName: _selectedCountryName,
                  bankControllers: _bankControllerManager.getAllControllers(),
                  canEdit: canEdit,
                  saving: _saving,
                ),
                const SizedBox(height: 32),
                PaymentPlatformsSection(
                  paymentPlatforms: _paymentPlatforms,
                  paymentPlatformControllers: _paymentPlatformControllerManager.getAllControllers(),
                  paymentPlatformEnabled: _paymentPlatformEnabled,
                  canEdit: canEdit,
                  saving: _saving,
                  onPlatformEnabledChanged: (entry) {
                    setState(() {
                      _paymentPlatformEnabled[entry.key] = entry.value;
                    });
                  },
                ),
              ],

              if (canEdit && _selectedCountryCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Salvando...' : 'Salvar'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
