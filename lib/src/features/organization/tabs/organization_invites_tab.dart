import 'package:flutter/material.dart';
import '../../../../modules/modules.dart';
import '../../../state/app_state_scope.dart';
import '../dialogs/send_invite_dialog.dart';

/// Aba de convites da organização
class OrganizationInvitesTab extends StatefulWidget {
  const OrganizationInvitesTab({super.key});

  @override
  State<OrganizationInvitesTab> createState() => _OrganizationInvitesTabState();
}

class _OrganizationInvitesTabState extends State<OrganizationInvitesTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final appState = AppStateScope.of(context);
      final orgId = appState.currentOrganizationId;

      if (orgId != null) {
        final invites = await organizationsModule.getOrganizationInvites(orgId);
        if (mounted) {
          setState(() => _invites = invites);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar convites: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final canManage = appState.canManageMembers;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: _invites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum convite pendente',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _invites.length,
              itemBuilder: (context, index) {
                final invite = _invites[index];
                
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(invite['status']),
                      child: Icon(
                        _getStatusIcon(invite['status']),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      invite['email'] ?? 'Email não informado',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Role: ${_getRoleLabel(invite['role'])} • ${_getStatusLabel(invite['status'])}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (invite['status'] == 'pending') ...[
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  color: Colors.blue[300],
                                  tooltip: 'Reenviar convite',
                                  onPressed: () => _resendInvite(invite),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel),
                                  color: Colors.red[300],
                                  tooltip: 'Cancelar convite',
                                  onPressed: () => _cancelInvite(invite),
                                ),
                              ],
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _sendInvite,
              icon: const Icon(Icons.person_add),
              label: const Text('Enviar Convite'),
              backgroundColor: const Color(0xFF2196F3),
            )
          : null,
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.help;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'accepted':
        return 'Aceito';
      case 'rejected':
        return 'Rejeitado';
      case 'expired':
        return 'Expirado';
      default:
        return 'Desconhecido';
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'owner':
        return 'Proprietário';
      case 'admin':
        return 'Administrador';
      case 'gestor':
        return 'Gestor';
      case 'financeiro':
        return 'Financeiro';
      case 'designer':
        return 'Designer';
      case 'usuario':
        return 'Usuário';
      default:
        return 'Sem role';
    }
  }

  Future<void> _sendInvite() async {
    final appState = AppStateScope.of(context);
    final orgId = appState.currentOrganizationId;

    if (orgId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SendInviteDialog(organizationId: orgId),
    );

    if (result == true) {
      _loadInvites(); // Recarregar lista
    }
  }

  Future<void> _resendInvite(Map<String, dynamic> invite) async {
    try {
      await organizationsModule.resendInvite(invite['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite reenviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reenviar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelInvite(Map<String, dynamic> invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Cancelar Convite', style: TextStyle(color: Colors.white)),
        content: Text(
          'Tem certeza que deseja cancelar o convite para ${invite['email']}?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await organizationsModule.cancelInvite(invite['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Convite cancelado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadInvites();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao cancelar convite: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

