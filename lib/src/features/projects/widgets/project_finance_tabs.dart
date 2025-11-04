import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../state/app_state_scope.dart';
import 'project_financial_section.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

/// Widget com abas para financeiro do projeto
/// Aba 1: Financeiro geral do projeto (ProjectFinancialSection existente)
/// Aba 2: Pagamentos aos funcionários responsáveis pelas tasks
class ProjectFinanceTabs extends StatefulWidget {
  final String projectId;
  final String currencyCode;

  const ProjectFinanceTabs({
    super.key,
    required this.projectId,
    required this.currencyCode,
  });

  @override
  State<ProjectFinanceTabs> createState() => _ProjectFinanceTabsState();
}

class _ProjectFinanceTabsState extends State<ProjectFinanceTabs> {
  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final canAccessFullFinance = app.isOrgOwner || app.isAdmin || app.isFinanceiro || app.isGestor;

    // Se for Admin/Gestor/Financeiro: mostra ambas as abas
    if (canAccessFullFinance) {
      return Card(
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Financeiro',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Projeto'),
                  Tab(text: 'Funcionários'),
                ],
              ),
              const Divider(height: 1),
              SizedBox(
                height: 390,
                child: TabBarView(
                  children: [
                    // Aba 1: Financeiro do projeto (sem scroll externo)
                    ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ProjectFinancialSection(
                          projectId: widget.projectId,
                          currencyCode: widget.currencyCode,
                        ),
                      ),
                    ),
                    // Aba 2: Pagamentos aos funcionários
                    _EmployeePaymentsTab(
                      projectId: widget.projectId,
                      currencyCode: widget.currencyCode,
                      showOnlyCurrentUser: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Se for outro usuário (Designer, Cliente, Usuário): mostra apenas suas próprias informações
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Financeiro',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 390,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _EmployeePaymentsTab(
                projectId: widget.projectId,
                currencyCode: widget.currencyCode,
                showOnlyCurrentUser: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aba de pagamentos aos funcionários
class _EmployeePaymentsTab extends StatefulWidget {
  final String projectId;
  final String currencyCode;
  final bool showOnlyCurrentUser;

  const _EmployeePaymentsTab({
    required this.projectId,
    required this.currencyCode,
    this.showOnlyCurrentUser = false,
  });

  @override
  State<_EmployeePaymentsTab> createState() => _EmployeePaymentsTabState();
}

class _EmployeePaymentsTabState extends State<_EmployeePaymentsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      // Se showOnlyCurrentUser = true, filtrar apenas o usuário atual
      Set<String> employeeIds;

      if (widget.showOnlyCurrentUser && currentUserId != null) {
        // Mostrar apenas o usuário atual
        employeeIds = {currentUserId};
      } else {
        // Buscar todas as tasks do projeto com assigned_to e assignee_user_ids
        final tasksData = await supabase
            .from('tasks')
            .select('assigned_to, assignee_user_ids')
            .eq('project_id', widget.projectId);

        // Extrair IDs únicos de funcionários (de assigned_to e assignee_user_ids)
        employeeIds = <String>{};
        for (final task in tasksData) {
          // Adicionar assigned_to (responsável principal)
          final assignedTo = task['assigned_to'] as String?;
          if (assignedTo != null) {
            employeeIds.add(assignedTo);
          }

          // Adicionar assignee_user_ids (múltiplos responsáveis)
          final assigneeUserIds = (task['assignee_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
          for (final id in assigneeUserIds) {
            if (id.isNotEmpty) {
              employeeIds.add(id);
            }
          }
        }
      }

      // Buscar perfis de todos os funcionários únicos
      final employeesMap = <String, Map<String, dynamic>>{};
      if (employeeIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, full_name, email, avatar_url')
            .inFilter('id', employeeIds.toList());

        for (final profile in profilesResponse) {
          final id = profile['id'] as String;
          employeesMap[id] = {
            'id': id,
            'full_name': profile['full_name'] ?? 'Usuário',
            'email': profile['email'] ?? '',
            'avatar_url': profile['avatar_url'],
          };
        }
      }

      // Buscar pagamentos aos funcionários deste projeto
      var paymentsQuery = supabase
          .from('employee_payments')
          .select('*')
          .eq('project_id', widget.projectId);

      // Se showOnlyCurrentUser = true, filtrar apenas pagamentos do usuário atual
      if (widget.showOnlyCurrentUser && currentUserId != null) {
        paymentsQuery = paymentsQuery.eq('employee_id', currentUserId);
      }

      final paymentsData = await paymentsQuery.order('created_at', ascending: false);

      setState(() {
        _employees = employeesMap.values.toList();
        _payments = List<Map<String, dynamic>>.from(paymentsData);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _getCurrencySymbol() {
    switch (widget.currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'BRL':
      default:
        return 'R\$';
    }
  }

  String _formatMoney(int cents) {
    final value = cents / 100.0;
    return '${_getCurrencySymbol()} ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _deletePayment(String paymentId, String employeeName, int amountCents) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Pagamento'),
        content: Text(
          'Tem certeza que deseja excluir o pagamento de ${_formatMoney(amountCents)} para $employeeName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('employee_payments')
          .delete()
          .eq('id', paymentId);

      _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento excluído!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  Future<void> _confirmPayment(String paymentId) async {
    try {
      await Supabase.instance.client
          .from('employee_payments')
          .update({'status': 'confirmed'})
          .eq('id', paymentId);

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento confirmado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao confirmar: $e')),
        );
      }
    }
  }

  Future<void> _addPayment(String employeeId, String employeeName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddEmployeePaymentDialog(
        projectId: widget.projectId,
        employeeId: employeeId,
        employeeName: employeeName,
        currencyCode: widget.currencyCode,
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('Erro: $_error'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum funcionário atribuído às tasks deste projeto'),
        ),
      );
    }

    // Calcular total pago CONFIRMADO por funcionário
    final totalsByEmployee = <String, int>{};
    for (final payment in _payments) {
      if (payment['status'] == 'confirmed') {
        final empId = payment['employee_id'] as String;
        final amount = payment['amount_cents'] as int? ?? 0;
        totalsByEmployee[empId] = (totalsByEmployee[empId] ?? 0) + amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagamentos aos Funcionários',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Valores pagos diretamente aos funcionários por este projeto',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ...(_employees.map((employee) {
            final employeeId = employee['id'] as String;
            final totalPaid = totalsByEmployee[employeeId] ?? 0;
            final employeePayments = _payments
                .where((p) => p['employee_id'] == employeeId)
                .toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundImage: employee['avatar_url'] != null &&
                          (employee['avatar_url'] as String).isNotEmpty
                      ? NetworkImage(employee['avatar_url'] as String)
                      : null,
                  child: employee['avatar_url'] == null ||
                          (employee['avatar_url'] as String).isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(employee['full_name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total pago (confirmado): ${_formatMoney(totalPaid)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (employeePayments.isEmpty)
                      Text(
                        'Nenhum pagamento confirmado',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                // Botão "+" só aparece para Admin/Gestor/Financeiro (quando showOnlyCurrentUser = false)
                trailing: !widget.showOnlyCurrentUser
                    ? IconOnlyButton(
                        icon: Icons.add_circle_outline,
                        onPressed: () => _addPayment(employeeId, employee['full_name']),
                        tooltip: 'Adicionar pagamento',
                      )
                    : null,
                children: [
                  if (employeePayments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhum pagamento registrado'),
                    )
                  else
                    ...employeePayments.map((payment) {
                      final date = DateTime.parse(payment['created_at'] as String);
                      final status = payment['status'] as String? ?? 'pending';
                      final isConfirmed = status == 'confirmed';

                      return ListTile(
                        leading: Icon(
                          isConfirmed ? Icons.check_circle : Icons.pending,
                          color: isConfirmed
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Row(
                          children: [
                            Text(_formatMoney(payment['amount_cents'] as int)),
                            const SizedBox(width: 8),
                            if (isConfirmed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Confirmado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.tertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pendente',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                          '${payment['description'] != null ? ' • ${payment['description']}' : ''}',
                        ),
                        // Botões de ação só aparecem para Admin/Gestor/Financeiro
                        trailing: !widget.showOnlyCurrentUser
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isConfirmed)
                                    IconOnlyButton(
                                      icon: Icons.check,
                                      tooltip: 'Confirmar pagamento',
                                      onPressed: () => _confirmPayment(payment['id'] as String),
                                    ),
                                  IconOnlyButton(
                                    icon: Icons.delete_outline,
                                    tooltip: 'Excluir pagamento',
                                    iconColor: Theme.of(context).colorScheme.error,
                                    onPressed: () => _deletePayment(
                                      payment['id'] as String,
                                      employee['full_name'],
                                      payment['amount_cents'] as int,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    }),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }
}

/// Dialog para adicionar pagamento a funcionário
class _AddEmployeePaymentDialog extends StatefulWidget {
  final String projectId;
  final String employeeId;
  final String employeeName;
  final String currencyCode;

  const _AddEmployeePaymentDialog({
    required this.projectId,
    required this.employeeId,
    required this.employeeName,
    required this.currencyCode,
  });

  @override
  State<_AddEmployeePaymentDialog> createState() => _AddEmployeePaymentDialogState();
}

class _AddEmployeePaymentDialogState extends State<_AddEmployeePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int _parseCents(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d,.]'), '');
    final normalized = clean.replaceAll(',', '.');
    final value = double.tryParse(normalized) ?? 0.0;
    return (value * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Obter organization_id do projeto
      final userId = Supabase.instance.client.auth.currentUser?.id;
      String? organizationId;
      try {
        final project = await Supabase.instance.client
            .from('projects')
            .select('organization_id')
            .eq('id', widget.projectId)
            .maybeSingle();
        organizationId = project?['organization_id'] as String?;
      } catch (e) {
        // Silently fail - organization_id is optional for backward compatibility
      }

      await Supabase.instance.client.from('employee_payments').insert({
        'project_id': widget.projectId,
        'employee_id': widget.employeeId,
        'amount_cents': _parseCents(_amountController.text),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'status': 'pending',
        'created_by': userId,
        if (organizationId != null) 'organization_id': organizationId,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {

      if (!mounted) return;

      String errorMessage = 'Erro ao salvar pagamento';
      if (e.toString().contains('permission') || e.toString().contains('policy')) {
        errorMessage = 'Você não tem permissão para registrar pagamentos. Apenas Owner, Admin, Gestor e Financeiro podem fazer isso.';
      } else {
        errorMessage = 'Erro ao salvar: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() => _saving = false);
    }
  }

  String _getCurrencySymbol() {
    switch (widget.currencyCode.toUpperCase()) {
      case 'USD':
        return '\$ ';
      case 'EUR':
        return '€ ';
      case 'BRL':
      default:
        return 'R\$ ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pagamento para ${widget.employeeName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Valor',
                hintText: '0,00',
                prefixText: _getCurrencySymbol(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obrigatório';
                if (_parseCents(v) <= 0) return 'Valor deve ser maior que zero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Pagamento referente à task X',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

