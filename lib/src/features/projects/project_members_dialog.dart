import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ui/molecules/user_avatar_name.dart';
import 'package:my_business/ui/atoms/buttons/buttons.dart';
import 'package:my_business/modules/common/organization_context.dart';

class ProjectMembersDialog extends StatefulWidget {
  final String projectId;
  final bool canManage; // owner ou admin
  const ProjectMembersDialog({super.key, required this.projectId, required this.canManage});

  @override
  State<ProjectMembersDialog> createState() => _ProjectMembersDialogState();
}

class _ProjectMembersDialogState extends State<ProjectMembersDialog> {
  late Future<List<Map<String, dynamic>>> _futureMembers;
  final _emailCtrl = TextEditingController();
  bool _adding = false;

  // Novo: seleção por lista de usuários
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _filteredCandidates = [];
  bool _loadingCandidates = true;
  String? _selectedUserId;
  void _applyCandidateFilter() {
    final q = _emailCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredCandidates = q.isEmpty
          ? List<Map<String, dynamic>>.from(_candidates)
          : _candidates.where((p) {
              final email = (p['email'] ?? '').toString().toLowerCase();
              final name  = (p['full_name'] ?? '').toString().toLowerCase();
              return email.contains(q) || name.contains(q);
            }).toList();
      // Garantir que o valor atual continue presente; se não, limpar seleção
      if (_selectedUserId != null && !_filteredCandidates.any((p) => p['id'] == _selectedUserId)) {
        _selectedUserId = null;
      }
    });
  }


  @override
  void initState() {
    super.initState();
    _futureMembers = _loadMembers();
    _loadCandidates();
    _emailCtrl.addListener(_applyCandidateFilter);
  }

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('project_members')
          .select('user_id')
          .eq('project_id', widget.projectId);
      final list = List<Map<String, dynamic>>.from(res);
      final ids = list.map((e) => e['user_id']).whereType<String>().toSet().toList();
      if (ids.isEmpty) return <Map<String, dynamic>>[];
      final inList = ids.map((e) => '"$e"').join(',');
      final profs = await client
          .from('profiles')
          .select('id, full_name, email, avatar_url')
          .filter('id', 'in', '($inList)');
      final byId = <String, Map<String, dynamic>>{
        for (final p in profs) (p['id'] as String): Map<String, dynamic>.from(p)
      };
      return [
        for (final r in list)
          {
            'user_id': r['user_id'],
            'profiles': byId[(r['user_id'] as String? ) ?? ''] ?? {},
          }
      ];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadCandidates() async {
    setState(() { _loadingCandidates = true; });
    try {
      final members = await Supabase.instance.client
          .from('project_members')
          .select('user_id')
          .eq('project_id', widget.projectId);
      final memberIds = members
          .map((e) => e['user_id'])
          .whereType<String>()
          .toSet();

      // Buscar membros da organização atual usando RPC
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        if (!mounted) return;
        setState(() {
          _candidates = [];
          _filteredCandidates = [];
          _loadingCandidates = false;
        });
        return;
      }

      final orgMembers = await Supabase.instance.client.rpc(
        'get_organization_members_with_profiles',
        params: {'org_id': orgId},
      );

      final all = (orgMembers as List).map((m) {
        final member = m as Map<String, dynamic>;
        return {
          'id': member['user_id'],
          'full_name': member['full_name'],
          'email': member['email'],
          'avatar_url': member['avatar_url'],
          'role': member['role'],
        };
      }).toList();

      final filtered = all.where((p) => !memberIds.contains(p['id'] as String?)).toList();

      if (!mounted) return;
      setState(() {
        _candidates = filtered;
        if (_selectedUserId != null && memberIds.contains(_selectedUserId)) {
          _selectedUserId = null;
        }
        final q = _emailCtrl.text.trim().toLowerCase();
        _filteredCandidates = q.isEmpty
            ? List<Map<String, dynamic>>.from(_candidates)
            : _candidates.where((p) {
                final email = (p['email'] ?? '').toString().toLowerCase();
                final name  = (p['full_name'] ?? '').toString().toLowerCase();
                return email.contains(q) || name.contains(q);
              }).toList();
        // Se a seleção atual não existir mais na lista filtrada, limpar
        if (_selectedUserId != null && !_filteredCandidates.any((p) => p['id'] == _selectedUserId)) {
          _selectedUserId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _candidates = []; });
    } finally {
      if (mounted) setState(() { _loadingCandidates = false; });
    }
  }

  Future<void> _addMember() async {
    final typedEmail = _emailCtrl.text.trim();
    final selectedId = _selectedUserId;
    if ((typedEmail.isEmpty) && selectedId == null) return;
    setState(() { _adding = true; });
    try {
      String? userId = selectedId;
      if (userId == null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id, email, full_name, role')
            .eq('email', typedEmail)
            .maybeSingle();

        final role = (profile?['role'] as String?)?.toLowerCase();
        if (role != 'admin' && role != 'gestor' && role != 'designer' && role != 'financeiro') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Apenas Admin/Gestor/Designer/Financeiro podem ser membros deste projeto.')),
            );
          }
          return;
        }
        if (profile == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuário não encontrado pelo e-mail informado.')),
            );
          }
          return;
        }
        userId = profile['id'] as String?;
      }

      await Supabase.instance.client.from('project_members').insert({
        'project_id': widget.projectId,
        'user_id': userId,
        'role': 'member',
      });
      _emailCtrl.clear();
      setState(() {
        _selectedUserId = null;
        _futureMembers = _loadMembers();
      });
      await _loadCandidates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membro adicionado')),
        );
      }
    } on PostgrestException catch (e) {
      final msg = (e.code == '23505')
          ? 'Usuário já é membro deste projeto.'
          : 'Erro: ${e.message}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao adicionar membro')),
        );
      }
    } finally {
      if (mounted) setState(() { _adding = false; });
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await Supabase.instance.client
          .from('project_members')
          .delete()
          .eq('project_id', widget.projectId)
          .eq('user_id', userId);
      setState(() { _futureMembers = _loadMembers(); });
      await _loadCandidates();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao remover membro')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_applyCandidateFilter);
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, minWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Membros do Projeto', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconOnlyButton(onPressed: () => Navigator.pop(context), icon: Icons.close, tooltip: 'Fechar')
                ],
              ),
              const SizedBox(height: 12),
              if (widget.canManage)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail do usuário (opcional)',
                        hintText: 'usuario@empresa.com',
                      ),
                      onSubmitted: (_) => _addMember(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String?>(_selectedUserId),
                      isExpanded: true,
                      initialValue: _filteredCandidates.any((p) => p['id'] == _selectedUserId) ? _selectedUserId : null,
                      hint: Text(_loadingCandidates ? 'Carregando usuários...' : 'Selecionar usuário'),
                      items: _filteredCandidates.map((p) => DropdownMenuItem<String>(
                            value: p['id'] as String,
                            child: UserDropdownItem(
                              avatarUrl: p['avatar_url'] as String?,
                              name: (p['full_name'] ?? p['email']) as String,
                            ),
                          )).toList(),
                      onChanged: _loadingCandidates ? null : (v) {
                        setState(() { _selectedUserId = v; });
                        if (v != null) {
                          final p = _candidates.firstWhere((e) => e['id'] == v, orElse: () => {});
                          final email = p['email'] as String?;
                          if (email != null) _emailCtrl.text = email;
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Usuário (Admin/Funcionário)'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _adding ? null : _addMember,
                        icon: _adding
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.person_add),
                        label: const Text('Adicionar'),
                      ),
                    ),
                  ],
                ),
              if (widget.canManage) const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureMembers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Falha ao carregar membros. Verifique permissões.')),
                    );
                  }
                  final members = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (members.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Nenhum membro adicionado ainda.')),
                    );
                  }
                  return SizedBox(
                    height: 360,
                    child: ListView.separated(
                      itemBuilder: (context, index) {
                        final m = members[index];
                        final profile = m['profiles'] as Map<String, dynamic>?;
                        final email = profile?['email'] ?? '';
                        final name = profile?['full_name'] ?? '-';
                        final avatarUrl = profile?['avatar_url'] as String?;
                        final userId = m['user_id'] as String?;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text(email),
                          trailing: widget.canManage && userId != null
                              ? IconOnlyButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Remover',
                                  onPressed: () => _removeMember(userId),
                                )
                              : null,
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: members.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

