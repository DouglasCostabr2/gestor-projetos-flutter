import 'package:flutter/material.dart';

import '../../state/app_state_scope.dart';
import '../projects/project_detail_page.dart';
import '../../../ui/organisms/dialogs/dialogs.dart';
import '../../../modules/modules.dart';
import '../../navigation/tab_manager_scope.dart';
import '../../navigation/tab_item.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final canAccess = app.isAdmin || app.isGestor || app.isFinanceiro;
    if (!canAccess) return const SizedBox.shrink();

    return Column(
      children: [
        // Header com título e abas
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Text('Financeiro', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
            ],
          ),
        ),
        // TabBar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Clientes'),
            Tab(text: 'Funcionários'),
          ],
        ),
        // TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ClientsFinanceTab(),
              _EmployeesFinanceTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// Aba de Clientes - Pagamentos recebidos de clientes
class _ClientsFinanceTab extends StatefulWidget {
  const _ClientsFinanceTab();

  @override
  State<_ClientsFinanceTab> createState() => _ClientsFinanceTabState();
}

class _ClientsFinanceTabState extends State<_ClientsFinanceTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {

      // Buscar todos os clientes usando o módulo
      final clientsData = await clientsModule.getClients();


      final clients = <Map<String, dynamic>>[];

      for (final client in clientsData) {
        final clientId = client['id'] as String;

        // Buscar todos os projetos do cliente usando o módulo
        final projectsData = await projectsModule.getProjectsByClient(clientId);


        // Buscar pagamentos de todos os projetos do cliente
        final projectIds = projectsData.map((p) => p['id'] as String).toList();

        List<dynamic> paymentsData = [];
        if (projectIds.isNotEmpty) {
          // Usando o módulo de finanças para buscar pagamentos
          paymentsData = await financeModule.getPaymentsByProjects(projectIds);

        }

        // Calcular valor total dos projetos por moeda
        Map<String, int> projectValueByCurrency = {};
        for (final project in projectsData) {
          final currency = (project['currency_code'] as String?) ?? 'BRL';
          final valueCents = (project['value_cents'] as int?) ?? 0;
          projectValueByCurrency[currency] = (projectValueByCurrency[currency] ?? 0) + valueCents;
        }

        // Agrupar pagamentos recebidos por moeda
        Map<String, int> receivedByCurrency = {};
        Map<String, List<Map<String, dynamic>>> paymentsByCurrency = {};

        for (final payment in paymentsData) {
          final project = payment['projects'] as Map<String, dynamic>?;
          final currency = (project?['currency_code'] as String?) ?? 'BRL';
          final amountCents = (payment['amount_cents'] as int?) ?? 0;

          receivedByCurrency[currency] = (receivedByCurrency[currency] ?? 0) + amountCents;
          paymentsByCurrency[currency] = (paymentsByCurrency[currency] ?? [])..add(payment);
        }

        // Calcular valores pendentes por moeda
        Map<String, int> pendingByCurrency = {};
        for (final currency in projectValueByCurrency.keys) {
          final total = projectValueByCurrency[currency] ?? 0;
          final received = receivedByCurrency[currency] ?? 0;
          final pending = total - received;
          if (pending > 0) {
            pendingByCurrency[currency] = pending;
          }
        }

        // Adicionar cliente mesmo sem pagamentos
        clients.add({
          'id': clientId,
          'name': client['name'] ?? 'Cliente',
          'email': client['email'] ?? '',
          'avatar_url': client['avatar_url'], // Avatar do cliente
          'project_value_by_currency': projectValueByCurrency,
          'received_by_currency': receivedByCurrency,
          'pending_by_currency': pendingByCurrency,
          'payments_by_currency': paymentsByCurrency,
          'total_payments': paymentsData.length,
        });
      }


      setState(() {
        _clients = clients;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'BRL':
      default:
        return 'R\$';
    }
  }

  String _formatMoneyWithCurrency(int cents, String currency) {
    final value = cents / 100.0;
    final symbol = _getCurrencySymbol(currency);
    return '$symbol ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clients.isEmpty) {
      return const Center(
        child: Text('Nenhum cliente encontrado'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _clients.map((client) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 380,
              maxWidth: 380,
              minHeight: 300,
            ),
            child: IntrinsicHeight(
              child: _ClientFinanceCard(
                client: client,
                formatMoney: _formatMoneyWithCurrency,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


// Card de Cliente
class _ClientFinanceCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final String Function(int, String) formatMoney;

  const _ClientFinanceCard({
    required this.client,
    required this.formatMoney,
  });

  void _showPendingModal(BuildContext context, String currency) async {
    // Buscar projetos do cliente com a moeda específica
    final clientId = client['id'] as String;

    try {
      // Buscar projetos do cliente nesta moeda usando o módulo
      final projectsData = await projectsModule.getProjectsByClientWithCurrency(
        clientId: clientId,
        currencyCode: currency,
      );

      // Para cada projeto, buscar pagamentos
      final projectsWithPending = <Map<String, dynamic>>[];

      for (final project in projectsData) {
        final projectId = project['id'] as String;
        final projectName = project['name'] as String;
        final projectValue = (project['value_cents'] as int?) ?? 0;

        // Buscar pagamentos deste projeto
        final paymentsData = await financeModule.getProjectPayments(projectId);

        // Calcular total recebido
        int receivedValue = 0;
        for (final payment in paymentsData) {
          receivedValue += (payment['amount_cents'] as int?) ?? 0;
        }

        final pendingValue = projectValue - receivedValue;

        // Adicionar apenas se tiver valor pendente
        if (pendingValue > 0) {
          projectsWithPending.add({
            'id': projectId,
            'name': projectName,
            'project_value': projectValue,
            'received_value': receivedValue,
            'pending_value': pendingValue,
          });
        }
      }

      if (!context.mounted) return;

      // Capturar TabManager ANTES de abrir o dialog
      final tabManager = TabManagerScope.maybeOf(context);

      DialogHelper.show(
        context: context,
        builder: (dialogContext) => StandardDialog(
          title: 'Valores Pendentes - ${client['name']} ($currency)',
          width: StandardDialog.widthMedium,
          height: StandardDialog.heightMedium,
          child: projectsWithPending.isEmpty
              ? const Center(child: Text('Nenhum valor pendente encontrado'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: projectsWithPending.length,
                  itemBuilder: (listContext, index) {
                    final project = projectsWithPending[index];
                    final projectId = project['id'] as String;
                    final projectName = project['name'] as String;
                    final pendingValue = project['pending_value'] as int;

                    return ListTile(
                      leading: Icon(
                        Icons.pending,
                        color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(projectName),
                      subtitle: Text(formatMoney(pendingValue, currency)),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        Navigator.pop(dialogContext);

                        // Usar TabManager capturado ANTES do dialog
                        if (tabManager != null) {
                          final tabId = 'project_$projectId';
                          final currentIndex = tabManager.currentIndex;
                          final updatedTab = TabItem(
                            id: tabId,
                            title: projectName,
                            icon: Icons.folder,
                            page: ProjectDetailPage(
                              key: ValueKey('project_$projectId'),
                              projectId: projectId,
                            ),
                            canClose: true,
                          );
                          tabManager.updateTab(currentIndex, updatedTab);
                        } else {
                          // Fallback
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectDetailPage(projectId: projectId),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar projetos: $e')),
        );
      }
    }
  }

  void _showPaymentsModal(BuildContext context, String currency) {
    final payments = (client['payments_by_currency'] as Map<String, List<Map<String, dynamic>>>)[currency] ?? [];

    // Capturar TabManager ANTES de abrir o dialog
    final tabManager = TabManagerScope.maybeOf(context);

    DialogHelper.show(
      context: context,
      builder: (dialogContext) => StandardDialog(
        title: 'Pagamentos de ${client['name']} ($currency)',
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
        ],
        child: payments.isEmpty
            ? const Center(child: Text('Nenhum pagamento encontrado'))
            : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        itemBuilder: (listContext, index) {
                          final payment = payments[index];
                          final project = payment['projects'] as Map<String, dynamic>?;
                          final projectId = payment['project_id'] as String?;
                          final projectName = project?['name'] ?? 'Projeto';
                          final amountCents = (payment['amount_cents'] as int?) ?? 0;
                          final value = formatMoney(amountCents, currency);

                          return ListTile(
                            leading: Icon(
                              Icons.payments,
                              color: Theme.of(dialogContext).colorScheme.tertiary,
                            ),
                            title: Text(value),
                            subtitle: Text(projectName),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: projectId != null
                                ? () {
                                    Navigator.pop(dialogContext);

                                    // Usar TabManager capturado ANTES do dialog
                                    if (tabManager != null) {
                                      final tabId = 'project_$projectId';
                                      final currentIndex = tabManager.currentIndex;
                                      final updatedTab = TabItem(
                                        id: tabId,
                                        title: projectName,
                                        icon: Icons.folder,
                                        page: ProjectDetailPage(
                                          key: ValueKey('project_$projectId'),
                                          projectId: projectId,
                                        ),
                                        canClose: true,
                                      );
                                      tabManager.updateTab(currentIndex, updatedTab);
                                    } else {
                                      // Fallback
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProjectDetailPage(projectId: projectId),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectValueByCurrency = client['project_value_by_currency'] as Map<String, int>;
    final receivedByCurrency = client['received_by_currency'] as Map<String, int>;
    final pendingByCurrency = client['pending_by_currency'] as Map<String, int>;
    final totalPayments = client['total_payments'] as int;
    final avatarUrl = client['avatar_url'] as String?;
    final name = client['name'] as String;

    // Todas as moedas do sistema
    const allCurrencies = ['BRL', 'USD', 'EUR'];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com avatar e nome
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client['name'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (client['email'] != null && (client['email'] as String).isNotEmpty)
                        Text(
                          client['email'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Total de pagamentos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.payments,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total de Pagamentos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  totalPayments.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Sanfonas por moeda
          ...allCurrencies.map((currency) {
            final projectValue = projectValueByCurrency[currency] ?? 0;
            final receivedValue = receivedByCurrency[currency] ?? 0;
            final pendingValue = pendingByCurrency[currency] ?? 0;
            final hasReceived = receivedValue > 0;
            final hasPending = pendingValue > 0;

            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              title: Row(
                children: [
                  Text(
                    currency,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (projectValue > 0)
                    Text(
                      formatMoney(projectValue, currency),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
              children: [
                // Recebido (clicável)
                InkWell(
                  onTap: hasReceived ? () => _showPaymentsModal(context, currency) : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Recebido'),
                        ),
                        Text(
                          formatMoney(receivedValue, currency),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                        SizedBox(
                          width: 24,
                          child: hasReceived
                              ? Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                // Pendente (clicável)
                InkWell(
                  onTap: hasPending ? () => _showPendingModal(context, currency) : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Pendente'),
                        ),
                        Text(
                          formatMoney(pendingValue, currency),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SizedBox(
                          width: 24,
                          child: hasPending
                              ? Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}


// Aba de Funcionários - Pagamentos feitos para funcionários
class _EmployeesFinanceTab extends StatefulWidget {
  const _EmployeesFinanceTab();

  @override
  State<_EmployeesFinanceTab> createState() => _EmployeesFinanceTabState();
}

class _EmployeesFinanceTabState extends State<_EmployeesFinanceTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Buscar todos os perfis (funcionários) usando o módulo
      final profilesData = await usersModule.getEmployeeProfiles();

      final employees = <Map<String, dynamic>>[];

      for (final profile in profilesData) {
        final employeeId = profile['id'] as String;

        // Buscar pagamentos do funcionário
        final employeePayments = await financeModule.getEmployeePayments(employeeId);

        // Agrupar por moeda e status
        Map<String, int> confirmedByCurrency = {};
        Map<String, int> pendingByCurrency = {};
        Map<String, List<Map<String, dynamic>>> confirmedPaymentsByCurrency = {};
        Map<String, List<Map<String, dynamic>>> pendingPaymentsByCurrency = {};

        for (final payment in employeePayments) {
          final project = payment['projects'] as Map<String, dynamic>?;
          final currency = (project?['currency_code'] as String?) ?? 'BRL';
          final amountCents = (payment['amount_cents'] as int?) ?? 0;
          final status = payment['status'] as String?;

          if (status == 'confirmed') {
            confirmedByCurrency[currency] = (confirmedByCurrency[currency] ?? 0) + amountCents;
            confirmedPaymentsByCurrency[currency] = (confirmedPaymentsByCurrency[currency] ?? [])..add(payment);
          } else {
            pendingByCurrency[currency] = (pendingByCurrency[currency] ?? 0) + amountCents;
            pendingPaymentsByCurrency[currency] = (pendingPaymentsByCurrency[currency] ?? [])..add(payment);
          }
        }

        // Adicionar funcionário mesmo sem pagamentos
        employees.add({
          'id': employeeId,
          'full_name': profile['full_name'] ?? 'Funcionário',
          'email': profile['email'] ?? '',
          'avatar_url': profile['avatar_url'],
          'role': profile['role'] ?? '',
          'confirmed_by_currency': confirmedByCurrency,
          'pending_by_currency': pendingByCurrency,
          'confirmed_payments_by_currency': confirmedPaymentsByCurrency,
          'pending_payments_by_currency': pendingPaymentsByCurrency,
          'total_payments': employeePayments.length,
        });
      }

      setState(() {
        _employees = employees;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'BRL':
      default:
        return 'R\$';
    }
  }

  String _formatMoneyWithCurrency(int cents, String currency) {
    final value = cents / 100.0;
    final symbol = _getCurrencySymbol(currency);
    return '$symbol ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_employees.isEmpty) {
      return const Center(
        child: Text('Nenhum funcionário encontrado'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _employees.map((employee) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 380,
              maxWidth: 380,
              minHeight: 300,
            ),
            child: IntrinsicHeight(
              child: _EmployeeFinanceCard(
                employee: employee,
                formatMoney: _formatMoneyWithCurrency,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}


// Card de Funcionário (com sanfonas como o card de clientes)
class _EmployeeFinanceCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final String Function(int, String) formatMoney;

  const _EmployeeFinanceCard({
    required this.employee,
    required this.formatMoney,
  });

  void _showPaymentsModal(BuildContext context, String currency, String status) {
    final paymentsKey = status == 'confirmed'
        ? 'confirmed_payments_by_currency'
        : 'pending_payments_by_currency';
    final payments = (employee[paymentsKey] as Map<String, List<Map<String, dynamic>>>)[currency] ?? [];
    final statusLabel = status == 'confirmed' ? 'Pagos' : 'Pendentes';

    // Capturar TabManager ANTES de abrir o dialog
    final tabManager = TabManagerScope.maybeOf(context);

    DialogHelper.show(
      context: context,
      builder: (dialogContext) => StandardDialog(
        title: 'Pagamentos $statusLabel - ${employee['full_name']} ($currency)',
        width: StandardDialog.widthMedium,
        height: StandardDialog.heightMedium,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
        ],
        child: payments.isEmpty
            ? const Center(child: Text('Nenhum pagamento encontrado'))
            : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        itemBuilder: (listContext, index) {
                          final payment = payments[index];
                          final project = payment['projects'] as Map<String, dynamic>?;
                          final projectId = payment['project_id'] as String?;
                          final projectName = project?['name'] ?? 'Projeto';
                          final amountCents = (payment['amount_cents'] as int?) ?? 0;
                          final value = formatMoney(amountCents, currency);
                          final description = payment['description'] as String?;
                          final isConfirmed = status == 'confirmed';

                          return ListTile(
                            leading: Icon(
                              isConfirmed ? Icons.check_circle : Icons.pending,
                              color: isConfirmed
                                  ? Theme.of(dialogContext).colorScheme.tertiary
                                  : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                            ),
                            title: Text(value),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(projectName),
                                if (description != null && description.isNotEmpty)
                                  Text(
                                    description,
                                    style: Theme.of(dialogContext).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: projectId != null
                                ? () {
                                    Navigator.pop(dialogContext);

                                    // Usar TabManager capturado ANTES do dialog
                                    if (tabManager != null) {
                                      final tabId = 'project_$projectId';
                                      final currentIndex = tabManager.currentIndex;
                                      final updatedTab = TabItem(
                                        id: tabId,
                                        title: projectName,
                                        icon: Icons.folder,
                                        page: ProjectDetailPage(
                                          key: ValueKey('project_$projectId'),
                                          projectId: projectId,
                                        ),
                                        canClose: true,
                                      );
                                      tabManager.updateTab(currentIndex, updatedTab);
                                    } else {
                                      // Fallback
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProjectDetailPage(projectId: projectId),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmedByCurrency = employee['confirmed_by_currency'] as Map<String, int>;
    final pendingByCurrency = employee['pending_by_currency'] as Map<String, int>;
    final totalPayments = employee['total_payments'] as int;
    final avatarUrl = employee['avatar_url'] as String?;
    final fullName = employee['full_name'] as String;

    // Todas as moedas do sistema
    const allCurrencies = ['BRL', 'USD', 'EUR'];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com avatar e nome
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          fullName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['full_name'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (employee['role'] != null && (employee['role'] as String).isNotEmpty)
                        Text(
                          employee['role'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Total de pagamentos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.payments,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total de Pagamentos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  totalPayments.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Sanfonas por moeda
          ...allCurrencies.map((currency) {
            final confirmedValue = confirmedByCurrency[currency] ?? 0;
            final pendingValue = pendingByCurrency[currency] ?? 0;
            final totalValue = confirmedValue + pendingValue;
            final hasConfirmed = confirmedValue > 0;
            final hasPending = pendingValue > 0;

            return ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              title: Row(
                children: [
                  Text(
                    currency,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (totalValue > 0)
                    Text(
                      formatMoney(totalValue, currency),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
              children: [
                // Pago (clicável)
                InkWell(
                  onTap: hasConfirmed ? () => _showPaymentsModal(context, currency, 'confirmed') : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Pago'),
                        ),
                        Text(
                          formatMoney(confirmedValue, currency),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                        ),
                        SizedBox(
                          width: 24,
                          child: hasConfirmed
                              ? Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                // Pendente (clicável)
                InkWell(
                  onTap: hasPending ? () => _showPaymentsModal(context, currency, 'pending') : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Pendente'),
                        ),
                        Text(
                          formatMoney(pendingValue, currency),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SizedBox(
                          width: 24,
                          child: hasPending
                              ? Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

