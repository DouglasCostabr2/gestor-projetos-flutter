import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'dart:io';
import 'country_state_city_selector.dart';
import 'avatar_picker.dart';
import 'package:gestor_projetos_flutter/widgets/standard_dialog.dart';
import 'package:gestor_projetos_flutter/modules/clients/module.dart';
import 'package:gestor_projetos_flutter/widgets/dropdowns/dropdowns.dart';
import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

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

  csc.Country? _selectedCountry;
  csc.State? _selectedState;
  csc.City? _selectedCity;

  bool _saving = false;
  bool _loadingCategories = true;
  bool _loadingInitialData = false;
  String? _selectedCategoryId;

  // Avatar
  File? _avatarFile;
  String? _avatarUrl;

  // Categorias carregadas do banco
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i['name'] ?? '';
      _email.text = i['email'] ?? '';
      _phone.text = i['phone'] ?? '';
      _avatarUrl = i['avatar_url'];
      _selectedCategoryId = i['category_id'];

      // Carregar país, estado e cidade iniciais
      _loadingInitialData = true;
      _loadInitialLocation(
        countryName: i['country'] as String?,
        stateName: i['state'] as String?,
        cityName: i['city'] as String?,
      );
    }
    // Carregar categorias em background (não bloqueia a abertura do formulário)
    _loadCategories();
  }

  Future<void> _loadInitialLocation({
    String? countryName,
    String? stateName,
    String? cityName,
  }) async {
    debugPrint('🌍 Carregando localização inicial: País=$countryName, Estado=$stateName, Cidade=$cityName');

    if (countryName == null) {
      debugPrint('⚠️ countryName é null, abortando');
      setState(() => _loadingInitialData = false);
      return;
    }

    try {
      // Buscar todos os países
      final countries = await csc.getAllCountries();
      debugPrint('✅ ${countries.length} países carregados');

      // Encontrar o país pelo nome
      final country = countries.firstWhere(
        (c) => c.name.toLowerCase() == countryName.toLowerCase(),
        orElse: () => countries.first,
      );

      _selectedCountry = country;
      debugPrint('✅ País selecionado: ${country.name} (${country.isoCode})');

      // Se tem estado, buscar estados do país
      if (stateName != null) {
        final states = await csc.getStatesOfCountry(country.isoCode);
        debugPrint('✅ ${states.length} estados carregados para ${country.name}');

        final state = states.firstWhere(
          (s) => s.name.toLowerCase() == stateName.toLowerCase(),
          orElse: () => states.first,
        );
        _selectedState = state;
        debugPrint('✅ Estado selecionado: ${state.name} (${state.isoCode})');

        // Se tem cidade, buscar cidades do estado
        if (cityName != null) {
          final cities = await csc.getStateCities(country.isoCode, state.isoCode);
          debugPrint('✅ ${cities.length} cidades carregadas para ${state.name}');

          final city = cities.firstWhere(
            (c) => c.name.toLowerCase() == cityName.toLowerCase(),
            orElse: () => cities.first,
          );
          _selectedCity = city;
          debugPrint('✅ Cidade selecionada: ${city.name}');
        }
      }

      debugPrint('🎉 Localização carregada com sucesso!');
      if (mounted) {
        setState(() {
          _loadingInitialData = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar localização inicial: $e');
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
      debugPrint('Erro ao carregar categorias: $e');
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
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
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Sanitizar nome do cliente para usar no nome do arquivo
      final clientName = _name.text.trim().isEmpty
          ? 'cliente'
          : _name.text.trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');

      final fileName = '$userId/avatar-$clientName.jpg';

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
            debugPrint('✅ Avatar antigo do cliente deletado: $oldPath');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao deletar avatar antigo do cliente (pode não existir): $e');
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
      debugPrint('Erro ao fazer upload do avatar: $e');
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
        );

        // Atualizar avatar e categoria separadamente (não estão no módulo)
        if (avatarUrl != null || _selectedCategoryId != null) {
          final updateData = <String, dynamic>{};
          if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
          if (_selectedCategoryId != null) updateData['category_id'] = _selectedCategoryId;

          // Buscar o cliente recém-criado para pegar o ID
          final clients = await Supabase.instance.client
              .from('clients')
              .select('id')
              .eq('name', _name.text.trim())
              .eq('owner_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          if (clients.isNotEmpty) {
            await Supabase.instance.client
                .from('clients')
                .update(updateData)
                .eq('id', clients.first['id']);
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
        );

        // Atualizar avatar e categoria separadamente (não estão no módulo)
        if (avatarUrl != null || _selectedCategoryId != null) {
          final updateData = <String, dynamic>{};
          if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
          if (_selectedCategoryId != null) updateData['category_id'] = _selectedCategoryId;

          await Supabase.instance.client
              .from('clients')
              .update(updateData)
              .eq('id', widget.initial!['id']);
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
                      SearchableDropdownField<String>(
                        value: _selectedCategoryId,
                        items: _categories.map((category) => SearchableDropdownItem(
                          value: category['id'] as String,
                          label: category['name'] as String,
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedCategoryId = value),
                        labelText: 'Categoria',
                        isLoading: _loadingCategories,
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
                        hintText: '(00) 00000-0000',
                      ),
                      const SizedBox(height: 24),

                      // País, Estado, Cidade
                      if (_loadingInitialData)
                        const SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        CountryStateCitySelector(
                          key: ValueKey('${_selectedCountry?.isoCode}_${_selectedState?.isoCode}_${_selectedCity?.name}'),
                          initialCountry: _selectedCountry,
                          initialState: _selectedState,
                          initialCity: _selectedCity,
                          onCountryChanged: (country) => _selectedCountry = country,
                          onStateChanged: (state) => _selectedState = state,
                          onCityChanged: (city) => _selectedCity = city,
                        ),
          ],
        ),
      ),
    );
  }
}

