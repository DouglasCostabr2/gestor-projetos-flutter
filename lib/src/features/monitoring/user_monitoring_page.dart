import 'package:flutter/material.dart';
import '../../state/app_state_scope.dart';
import 'widgets/user_monitoring_card.dart';
import '../../../modules/modules.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/ui/atoms/loaders/loaders.dart';

/// Página de monitoramento de usuários
/// Exibe cards com informações sobre o que cada usuário está fazendo
/// Acesso restrito: Apenas Admin e Gestor
class UserMonitoringPage extends StatefulWidget {
  const UserMonitoringPage({super.key});

  @override
  State<UserMonitoringPage> createState() => _UserMonitoringPageState();
}

class _UserMonitoringPageState extends State<UserMonitoringPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  DateTime? _lastUpdate;
  
  // Filtros e ordenação
  String _searchQuery = '';
  String? _selectedRole;
  String _sortBy = 'name';
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// Constrói skeleton loading para a página de monitoramento
  Widget _buildMonitoringSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + Nome skeleton
                  Row(
                    children: [
                      SkeletonLoader.circle(size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader.text(width: 120),
                            const SizedBox(height: 8),
                            SkeletonLoader.text(width: 80),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Informações skeleton
                  SkeletonLoader.text(width: double.infinity),
                  const SizedBox(height: 8),
                  SkeletonLoader.text(width: 150),
                  const SizedBox(height: 8),
                  SkeletonLoader.text(width: 200),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Usando o módulo de monitoramento
      final users = await monitoringModule.fetchMonitoringData();

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = _allUsers;

      // Aplicar filtro de role
      filtered = monitoringModule.filterByRole(filtered, _selectedRole);

      // Aplicar busca
      filtered = monitoringModule.filterBySearch(filtered, _searchQuery);

      // Aplicar ordenação
      filtered = monitoringModule.sortUsers(filtered, _sortBy);
      
      _filteredUsers = filtered;
    });
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'designer':
        return 'Designer';
      case 'financeiro':
        return 'Financeiro';
      case 'cliente':
        return 'Cliente';
      default:
        return 'Convidado';
    }
  }

  String _formatMoney(int cents) {
    final value = cents / 100.0;
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    // Verificar permissão: apenas Admin e Gestor
    if (!appState.isAdmin && !appState.isGestor) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Acesso Negado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apenas Administradores e Gestores podem acessar o Monitoramento de Usuários.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Header com filtros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Monitoramento de Usuários',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    if (_lastUpdate != null)
                      Text(
                        'Atualizado: ${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    const SizedBox(width: 16),
                    IconOnlyButton(
                      icon: Icons.refresh,
                      onPressed: _loadUsers,
                      tooltip: 'Atualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtros
                Row(
                  children: [
                    // Busca
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar usuário',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtro por role
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por papel',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Todos')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                          DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
                          DropdownMenuItem(value: 'designer', child: Text('Designer')),
                          DropdownMenuItem(value: 'financeiro', child: Text('Financeiro')),
                          DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Ordenação
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sortBy,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar por',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'name', child: Text('Nome')),
                          DropdownMenuItem(value: 'pending_tasks', child: Text('Tasks Pendentes')),
                          DropdownMenuItem(value: 'completed_tasks', child: Text('Tasks Concluídas')),
                          DropdownMenuItem(value: 'overdue_tasks', child: Text('Tasks Atrasadas')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Conteúdo
          Expanded(
            child: _loading
                ? _buildMonitoringSkeleton()
                : _error != null
                    ? Center(
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
                              onPressed: _loadUsers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum usuário encontrado',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _filteredUsers.map((user) {
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 380,
                                    maxWidth: 380,
                                    minHeight: 300,
                                  ),
                                  child: IntrinsicHeight(
                                    child: UserMonitoringCard(
                                      user: user,
                                      getRoleLabel: _getRoleLabel,
                                      formatMoney: _formatMoney,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

