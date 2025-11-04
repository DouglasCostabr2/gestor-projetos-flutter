import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../modules/modules.dart';
import '../../../state/app_state_scope.dart';
import '../../../../ui/atoms/inputs/inputs.dart';

/// Página de Configurações de Invoice da Organização
class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Invoice Settings
  final _invoicePrefixController = TextEditingController();
  final _nextInvoiceNumberController = TextEditingController();
  final _invoiceNotesController = TextEditingController();
  final _invoiceTermsController = TextEditingController();

  bool _initialized = false;

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
    _invoicePrefixController.dispose();
    _nextInvoiceNumberController.dispose();
    _invoiceNotesController.dispose();
    _invoiceTermsController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    setState(() => _loading = true);
    try {
      final appState = AppStateScope.of(context);
      final org = appState.currentOrganization;

      if (org != null) {
        _invoicePrefixController.text = org['invoice_prefix'] ?? '';
        _nextInvoiceNumberController.text = org['next_invoice_number']?.toString() ?? '1';
        _invoiceNotesController.text = org['invoice_notes'] ?? '';
        _invoiceTermsController.text = org['invoice_terms'] ?? '';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;
      if (orgId == null) throw Exception('Nenhuma organização ativa');

      await organizationsModule.updateOrganization(
        organizationId: orgId,
        invoicePrefix: _invoicePrefixController.text.trim().isEmpty ? null : _invoicePrefixController.text.trim(),
        nextInvoiceNumber: _nextInvoiceNumberController.text.trim().isEmpty ? null : int.tryParse(_nextInvoiceNumberController.text.trim()),
        invoiceNotes: _invoiceNotesController.text.trim().isEmpty ? null : _invoiceNotesController.text.trim(),
        invoiceTerms: _invoiceTermsController.text.trim().isEmpty ? null : _invoiceTermsController.text.trim(),
      );

      // Atualizar organização no AppState
      await appState.refreshOrganizations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações de invoice atualizadas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
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
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canEdit = appState.canManageOrganization;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.description, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações de Invoice',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure numeração, notas e termos para suas invoices',
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

              // Invoice Settings
              Row(
                children: [
                  Expanded(
                    child: GenericTextField(
                      controller: _invoicePrefixController,
                      labelText: 'Prefixo da Invoice',
                      enabled: canEdit && !_saving,
                      hintText: 'Ex: INV',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GenericTextField(
                      controller: _nextInvoiceNumberController,
                      labelText: 'Próximo Número',
                      enabled: canEdit && !_saving,
                      hintText: 'Ex: 1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GenericTextField(
                controller: _invoiceNotesController,
                labelText: 'Notas da Invoice',
                enabled: canEdit && !_saving,
                hintText: 'Notas que aparecerão em todas as invoices',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              GenericTextField(
                controller: _invoiceTermsController,
                labelText: 'Termos de Pagamento',
                enabled: canEdit && !_saving,
                hintText: 'Ex: Pagamento em 30 dias',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Save Button
              if (canEdit)
                Row(
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
            ],
          ),
        ),
      ),
    );
  }
}

