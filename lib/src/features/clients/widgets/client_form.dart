import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'dart:io';
import 'country_state_city_selector.dart';
import 'avatar_picker.dart';
import 'social_networks_field.dart';
import 'package:my_business/ui/organisms/dialogs/dialogs.dart';
import 'package:my_business/modules/clients/module.dart';
import 'package:my_business/modules/common/organization_context.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';
import 'package:my_business/ui/atoms/inputs/inputs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/molecules/inputs/mention_text_area.dart';
import 'package:my_business/services/mentions_service.dart';
import 'package:my_business/constants/client_status.dart';

/// Formulário de criação/edição de cliente
class ClientForm extends StatefulWidget {
  final Map<String, dynamic>? initial;
  
  const ClientForm({super.key, this.initial});

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  // Fiscal fields
  final _taxId = TextEditingController();
  final _legalName = TextEditingController();
  String? _selectedTaxIdType;

  csc.Country? _selectedCountry;
  csc.State? _selectedState;
  csc.City? _selectedCity;

  bool _saving = false;
  bool _loadingCategories = true;
  bool _loadingInitialData = false;
  String? _selectedCategoryId;
  String _selectedStatus = ClientStatus.naoProspectado;

  // Avatar
  File? _avatarFile;
  String? _avatarUrl;

  // Categorias carregadas do banco
  List<Map<String, dynamic>> _categories = [];

  // Redes sociais
  List<SocialNetwork> _socialNetworks = [];

  // Cache estático de países para evitar múltiplas chamadas
  static List<csc.Country>? _countriesCache;

  @override
  void initState() {
    super.initState();

    final i = widget.initial;
    if (i != null) {
      _name.text = i['name'] ?? '';
      _email.text = i['email'] ?? '';
      _phone.text = i['phone'] ?? '';
      _notes.text = i['notes'] ?? '';
      _avatarUrl = i['avatar_url'];
      _selectedCategoryId = i['category_id'];
      _selectedStatus = i['status'] ?? 'nao_prospectado';

      // Fiscal fields
      _taxId.text = i['tax_id'] ?? '';
      _legalName.text = i['legal_name'] ?? '';
      _selectedTaxIdType = i['tax_id_type'];

      // Carregar redes sociais
      if (i['social_networks'] != null) {
        final networksJson = i['social_networks'] as List<dynamic>;
        _socialNetworks = networksJson
            .map((json) => SocialNetwork.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Carregar país, estado e cidade iniciais de forma assíncrona
      _loadingInitialData = true;
      // Usar addPostFrameCallback para não bloquear a abertura do formulário
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialLocation(
          countryName: i['country'] as String?,
          stateName: i['state'] as String?,
          cityName: i['city'] as String?,
        );
      });
    }

    // Carregar categorias em background (não bloqueia a abertura do formulário)
    _loadCategories();
  }

  Future<void> _loadInitialLocation({
    String? countryName,
    String? stateName,
    String? cityName,
  }) async {
    if (countryName == null) {
      setState(() => _loadingInitialData = false);
      return;
    }

    try {
      // Buscar todos os países (com cache)
      _countriesCache ??= await csc.getAllCountries();
      final countries = _countriesCache!;

      // Encontrar o país pelo nome
      final country = countries.firstWhere(
        (c) => c.name.toLowerCase() == countryName.toLowerCase(),
        orElse: () => countries.first,
      );

      _selectedCountry = country;

      // Se tem estado, buscar estados do país
      if (stateName != null) {
        final states = await csc.getStatesOfCountry(country.isoCode);

        final state = states.firstWhere(
          (s) => s.name.toLowerCase() == stateName.toLowerCase(),
          orElse: () => states.first,
        );
        _selectedState = state;

        // Se tem cidade, buscar cidades do estado
        if (cityName != null) {
          final cities = await csc.getStateCities(country.isoCode, state.isoCode);

          final city = cities.firstWhere(
            (c) => c.name.toLowerCase() == cityName.toLowerCase(),
            orElse: () => cities.first,
          );
          _selectedCity = city;
        }
      }

      if (mounted) {
        setState(() {
          _loadingInitialData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingInitialData = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('client_categories')
          .select('id, name, color')
          .order('name');

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(res);
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    _taxId.dispose();
    _legalName.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await AvatarPicker.pickImage();
    if (file != null) {
      setState(() => _avatarFile = file);
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_avatarFile == null) return _avatarUrl;

    try {
      // Obter organization_id da organização ativa
      final organizationId = OrganizationContext.currentOrganizationId;
      if (organizationId == null) {
        throw Exception('Nenhuma organização ativa');
      }

      // Sanitizar nome do cliente para usar no nome do arquivo
      final clientName = _name.text.trim().isEmpty
          ? 'cliente'
          : _name.text.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = '$organizationId/avatar-$clientName.jpg';

      // Deletar avatar antigo se existir (para liberar espaço)
      if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
        try {
          // Extrair o caminho do arquivo da URL
          // URL format: https://.../storage/v1/object/public/client-avatars/userId/timestamp.ext
          final uri = Uri.parse(_avatarUrl!);
          final pathSegments = uri.pathSegments;
          // Encontrar o índice de 'client-avatars' e pegar tudo depois
          final bucketIndex = pathSegments.indexOf('client-avatars');
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final oldPath = pathSegments.sublist(bucketIndex + 1).join('/');
            await Supabase.instance.client.storage
                .from('client-avatars')
                .remove([oldPath]);
          }
        } catch (e) {
          // Avatar antigo pode não existir, ignorar erro
        }
      }

      // Fazer upload do novo avatar
      await Supabase.instance.client.storage
          .from('client-avatars')
          .upload(fileName, _avatarFile!);

      final url = Supabase.instance.client.storage
          .from('client-avatars')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      // Erro ao fazer upload do avatar
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Upload do avatar se houver
      final avatarUrl = await _uploadAvatar();

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      if (widget.initial == null) {
        // Criar novo cliente usando o módulo
        await clientsModule.createClient(
          name: _name.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          country: _selectedCountry?.name,
          state: _selectedState?.name,
          city: _selectedCity?.name,
          status: _selectedStatus,
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          taxIdType: _selectedTaxIdType,
          legalName: _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
        );

        // Atualizar avatar, categoria, notas e redes sociais separadamente (não estão no módulo)
        if (avatarUrl != null || _selectedCategoryId != null || _notes.text.trim().isNotEmpty || _socialNetworks.isNotEmpty) {
          final updateData = <String, dynamic>{};
          if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
          if (_selectedCategoryId != null) updateData['category_id'] = _selectedCategoryId;
          if (_notes.text.trim().isNotEmpty) updateData['notes'] = _notes.text.trim();

          // Converter redes sociais para JSON
          final networksJson = _socialNetworks
              .where((n) => n.name.trim().isNotEmpty || n.url.trim().isNotEmpty)
              .map((n) => n.toJson())
              .toList();
          updateData['social_networks'] = networksJson;

          // Buscar o cliente recém-criado para pegar o ID
          final clients = await Supabase.instance.client
              .from('clients')
              .select('id')
              .eq('name', _name.text.trim())
              .eq('owner_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          if (clients.isNotEmpty) {
            final clientId = clients.first['id'] as String;
            await Supabase.instance.client
                .from('clients')
                .update(updateData)
                .eq('id', clientId);

            // Salvar menções das notas
            if (_notes.text.trim().isNotEmpty) {
              final mentionsService = MentionsService();
              try {
                await mentionsService.saveClientMentions(
                  clientId: clientId,
                  fieldName: 'notes',
                  content: _notes.text,
                );
              } catch (e) {
                debugPrint('Erro ao salvar menções das notas: $e');
              }
            }
          }
        }
      } else {
        // Atualizar existente usando o módulo
        await clientsModule.updateClient(
          clientId: widget.initial!['id'],
          name: _name.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          country: _selectedCountry?.name,
          state: _selectedState?.name,
          city: _selectedCity?.name,
          status: _selectedStatus,
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          taxIdType: _selectedTaxIdType,
          legalName: _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
        );

        // Atualizar avatar, categoria, notas e redes sociais separadamente (não estão no módulo)
        final updateData = <String, dynamic>{};
        if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
        if (_selectedCategoryId != null) updateData['category_id'] = _selectedCategoryId;
        if (_notes.text.trim().isNotEmpty) updateData['notes'] = _notes.text.trim();

        // Converter redes sociais para JSON
        final networksJson = _socialNetworks
            .where((n) => n.name.trim().isNotEmpty || n.url.trim().isNotEmpty)
            .map((n) => n.toJson())
            .toList();
        updateData['social_networks'] = networksJson;

        if (updateData.isNotEmpty) {
          await Supabase.instance.client
              .from('clients')
              .update(updateData)
              .eq('id', widget.initial!['id']);
        }

        // Salvar menções das notas
        if (_notes.text.trim().isNotEmpty) {
          final mentionsService = MentionsService();
          try {
            await mentionsService.saveClientMentions(
              clientId: widget.initial!['id'],
              fieldName: 'notes',
              content: _notes.text,
            );
          } catch (e) {
            debugPrint('Erro ao salvar menções das notas: $e');
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    // Mostrar loading enquanto carrega dados iniciais
    if (_loadingInitialData) {
      return StandardDialog(
        title: isEditing ? 'Editar Cliente' : 'Novo Cliente',
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        isLoading: true,
        actions: const [],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando dados do cliente...'),
            ],
          ),
        ),
      );
    }

    return StandardDialog(
      title: isEditing ? 'Editar Cliente' : 'Novo Cliente',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightMedium,
      isLoading: _saving,
      actions: [
        TextOnlyButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          label: 'Cancelar',
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          label: isEditing ? 'Salvar' : 'Criar',
          isLoading: _saving,
        ),
      ],
      child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar
                      Center(
                        child: AvatarPicker(
                          avatarFile: _avatarFile,
                          avatarUrl: _avatarUrl,
                          onPick: _pickAvatar,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nome
                      GenericTextField(
                        controller: _name,
                        labelText: 'Nome *',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),

                      // Categoria
                      if (_loadingCategories)
                        const LinearProgressIndicator()
                      else
                        GenericDropdownField<String?>(
                          value: _selectedCategoryId,
                          items: _categories.map((category) => DropdownItem<String?>(
                            value: category['id'] as String,
                            label: category['name'] as String,
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedCategoryId = value),
                          labelText: 'Categoria',
                          hintText: 'Selecione uma categoria',
                        ),
                      const SizedBox(height: 16),

                      // Status
                      GenericDropdownField<String>(
                        value: _selectedStatus,
                        items: ClientStatus.values.map((status) => DropdownItem(
                          value: status,
                          label: ClientStatus.getLabel(status),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedStatus = value ?? ClientStatus.naoProspectado),
                        labelText: 'Status',
                        hintText: 'Selecione um status',
                      ),
                      const SizedBox(height: 16),

                      // Email
                      GenericEmailField(
                        controller: _email,
                        labelText: 'Email',
                      ),
                      const SizedBox(height: 16),

                      // Telefone
                      GenericPhoneField(
                        controller: _phone,
                        labelText: 'Telefone',
                        hintText: '+55 (11) 98765-4321',
                      ),
                      const SizedBox(height: 24),

                      // País, Estado, Cidade
                      CountryStateCitySelector(
                        key: ValueKey('${_selectedCountry?.isoCode}_${_selectedState?.isoCode}_${_selectedCity?.name}'),
                        initialCountry: _selectedCountry,
                        initialState: _selectedState,
                        initialCity: _selectedCity,
                        onCountryChanged: (country) => _selectedCountry = country,
                        onStateChanged: (state) => _selectedState = state,
                        onCityChanged: (city) => _selectedCity = city,
                      ),
                      const SizedBox(height: 24),

                      // Seção de Dados Fiscais
                      Text(
                        '📋 Dados Fiscais (para Invoicing)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Informações fiscais para emissão de invoices/notas fiscais',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tax ID Type
                      GenericDropdownField<String>(
                        value: _selectedTaxIdType,
                        items: const [
                          DropdownItem(value: 'cpf', label: 'CPF (Brasil - Pessoa Física)'),
                          DropdownItem(value: 'cnpj', label: 'CNPJ (Brasil - Pessoa Jurídica)'),
                          DropdownItem(value: 'ssn', label: 'SSN (EUA - Social Security Number)'),
                          DropdownItem(value: 'ein', label: 'EIN (EUA - Employer ID)'),
                          DropdownItem(value: 'vat', label: 'VAT (Europa - Value Added Tax)'),
                          DropdownItem(value: 'nif', label: 'NIF (Portugal/Espanha)'),
                          DropdownItem(value: 'abn', label: 'ABN (Austrália)'),
                          DropdownItem(value: 'bn', label: 'BN (Canadá - Business Number)'),
                          DropdownItem(value: 'tin', label: 'TIN (Genérico - Tax ID Number)'),
                        ],
                        onChanged: (value) => setState(() => _selectedTaxIdType = value),
                        labelText: 'Tipo de Identificação Fiscal',
                        hintText: 'Selecione o tipo de documento',
                      ),
                      const SizedBox(height: 16),

                      // Tax ID
                      GenericTextField(
                        controller: _taxId,
                        labelText: 'Número de Identificação Fiscal',
                        hintText: 'Ex: 123.456.789-00, 12.345.678/0001-90, etc.',
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 16),

                      // Legal Name
                      GenericTextField(
                        controller: _legalName,
                        labelText: 'Nome Legal / Razão Social',
                        hintText: 'Nome completo ou razão social para invoices',
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 24),

                      // Notas/Observações
                      MentionTextArea(
                        controller: _notes,
                        labelText: 'Notas/Observações',
                        hintText: 'Adicione notas sobre o cliente... (digite @ para mencionar)',
                        minLines: 3,
                        maxLines: 6,
                        enabled: !_saving,
                        onMentionsChanged: (userIds) {
                          // Menções serão salvas ao salvar o cliente
                        },
                      ),
                      const SizedBox(height: 24),

                      // Redes Sociais
                      SocialNetworksField(
                        initialNetworks: _socialNetworks,
                        onChanged: (networks) => _socialNetworks = networks,
                        enabled: !_saving,
                      ),
          ],
        ),
      ),
    );
  }
}

