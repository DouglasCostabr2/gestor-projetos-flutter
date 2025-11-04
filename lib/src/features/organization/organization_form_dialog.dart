import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_business/ui/atoms/inputs/inputs.dart';
import 'package:my_business/ui/molecules/dropdowns/dropdowns.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/organisms/dialogs/standard_dialog.dart';

/// Dialog para configurações da organização
class OrganizationFormDialog extends StatefulWidget {
  const OrganizationFormDialog({super.key});

  @override
  State<OrganizationFormDialog> createState() => _OrganizationFormDialogState();
}

class _OrganizationFormDialogState extends State<OrganizationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _organizationId;

  // Basic Information
  final _companyName = TextEditingController();
  final _legalName = TextEditingController();
  final _tradeName = TextEditingController();

  // Fiscal Information
  final _taxId = TextEditingController();
  String? _selectedTaxIdType;
  final _stateRegistration = TextEditingController();
  final _municipalRegistration = TextEditingController();

  // Address
  final _address = TextEditingController();
  final _addressNumber = TextEditingController();
  final _addressComplement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zipCode = TextEditingController();
  final _country = TextEditingController();

  // Contact
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _mobile = TextEditingController();
  final _website = TextEditingController();

  // Branding
  final _logoUrl = TextEditingController();
  final _primaryColor = TextEditingController();

  // Invoice Settings
  final _invoicePrefix = TextEditingController();
  final _nextInvoiceNumber = TextEditingController();
  final _invoiceNotes = TextEditingController();
  final _paymentTerms = TextEditingController();

  // Bank Information
  final _bankName = TextEditingController();
  final _bankBranch = TextEditingController();
  final _bankAccount = TextEditingController();
  final _bankAccountType = TextEditingController();
  final _pixKey = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrganizationSettings();
  }

  Future<void> _loadOrganizationSettings() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('organization_settings')
          .select()
          .maybeSingle();

      if (data != null && mounted) {
        _organizationId = data['id'];
        
        // Basic Information
        _companyName.text = data['company_name'] ?? '';
        _legalName.text = data['legal_name'] ?? '';
        _tradeName.text = data['trade_name'] ?? '';

        // Fiscal Information
        _taxId.text = data['tax_id'] ?? '';
        _selectedTaxIdType = data['tax_id_type'];
        _stateRegistration.text = data['state_registration'] ?? '';
        _municipalRegistration.text = data['municipal_registration'] ?? '';

        // Address
        _address.text = data['address'] ?? '';
        _addressNumber.text = data['address_number'] ?? '';
        _addressComplement.text = data['address_complement'] ?? '';
        _neighborhood.text = data['neighborhood'] ?? '';
        _city.text = data['city'] ?? '';
        _state.text = data['state'] ?? '';
        _zipCode.text = data['zip_code'] ?? '';
        _country.text = data['country'] ?? '';

        // Contact
        _email.text = data['email'] ?? '';
        _phone.text = data['phone'] ?? '';
        _mobile.text = data['mobile'] ?? '';
        _website.text = data['website'] ?? '';

        // Branding
        _logoUrl.text = data['logo_url'] ?? '';
        _primaryColor.text = data['primary_color'] ?? '';

        // Invoice Settings
        _invoicePrefix.text = data['invoice_prefix'] ?? '';
        _nextInvoiceNumber.text = data['next_invoice_number']?.toString() ?? '1';
        _invoiceNotes.text = data['invoice_notes'] ?? '';
        _paymentTerms.text = data['payment_terms'] ?? '';

        // Bank Information
        _bankName.text = data['bank_name'] ?? '';
        _bankBranch.text = data['bank_agency'] ?? '';
        _bankAccount.text = data['bank_account'] ?? '';
        _bankAccountType.text = data['bank_account_type'] ?? '';
        _pixKey.text = data['pix_key'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final data = {
        'company_name': _companyName.text.trim().isEmpty ? null : _companyName.text.trim(),
        'legal_name': _legalName.text.trim().isEmpty ? null : _legalName.text.trim(),
        'trade_name': _tradeName.text.trim().isEmpty ? null : _tradeName.text.trim(),
        'tax_id': _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
        'tax_id_type': _selectedTaxIdType,
        'state_registration': _stateRegistration.text.trim().isEmpty ? null : _stateRegistration.text.trim(),
        'municipal_registration': _municipalRegistration.text.trim().isEmpty ? null : _municipalRegistration.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'address_number': _addressNumber.text.trim().isEmpty ? null : _addressNumber.text.trim(),
        'address_complement': _addressComplement.text.trim().isEmpty ? null : _addressComplement.text.trim(),
        'neighborhood': _neighborhood.text.trim().isEmpty ? null : _neighborhood.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'state': _state.text.trim().isEmpty ? null : _state.text.trim(),
        'zip_code': _zipCode.text.trim().isEmpty ? null : _zipCode.text.trim(),
        'country': _country.text.trim().isEmpty ? null : _country.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'mobile': _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
        'logo_url': _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
        'primary_color': _primaryColor.text.trim().isEmpty ? null : _primaryColor.text.trim(),
        'invoice_prefix': _invoicePrefix.text.trim().isEmpty ? null : _invoicePrefix.text.trim(),
        'next_invoice_number': _nextInvoiceNumber.text.trim().isEmpty ? 1 : int.tryParse(_nextInvoiceNumber.text.trim()) ?? 1,
        'invoice_notes': _invoiceNotes.text.trim().isEmpty ? null : _invoiceNotes.text.trim(),
        'payment_terms': _paymentTerms.text.trim().isEmpty ? null : _paymentTerms.text.trim(),
        'bank_name': _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        'bank_agency': _bankBranch.text.trim().isEmpty ? null : _bankBranch.text.trim(),
        'bank_account': _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        'bank_account_type': _bankAccountType.text.trim().isEmpty ? null : _bankAccountType.text.trim(),
        'pix_key': _pixKey.text.trim().isEmpty ? null : _pixKey.text.trim(),
      };

      if (_organizationId == null) {
        // Create new
        await Supabase.instance.client
            .from('organization_settings')
            .insert(data);
      } else {
        // Update existing
        await Supabase.instance.client
            .from('organization_settings')
            .update(data)
            .eq('id', _organizationId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!')),
        );
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _companyName.dispose();
    _legalName.dispose();
    _tradeName.dispose();
    _taxId.dispose();
    _stateRegistration.dispose();
    _municipalRegistration.dispose();
    _address.dispose();
    _addressNumber.dispose();
    _addressComplement.dispose();
    _neighborhood.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    _country.dispose();
    _email.dispose();
    _phone.dispose();
    _mobile.dispose();
    _website.dispose();
    _logoUrl.dispose();
    _primaryColor.dispose();
    _invoicePrefix.dispose();
    _nextInvoiceNumber.dispose();
    _invoiceNotes.dispose();
    _paymentTerms.dispose();
    _bankName.dispose();
    _bankBranch.dispose();
    _bankAccount.dispose();
    _bankAccountType.dispose();
    _pixKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const StandardDialog(
        title: 'Configurações da Organização',
        width: StandardDialog.widthLarge,
        height: StandardDialog.heightLarge,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return StandardDialog(
      title: 'Configurações da Organização',
      width: StandardDialog.widthLarge,
      height: StandardDialog.heightLarge,
      isLoading: _saving,
      actions: [
        TextOnlyButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          label: 'Cancelar',
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          label: 'Salvar',
          isLoading: _saving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Basic Information
              _buildSectionTitle(context, '📋 Informações Básicas'),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _companyName,
                labelText: 'Nome da Empresa *',
                hintText: 'Nome comercial da empresa',
                enabled: !_saving,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _legalName,
                labelText: 'Razão Social / Legal Name',
                hintText: 'Nome legal completo da empresa',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _tradeName,
                labelText: 'Nome Fantasia / Trade Name',
                hintText: 'Nome fantasia da empresa',
                enabled: !_saving,
              ),
              const SizedBox(height: 32),

              // Section 2: Fiscal Information
              _buildSectionTitle(context, '💼 Dados Fiscais'),
              const SizedBox(height: 16),

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

              GenericTextField(
                controller: _taxId,
                labelText: 'Número de Identificação Fiscal',
                hintText: 'Ex: 12.345.678/0001-90, VAT123456, etc.',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _stateRegistration,
                labelText: 'Inscrição Estadual (Brasil)',
                hintText: 'Apenas para empresas brasileiras',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _municipalRegistration,
                labelText: 'Inscrição Municipal (Brasil)',
                hintText: 'Apenas para empresas brasileiras',
                enabled: !_saving,
              ),
              const SizedBox(height: 32),

              // Section 3: Address
              _buildSectionTitle(context, '📍 Endereço'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GenericTextField(
                      controller: _address,
                      labelText: 'Endereço',
                      hintText: 'Rua, Avenida, etc.',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: GenericTextField(
                      controller: _addressNumber,
                      labelText: 'Número',
                      hintText: '123',
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _addressComplement,
                labelText: 'Complemento',
                hintText: 'Sala, Andar, etc.',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _neighborhood,
                labelText: 'Bairro',
                hintText: 'Nome do bairro',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GenericTextField(
                      controller: _city,
                      labelText: 'Cidade',
                      hintText: 'Nome da cidade',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericTextField(
                      controller: _state,
                      labelText: 'Estado/Província',
                      hintText: 'Ex: SP, CA, etc.',
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GenericTextField(
                      controller: _zipCode,
                      labelText: 'CEP/Código Postal',
                      hintText: '01234-567',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericTextField(
                      controller: _country,
                      labelText: 'País',
                      hintText: 'Brasil, USA, etc.',
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Section 4: Contact
              _buildSectionTitle(context, '📞 Contato'),
              const SizedBox(height: 16),

              GenericEmailField(
                controller: _email,
                labelText: 'Email Corporativo',
                hintText: 'contato@empresa.com',
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GenericPhoneField(
                      controller: _phone,
                      labelText: 'Telefone',
                      hintText: '+55 (11) 1234-5678',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericPhoneField(
                      controller: _mobile,
                      labelText: 'Celular',
                      hintText: '+55 (11) 98765-4321',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _website,
                labelText: 'Website',
                hintText: 'https://www.empresa.com',
                enabled: !_saving,
              ),
              const SizedBox(height: 32),

              // Section 5: Branding
              _buildSectionTitle(context, '🎨 Branding'),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _logoUrl,
                labelText: 'URL do Logo',
                hintText: 'https://...',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _primaryColor,
                labelText: 'Cor Primária (Hex)',
                hintText: '#FF5733',
                enabled: !_saving,
              ),
              const SizedBox(height: 32),

              // Section 6: Invoice Settings
              _buildSectionTitle(context, '🧾 Configurações de Invoice'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GenericTextField(
                      controller: _invoicePrefix,
                      labelText: 'Prefixo de Invoice',
                      hintText: 'INV',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericTextField(
                      controller: _nextInvoiceNumber,
                      labelText: 'Próximo Número',
                      hintText: '1',
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _paymentTerms,
                labelText: 'Condições de Pagamento',
                hintText: 'Ex: Pagamento em 30 dias',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _invoiceNotes,
                labelText: 'Notas Padrão para Invoices',
                hintText: 'Texto que aparecerá em todas as invoices',
                enabled: !_saving,
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Section 7: Bank Information
              _buildSectionTitle(context, '🏦 Informações Bancárias'),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _bankName,
                labelText: 'Nome do Banco',
                hintText: 'Ex: Banco do Brasil',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GenericTextField(
                      controller: _bankBranch,
                      labelText: 'Agência',
                      hintText: '1234-5',
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericTextField(
                      controller: _bankAccount,
                      labelText: 'Conta',
                      hintText: '12345-6',
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _bankAccountType,
                labelText: 'Tipo de Conta',
                hintText: 'Corrente, Poupança, etc.',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              GenericTextField(
                controller: _pixKey,
                labelText: 'Chave PIX',
                hintText: 'CPF, CNPJ, Email, Telefone ou Chave Aleatória',
                enabled: !_saving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

