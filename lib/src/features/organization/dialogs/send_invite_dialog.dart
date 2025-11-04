import 'package:flutter/material.dart';
import '../../../../modules/modules.dart';
import '../../../../ui/atoms/inputs/inputs.dart';
import '../../../../ui/atoms/buttons/buttons.dart';
import '../../../../ui/molecules/dropdowns/dropdowns.dart';

/// Dialog para enviar convite para organização
class SendInviteDialog extends StatefulWidget {
  final String organizationId;

  const SendInviteDialog({
    super.key,
    required this.organizationId,
  });

  @override
  State<SendInviteDialog> createState() => _SendInviteDialogState();
}

class _SendInviteDialogState extends State<SendInviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'usuario';
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await organizationsModule.createOrganizationInvite(
        organizationId: widget.organizationId,
        email: _emailController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enviar Convite',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Email
              GenericEmailField(
                controller: _emailController,
                labelText: 'Email do convidado',
                hintText: 'usuario@exemplo.com',
                enabled: !_loading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email é obrigatório';
                  }
                  if (!value.contains('@')) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Role
              GenericDropdownField<String>(
                value: _selectedRole,
                items: const [
                  DropdownItem(value: 'usuario', label: 'Usuário'),
                  DropdownItem(value: 'designer', label: 'Designer'),
                  DropdownItem(value: 'financeiro', label: 'Financeiro'),
                  DropdownItem(value: 'gestor', label: 'Gestor'),
                  DropdownItem(value: 'admin', label: 'Administrador'),
                ],
                onChanged: _loading ? null : (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
                labelText: 'Função (Role)',
              ),
              const SizedBox(height: 8),
              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Um email será enviado com um link de convite. O convite expira em 7 dias.',
                        style: TextStyle(
                          color: Colors.blue[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SecondaryButton(
                    label: 'Cancelar',
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: 'Enviar Convite',
                    onPressed: _loading ? null : _sendInvite,
                    isLoading: _loading,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

