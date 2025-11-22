import 'package:flutter/material.dart';
import 'package:my_business/ui/atoms/inputs/inputs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/organisms/dialogs/standard_dialog.dart';
import '../../../../modules/modules.dart';
import '../../../state/app_state_scope.dart';

/// Dialog para criar uma nova organização
class CreateOrganizationDialog extends StatefulWidget {
  const CreateOrganizationDialog({super.key});

  @override
  State<CreateOrganizationDialog> createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Campos obrigatórios
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();

  // Campos opcionais básicos
  final _legalNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _legalNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Gera um slug a partir do nome
  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Remove caracteres especiais
        .replaceAll(RegExp(r'\s+'), '-') // Substitui espaços por hífens
        .replaceAll(RegExp(r'-+'), '-') // Remove hífens duplicados
        .replaceAll(RegExp(r'^-|-$'), ''); // Remove hífens no início/fim
  }

  /// Atualiza o slug automaticamente quando o nome muda
  void _onNameChanged(String value) {
    if (_slugController.text.isEmpty || 
        _slugController.text == _generateSlug(_nameController.text)) {
      setState(() {
        _slugController.text = _generateSlug(value);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar se o usuário tem permissão (role admin)
    final appState = AppStateScope.of(context);
    if (!appState.isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Apenas administradores podem criar organizações'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    try {

      // Criar organização usando o módulo
      final newOrg = await organizationsModule.createOrganization(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
        legalName: _legalNameController.text.trim().isEmpty
            ? null
            : _legalNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );


      if (!mounted) return;

      // Atualizar lista de organizações no AppState
      await appState.refreshOrganizations();

      // Definir a nova organização como ativa
      await appState.setCurrentOrganization(newOrg['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organização "${_nameController.text}" criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar organização: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardDialog(
      title: 'Criar Nova Organização',
      width: StandardDialog.widthMedium,
      height: StandardDialog.heightSmall,
      isLoading: _saving,
      actions: [
        TextOnlyButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          label: 'Cancelar',
        ),
        PrimaryButton(
          onPressed: _saving ? null : _save,
          label: 'Criar Organização',
          icon: Icons.add_business,
          isLoading: _saving,
        ),
      ],
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informação
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3A3A3A),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2196F3),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você será o proprietário desta organização e poderá configurar todos os detalhes posteriormente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nome da Organização (obrigatório)
              GenericTextField(
                controller: _nameController,
                labelText: 'Nome da Organização *',
                hintText: 'Ex: Minha Empresa',
                enabled: !_saving,
                onChanged: _onNameChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  if (value.trim().length < 3) {
                    return 'Nome deve ter pelo menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Slug (obrigatório, gerado automaticamente)
              GenericTextField(
                controller: _slugController,
                labelText: 'Identificador Único (Slug) *',
                hintText: 'minha-empresa',
                enabled: !_saving,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Slug é obrigatório';
                  }
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                    return 'Slug deve conter apenas letras minúsculas, números e hífens';
                  }
                  if (value.length < 3) {
                    return 'Slug deve ter pelo menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'O slug é gerado automaticamente a partir do nome, mas você pode personalizá-lo.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),

              // Divisor
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 16),

              // Campos opcionais
              Text(
                'Informações Adicionais (Opcional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),

              // Razão Social (opcional)
              GenericTextField(
                controller: _legalNameController,
                labelText: 'Razão Social',
                hintText: 'Nome legal completo da empresa',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              // Email (opcional)
              GenericEmailField(
                controller: _emailController,
                labelText: 'Email Corporativo',
                hintText: 'contato@empresa.com',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              // Telefone (opcional)
              GenericPhoneField(
                controller: _phoneController,
                labelText: 'Telefone',
                hintText: '+55 (11) 1234-5678',
                enabled: !_saving,
              ),
              const SizedBox(height: 16),

              // Nota final
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings,
                      color: Color(0xFF9E9E9E),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Você poderá adicionar mais informações (endereço, dados bancários, etc.) nas configurações da organização.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
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

