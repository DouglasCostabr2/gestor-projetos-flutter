import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/user_avatar_name.dart';
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _data = [];
  // Lista de cargos disponíveis na UI (mapear 'funcionario' -> 'designer')
  final List<String> _roles = const ['admin', 'gestor', 'designer', 'financeiro', 'cliente', 'convidado'];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final res = await Supabase.instance.client
        .from('profiles')
        .select('id, email, full_name, role, avatar_url')
        .order('email', ascending: true);
    if (!mounted) return;
    setState(() {
      _data = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _updateRole(String id, String newRole) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('profiles').update({'role': newRole}).eq('id', id);
      messenger.showSnackBar(const SnackBar(content: Text('Papel atualizado')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Falha ao atualizar papel (verifique RLS)')));
    } finally {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('Usuários', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconOnlyButton(onPressed: _loading ? null : _reload, icon: Icons.refresh, tooltip: 'Atualizar'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Builder(builder: (context) {
            if (_loading) return const Center(child: CircularProgressIndicator());
            if (_data.isEmpty) return const Center(child: Text('Nenhum usuário encontrado'));
            return SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Nome')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Papel')),
                ],
                rows: _data.map((u) {
                  final id = u['id'] as String?;
                  final rawRole = (u['role'] as String? ?? '').toLowerCase();
                  // Exibir 'designer' para registros antigos com 'funcionario'
                  final displayRole = rawRole == 'funcionario' ? 'designer' : rawRole;
                  final avatarUrl = u['avatar_url'] as String?;
                  final name = u['full_name'] ?? '-';
                  return DataRow(cells: [
                    DataCell(
                      UserAvatarName(
                        avatarUrl: avatarUrl,
                        name: name,
                        size: 32,
                      ),
                    ),
                    DataCell(Text(u['email'] ?? '-')),
                    DataCell(
                      id == null
                          ? const Text('-')
                          : DropdownButton<String>(
                              value: _roles.contains(displayRole) ? displayRole : 'convidado',
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (v) async {
                                    if (v == null) return;
                                    // Bloqueio: gestor não pode alterar papel de um usuário admin
                                    final res = await Supabase.instance.client
                                      .from('profiles')
                                      .select('role')
                                      .eq('id', Supabase.instance.client.auth.currentUser!.id)
                                      .maybeSingle();
                                    final currentRole = (res?['role'] as String?)?.toLowerCase();
                                    if (displayRole == 'admin' && currentRole == 'gestor') {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Gestor não pode alterar o cargo de um usuário Admin.')),
                                      );
                                      return;
                                    }
                                    _updateRole(id, v);
                                  },
                            ),
                    ),
                  ]);
                }).toList(),
              ),
            );
          }),
        )
      ],
    );
  }
}

