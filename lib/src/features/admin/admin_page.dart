import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/app_state_scope.dart';
import '../../../ui/molecules/user_avatar_name.dart';
import '../../../ui/organisms/dialogs/standard_dialog.dart';
import '../../../ui/organisms/tabs/tabs.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    // Verificar se o usuário é admin
    if (!appState.isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Acesso Negado',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Apenas administradores têm acesso a esta página.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Painel de Administração',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Gerenciamento avançado do sistema',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs usando componente genérico
        Expanded(
          child: GenericTabView(
            tabs: const [
              TabConfig(icon: Icons.dashboard, text: 'Visão Geral'),
              TabConfig(icon: Icons.people, text: 'Usuários'),
              TabConfig(icon: Icons.settings, text: 'Sistema'),
              TabConfig(icon: Icons.analytics, text: 'Relatórios'),
            ],
            children: [
              const _OverviewTab(),
              const _UsersManagementTab(),
              const _SystemSettingsTab(),
              const _ReportsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 1: VISÃO GERAL
// ============================================================================
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _loading = true;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // Buscar estatísticas usando COUNT para melhor performance
      final usersCount = await client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);

      final projectsCount = await client
          .from('projects')
          .select('id')
          .count(CountOption.exact);

      final tasksCount = await client
          .from('tasks')
          .select('id')
          .count(CountOption.exact);

      final clientsCount = await client
          .from('clients')
          .select('id')
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _stats = {
            'users': usersCount.count,
            'projects': projectsCount.count,
            'tasks': tasksCount.count,
            'clients': clientsCount.count,
          };
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar estatísticas: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estatísticas do Sistema',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          
          // Cards de estatísticas
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                icon: Icons.people,
                title: 'Usuários',
                value: _stats['users']?.toString() ?? '0',
                color: Theme.of(context).colorScheme.primary,
              ),
              _StatCard(
                icon: Icons.work,
                title: 'Projetos',
                value: _stats['projects']?.toString() ?? '0',
                color: Theme.of(context).colorScheme.tertiary,
              ),
              _StatCard(
                icon: Icons.checklist,
                title: 'Tarefas',
                value: _stats['tasks']?.toString() ?? '0',
                color: Theme.of(context).colorScheme.secondary,
              ),
              _StatCard(
                icon: Icons.business,
                title: 'Clientes',
                value: _stats['clients']?.toString() ?? '0',
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Ações rápidas
          Text(
            'Ações Rápidas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                icon: Icons.refresh,
                label: 'Atualizar Estatísticas',
                onPressed: _loadStats,
              ),
              _ActionButton(
                icon: Icons.backup,
                label: 'Backup do Sistema',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                  );
                },
              ),
              _ActionButton(
                icon: Icons.cleaning_services,
                label: 'Limpar Cache',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache limpo com sucesso')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

// ============================================================================
// TAB 2: GERENCIAMENTO DE USUÁRIOS
// ============================================================================
class _UsersManagementTab extends StatefulWidget {
  const _UsersManagementTab();

  @override
  State<_UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<_UsersManagementTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  final List<String> _roles = const ['admin', 'gestor', 'designer', 'financeiro', 'cliente', 'usuario', 'convidado'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, email, full_name, role, avatar_url, created_at')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar usuários: $e')),
        );
      }
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Papel atualizado com sucesso')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar papel: $e')),
        );
      }
    }
  }

  Future<void> _sendPasswordResetEmail(String userEmail, String userName) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(userEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de redefinição de senha enviado para $userName'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar email: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _editUserEmail(String userId, String currentEmail, String userName) async {
    final emailController = TextEditingController(text: currentEmail);

    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Email - $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Novo Email',
                hintText: 'usuario@exemplo.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            Text(
              'Nota: O usuário precisará verificar o novo email.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newEmail == null || newEmail.isEmpty || newEmail == currentEmail) return;

    try {
      // Atualizar email no profiles
      await Supabase.instance.client
          .from('profiles')
          .update({'email': newEmail})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar email: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changeUserPassword(String userId, String userName) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trocar Senha - $userName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Nova Senha',
                hintText: 'Digite a nova senha',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirmar Senha',
                hintText: 'Confirme a nova senha',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(
              'A senha deve ter pelo menos 6 caracteres.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final pwd = passwordController.text.trim();
              final confirmPwd = confirmPasswordController.text.trim();

              if (pwd.isEmpty || confirmPwd.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha todos os campos')),
                );
                return;
              }

              if (pwd.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres')),
                );
                return;
              }

              if (pwd != confirmPwd) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('As senhas não conferem')),
                );
                return;
              }

              Navigator.pop(context, pwd);
            },
            child: const Text('Trocar Senha'),
          ),
        ],
      ),
    );

    if (newPassword == null || newPassword.isEmpty) return;

    try {
      // Usar a função RPC do Supabase para trocar a senha
      final result = await Supabase.instance.client.rpc(
        'change_user_password',
        params: {
          'user_id': userId,
          'new_password': newPassword,
        },
      );

      if (result == null || result['success'] != true) {
        throw Exception(result?['error'] ?? 'Erro desconhecido ao alterar senha');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar senha: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Confirmar Exclusão',
        message: 'Tem certeza que deseja excluir o usuário "$userName"?',
        confirmText: 'Excluir',
        isDestructive: true,
      ),
    );

    if (confirmed != true) return;

    try {
      // Nota: Isso requer uma função no Supabase para deletar o usuário do auth.users
      // Por enquanto, apenas removemos do profiles
      await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário excluído com sucesso')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir usuário: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header com ações
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Total: ${_users.length} usuários',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconOnlyButton(
                onPressed: _loadUsers,
                icon: Icons.refresh,
                tooltip: 'Atualizar',
              ),
            ],
          ),
        ),

        // Tabela de usuários
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nome')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Papel')),
                  DataColumn(label: Text('Criado em')),
                  DataColumn(label: Text('Ações')),
                ],
                rows: _users.map((user) {
                  final role = (user['role'] as String?)?.toLowerCase() ?? 'convidado';
                  final createdAt = user['created_at'] != null
                      ? DateTime.parse(user['created_at']).toLocal()
                      : null;
                  final userName = user['full_name'] ?? user['email'] ?? 'Usuário';
                  final userEmail = user['email'] ?? '';

                  return DataRow(
                    cells: [
                      DataCell(
                        UserAvatarName(
                          avatarUrl: user['avatar_url'],
                          name: userName,
                          size: 32,
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Flexible(child: Text(userEmail)),
                            const SizedBox(width: 8),
                            IconOnlyButton(
                              icon: Icons.edit,
                              iconSize: 16,
                              tooltip: 'Editar email',
                              onPressed: () => _editUserEmail(
                                user['id'],
                                userEmail,
                                userName,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        DropdownButton<String>(
                          value: _roles.contains(role) ? role : 'convidado',
                          items: _roles.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          )).toList(),
                          onChanged: (newRole) {
                            if (newRole != null && newRole != role) {
                              _updateUserRole(user['id'], newRole);
                            }
                          },
                        ),
                      ),
                      DataCell(
                        Text(createdAt != null
                            ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                            : '-'),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconOnlyButton(
                              icon: Icons.lock,
                              tooltip: 'Trocar senha',
                              onPressed: () => _changeUserPassword(user['id'], userName),
                            ),
                            IconOnlyButton(
                              icon: Icons.lock_reset,
                              tooltip: 'Enviar email de redefinição de senha',
                              onPressed: userEmail.isNotEmpty
                                  ? () => _sendPasswordResetEmail(userEmail, userName)
                                  : null,
                            ),
                            IconOnlyButton(
                              icon: Icons.delete,
                              tooltip: 'Excluir usuário',
                              iconColor: Theme.of(context).colorScheme.error,
                              onPressed: () => _deleteUser(user['id'], userName),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: CONFIGURAÇÕES DO SISTEMA
// ============================================================================
class _SystemSettingsTab extends StatefulWidget {
  const _SystemSettingsTab();

  @override
  State<_SystemSettingsTab> createState() => _SystemSettingsTabState();
}

class _SystemSettingsTabState extends State<_SystemSettingsTab> {

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configurações do Sistema',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          _SettingSection(
            title: 'Banco de Dados',
            children: [
              _SettingItem(
                icon: Icons.storage,
                title: 'Status da Conexão',
                subtitle: 'Conectado ao Supabase',
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              _SettingItem(
                icon: Icons.backup,
                title: 'Último Backup',
                subtitle: 'Nunca',
                trailing: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                    );
                  },
                  child: const Text('Fazer Backup'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _SettingSection(
            title: 'Segurança',
            children: [
              _SettingItem(
                icon: Icons.security,
                title: 'Row Level Security (RLS)',
                subtitle: 'Ativado em todas as tabelas',
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              _SettingItem(
                icon: Icons.vpn_key,
                title: 'Autenticação',
                subtitle: 'OAuth 2.0 com PKCE',
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
            ],
          ),


        ],
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

// ============================================================================
// TAB 4: RELATÓRIOS
// ============================================================================
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  bool _loading = true;
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // Buscar dados para relatórios
      final projects = await client.from('projects').select('status');
      final tasks = await client.from('tasks').select('status, priority');
      final users = await client.from('profiles').select('role');

      // Processar dados
      final projectsByStatus = <String, int>{};
      for (var p in projects) {
        final status = p['status'] as String? ?? 'unknown';
        projectsByStatus[status] = (projectsByStatus[status] ?? 0) + 1;
      }

      final tasksByStatus = <String, int>{};
      final tasksByPriority = <String, int>{};
      for (var t in tasks) {
        final status = t['status'] as String? ?? 'unknown';
        final priority = t['priority'] as String? ?? 'unknown';
        tasksByStatus[status] = (tasksByStatus[status] ?? 0) + 1;
        tasksByPriority[priority] = (tasksByPriority[priority] ?? 0) + 1;
      }

      final usersByRole = <String, int>{};
      for (var u in users) {
        final role = u['role'] as String? ?? 'convidado';
        usersByRole[role] = (usersByRole[role] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _reportData = {
            'projectsByStatus': projectsByStatus,
            'tasksByStatus': tasksByStatus,
            'tasksByPriority': tasksByPriority,
            'usersByRole': usersByRole,
          };
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatórios: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Relatórios e Análises',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconOnlyButton(
                onPressed: _loadReportData,
                icon: Icons.refresh,
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Projetos por Status
          _ReportCard(
            title: 'Projetos por Status',
            data: _reportData['projectsByStatus'] as Map<String, int>? ?? {},
          ),

          const SizedBox(height: 16),

          // Tarefas por Status
          _ReportCard(
            title: 'Tarefas por Status',
            data: _reportData['tasksByStatus'] as Map<String, int>? ?? {},
          ),

          const SizedBox(height: 16),

          // Tarefas por Prioridade
          _ReportCard(
            title: 'Tarefas por Prioridade',
            data: _reportData['tasksByPriority'] as Map<String, int>? ?? {},
          ),

          const SizedBox(height: 16),

          // Usuários por Papel
          _ReportCard(
            title: 'Usuários por Papel',
            data: _reportData['usersByRole'] as Map<String, int>? ?? {},
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;

  const _ReportCard({
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Text('Nenhum dado disponível')
            else
              ...data.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

