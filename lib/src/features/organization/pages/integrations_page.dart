import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../services/google_drive_oauth_service.dart';
import '../../../../ui/organisms/dialogs/drive_connect_dialog.dart';
import '../../../state/app_state_scope.dart';

/// Página de Integrações da Organização
///
/// Gerencia integrações externas como Google Drive, APIs, etc.
class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key});

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  bool _loadingDriveStatus = true;
  String? _driveEmail;
  bool _isSharedToken = false;
  String? _sharedConnectedBy;

  @override
  void initState() {
    super.initState();
    _loadDriveStatus();
  }

  Future<void> _loadDriveStatus() async {
    setState(() => _loadingDriveStatus = true);
    try {
      // Obter organization_id do contexto
      final appState = AppStateScope.of(context);
      final organizationId = appState.currentOrganizationId;

      if (organizationId == null) {
        if (mounted) {
          setState(() {
            _driveEmail = null;
            _isSharedToken = false;
            _sharedConnectedBy = null;
            _loadingDriveStatus = false;
          });
        }
        return;
      }

      final service = GoogleDriveOAuthService();

      // Verificar se há token compartilhado da organização
      final hasShared = await service.hasSharedToken(organizationId);
      if (hasShared) {
        final sharedInfo = await service.getSharedTokenInfo(organizationId);
        final connectedById = sharedInfo?['connected_by'] as String?;

        // Buscar nome do usuário que conectou
        String? connectedByName;
        if (connectedById != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('full_name, email')
                .eq('id', connectedById)
                .maybeSingle();
            connectedByName = profile?['full_name'] ?? profile?['email'];
          } catch (e) {
            // Ignorar erro (operação não crítica)
          }
        }

        if (mounted) {
          setState(() {
            _driveEmail = 'Conta compartilhada da organização';
            _isSharedToken = true;
            _sharedConnectedBy = connectedByName;
            _loadingDriveStatus = false;
          });
        }
        return;
      }

      // Sem token compartilhado: considerar não conectado (sem opção pessoal)
      if (mounted) {
        setState(() {
          _driveEmail = null;
          _isSharedToken = false;
          _sharedConnectedBy = null;
          _loadingDriveStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driveEmail = null;
          _isSharedToken = false;
          _sharedConnectedBy = null;
          _loadingDriveStatus = false;
        });
      }
    }
  }

  Future<void> _connectDrive() async {
    // Obter organization_id do contexto ANTES do showDialog
    final appState = AppStateScope.of(context);
    final organizationId = appState.currentOrganizationId;

    if (organizationId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma organização ativa'),
          ),
        );
      }
      return;
    }

    // Conectar sempre como conta compartilhada da organização
    final service = GoogleDriveOAuthService();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DriveConnectDialog(
        service: service,
        saveAsShared: true,
        organizationId: organizationId,
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Google Drive conectado como conta compartilhada da organização'),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
      _loadDriveStatus();
    }
  }

  Future<void> _disconnectDrive() async {
    // Obter organization_id do contexto ANTES do showDialog
    final appState = AppStateScope.of(context);
    final organizationId = appState.currentOrganizationId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar Google Drive'),
        content: const Text(
          'Tem certeza que deseja desconectar a conta compartilhada do Google Drive?\n\n'
          'ATENÇÃO: Todos os usuários da organização perderão acesso ao Google Drive até que uma nova conta seja conectada.\n\n'
          'Os arquivos já enviados permanecerão no Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {

      if (organizationId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma organização ativa'),
            ),
          );
        }
        return;
      }

      // Desconectar token compartilhado da organização
      final service = GoogleDriveOAuthService();
      await service.disconnectShared(organizationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google Drive desconectado com sucesso'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
        _loadDriveStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desconectar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Integrações',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gerencie integrações com serviços externos',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),

            // Seção Google Drive
            _IntegrationSection(
              title: 'Google Drive',
              children: [
                _IntegrationItem(
                  icon: Icons.cloud,
                  title: 'Google Drive',
                  subtitle: _loadingDriveStatus
                      ? 'Verificando...'
                      : _driveEmail != null
                          ? _isSharedToken
                              ? 'Conta compartilhada${_sharedConnectedBy != null ? ' (conectada por $_sharedConnectedBy)' : ''}'
                              : 'Conectado como $_driveEmail'
                          : 'Não conectado',
                  trailing: _loadingDriveStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _driveEmail != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSharedToken)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Tooltip(
                                      message: 'Todos os usuários usam esta conta',
                                      child: Icon(Icons.people, color: Colors.blue),
                                    ),
                                  ),
                                Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _disconnectDrive,
                                  child: const Text('Desconectar'),
                                ),
                              ],
                            )
                          : FilledButton.icon(
                              onPressed: _connectDrive,
                              icon: const Icon(Icons.link),
                              label: const Text('Conectar'),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget de seção de integração
class _IntegrationSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _IntegrationSection({
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Widget de item de integração
class _IntegrationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _IntegrationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}

