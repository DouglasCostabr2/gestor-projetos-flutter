import 'package:flutter/material.dart';
import '../../../../modules/modules.dart';
import '../../../state/app_state_scope.dart';
import '../../../../ui/atoms/inputs/inputs.dart';
import '../../../../ui/atoms/buttons/buttons.dart';
import '../../../../ui/organisms/dialogs/dialogs.dart';
import '../../../navigation/tab_manager_scope.dart';

/// Aba de detalhes da organização
class OrganizationDetailsTab extends StatefulWidget {
  const OrganizationDetailsTab({super.key});

  @override
  State<OrganizationDetailsTab> createState() => _OrganizationDetailsTabState();
}

class _OrganizationDetailsTabState extends State<OrganizationDetailsTab> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  bool _deleting = false;
  // Controllers para os campos básicos
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _tradeNameController = TextEditingController();

  // Controllers para endereço
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _addressComplementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Controllers para contatos
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadOrganization();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _legalNameController.dispose();
    _tradeNameController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _addressComplementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    setState(() => _loading = true);
    try {
      final appState = AppStateScope.of(context);
      final org = appState.currentOrganization;

      if (org != null) {
        _nameController.text = org['name'] ?? '';
        _slugController.text = org['slug'] ?? '';
        _legalNameController.text = org['legal_name'] ?? '';
        _tradeNameController.text = org['trade_name'] ?? '';
        _addressController.text = org['address'] ?? '';
        _addressNumberController.text = org['address_number'] ?? '';
        _addressComplementController.text = org['address_complement'] ?? '';
        _neighborhoodController.text = org['neighborhood'] ?? '';
        _cityController.text = org['city'] ?? '';
        _stateController.text = org['state_province'] ?? '';
        _postalCodeController.text = org['postal_code'] ?? '';
        _countryController.text = org['country'] ?? '';
        _emailController.text = org['email'] ?? '';
        _phoneController.text = org['phone'] ?? '';
        _mobileController.text = org['mobile'] ?? '';
        _websiteController.text = org['website'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar organização: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;

      if (orgId == null) {
        throw Exception('Nenhuma organização ativa');
      }

      await organizationsModule.updateOrganization(
        organizationId: orgId,
        name: _nameController.text.trim(),
        slug: _slugController.text.trim().isEmpty ? null : _slugController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty ? null : _legalNameController.text.trim(),
        tradeName: _tradeNameController.text.trim().isEmpty ? null : _tradeNameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        addressNumber: _addressNumberController.text.trim().isEmpty ? null : _addressNumberController.text.trim(),
        addressComplement: _addressComplementController.text.trim().isEmpty ? null : _addressComplementController.text.trim(),
        neighborhood: _neighborhoodController.text.trim().isEmpty ? null : _neighborhoodController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        zipCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      );

      // Atualizar organização no AppState
      await appState.refreshOrganizations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organização atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
  Future<void> _confirmDeleteOrganization() async {
    final appState = AppStateScope.of(context);
    final orgName = appState.currentOrganization?['name'] ?? 'esta organização';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Excluir Organização',
        message: 'Tem certeza que deseja excluir "$orgName"?\n\nEsta ação é irreversível e removerá todos os dados desta organização.',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await _deleteOrganization();
    }
  }

  Future<void> _deleteOrganization() async {
    final appState = AppStateScope.of(context);
    final orgId = appState.currentOrganizationId;
    if (orgId == null) return;

    setState(() => _deleting = true);
    try {
      await organizationsModule.deleteOrganization(orgId);
      await appState.refreshOrganizations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organização excluída com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      final tabManager = TabManagerScope.maybeOf(context);
      if (tabManager != null) {
        final idx = tabManager.currentIndex;
        tabManager.removeTab(idx);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir organização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.canManageOrganization;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.business, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dados Básicos da Organização',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure nome, identificação, endereço e contatos da organização',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Basic Information
            GenericTextField(
              controller: _nameController,
              labelText: 'Nome da Organização',
              enabled: canEdit && !_saving,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _slugController,
              labelText: 'Slug (identificador único)',
              enabled: canEdit && !_saving,
              hintText: 'ex: minha-empresa',
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _legalNameController,
              labelText: 'Razão Social',
              enabled: canEdit && !_saving,
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _tradeNameController,
              labelText: 'Nome Fantasia',
              enabled: canEdit && !_saving,
            ),
            const SizedBox(height: 32),

            // Endereço
            Text(
              'Endereço',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GenericTextField(
                    controller: _addressController,
                    labelText: 'Logradouro',
                    enabled: canEdit && !_saving,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GenericTextField(
                    controller: _addressNumberController,
                    labelText: 'Número',
                    enabled: canEdit && !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _addressComplementController,
              labelText: 'Complemento',
              enabled: canEdit && !_saving,
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _neighborhoodController,
              labelText: 'Bairro',
              enabled: canEdit && !_saving,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GenericTextField(
                    controller: _cityController,
                    labelText: 'Cidade',
                    enabled: canEdit && !_saving,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GenericTextField(
                    controller: _stateController,
                    labelText: 'Estado',
                    enabled: canEdit && !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GenericTextField(
                    controller: _postalCodeController,
                    labelText: 'CEP',
                    enabled: canEdit && !_saving,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GenericTextField(
                    controller: _countryController,
                    labelText: 'País',
                    enabled: canEdit && !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Contatos
            Text(
              'Contatos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _emailController,
              labelText: 'Email',
              enabled: canEdit && !_saving,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GenericTextField(
                    controller: _phoneController,
                    labelText: 'Telefone',
                    enabled: canEdit && !_saving,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GenericTextField(
                    controller: _mobileController,
                    labelText: 'Celular',
                    enabled: canEdit && !_saving,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GenericTextField(
              controller: _websiteController,
              labelText: 'Website',
              enabled: canEdit && !_saving,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 32),
            // Botões de ação
            if (canEdit) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SecondaryButton(
                    label: 'Cancelar',
                    onPressed: _saving ? null : () => _loadOrganization(),
                  ),
                  const SizedBox(width: 16),
                  PrimaryButton(
                    label: 'Salvar Alterações',
                    onPressed: _saving ? null : _saveOrganization,
                    isLoading: _saving,
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[300]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você não tem permissão para editar a organização. Apenas proprietários e administradores podem fazer alterações.',
                        style: TextStyle(color: Colors.orange[300]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

	            const SizedBox(height: 24),
	            if (appState.isOrgOwner) ...[
	              Container(
	                padding: const EdgeInsets.all(16),
	                decoration: BoxDecoration(
	                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
	                  borderRadius: BorderRadius.circular(8),
	                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
	                ),
	                child: Column(
	                  crossAxisAlignment: CrossAxisAlignment.start,
	                  children: [
	                    Row(
	                      children: [
	                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
	                        const SizedBox(width: 8),
	                        Text(
	                          'Zona de Perigo',
	                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
	                                color: Theme.of(context).colorScheme.error,
	                                fontWeight: FontWeight.bold,
	                              ),
	                        ),
	                      ],
	                    ),
	                    const SizedBox(height: 8),
	                    Text(
	                      'Excluir a organização é irreversível e removerá todos os dados associados.',
	                      style: Theme.of(context).textTheme.bodyMedium,
	                    ),
	                    const SizedBox(height: 12),
	                    Align(
	                      alignment: Alignment.centerRight,
	                      child: DangerButton(
	                        onPressed: _deleting ? null : _confirmDeleteOrganization,
	                        label: 'Excluir Organização',
	                        icon: Icons.delete_forever,
	                        isLoading: _deleting,
	                      ),
	                    ),
	                  ],
	                ),
	              ),
	            ],
          ],
        ),
      ),
    );
  }
}


