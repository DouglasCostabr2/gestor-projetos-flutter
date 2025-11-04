/// Exemplos de uso do sistema de atualização
///
/// Este arquivo contém exemplos práticos de como usar o UpdateService
/// e o UpdateDialog em diferentes cenários.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_business/models/app_update.dart';
import 'package:my_business/services/update_service.dart';
import 'package:my_business/widgets/update_dialog.dart';

// ============================================================================
// EXEMPLO 1: Verificação Manual de Atualização
// ============================================================================

/// Exemplo de como verificar manualmente por atualizações
/// Útil para adicionar um botão "Verificar atualizações" nas configurações
class ManualUpdateCheckExample extends StatelessWidget {
  const ManualUpdateCheckExample({super.key});

  Future<void> _checkForUpdates(BuildContext context) async {
    // Mostrar indicador de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updateService = UpdateService();
      final update = await updateService.checkForUpdates();

      // Fechar indicador de carregamento
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (update != null && context.mounted) {
        // Mostrar diálogo de atualização
        await UpdateDialog.show(context, update, updateService);
      } else if (context.mounted) {
        // Nenhuma atualização disponível
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Você está usando a versão mais recente!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Erro ao verificar
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao verificar atualizações: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _checkForUpdates(context),
      icon: const Icon(Icons.system_update),
      label: const Text('Verificar atualizações'),
    );
  }
}

// ============================================================================
// EXEMPLO 2: Verificação Automática com Intervalo
// ============================================================================

/// Exemplo de como verificar atualizações periodicamente
/// Útil para apps que ficam abertos por muito tempo
class PeriodicUpdateCheckExample extends StatefulWidget {
  const PeriodicUpdateCheckExample({super.key});

  @override
  State<PeriodicUpdateCheckExample> createState() =>
      _PeriodicUpdateCheckExampleState();
}

class _PeriodicUpdateCheckExampleState
    extends State<PeriodicUpdateCheckExample> {
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    // Verificar a cada 6 horas
    Future.delayed(const Duration(hours: 6), () async {
      if (!mounted) return;

      final update = await _updateService.checkForUpdates();
      if (update != null && mounted) {
        await UpdateDialog.show(context, update, _updateService);
      }

      // Agendar próxima verificação
      _startPeriodicCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// ============================================================================
// EXEMPLO 3: Download com Progresso Customizado
// ============================================================================

/// Exemplo de como fazer download com UI customizada
class CustomProgressUpdateExample extends StatefulWidget {
  final AppUpdate update;

  const CustomProgressUpdateExample({
    super.key,
    required this.update,
  });

  @override
  State<CustomProgressUpdateExample> createState() =>
      _CustomProgressUpdateExampleState();
}

class _CustomProgressUpdateExampleState
    extends State<CustomProgressUpdateExample> {
  final UpdateService _updateService = UpdateService();
  double _progress = 0.0;
  bool _isDownloading = false;
  String _statusMessage = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Iniciando download...';
    });

    // Configurar callback de progresso
    _updateService.onDownloadProgress = (progress) {
      setState(() {
        _progress = progress;
        _statusMessage =
            'Baixando... ${(progress * 100).toStringAsFixed(1)}%';
      });
    };

    try {
      await _updateService.downloadAndInstall(widget.update);
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Erro ao baixar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_statusMessage),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 16),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: const Text('Baixar atualização'),
          ),
      ],
    );
  }
}

// ============================================================================
// EXEMPLO 4: Verificação Silenciosa (Background)
// ============================================================================

/// Exemplo de verificação silenciosa sem UI
/// Útil para preparar atualizações em background
class SilentUpdateCheckExample {
  final UpdateService _updateService = UpdateService();

  /// Verifica e baixa atualização em background
  /// Retorna true se uma atualização foi baixada
  Future<bool> checkAndPrepareUpdate() async {
    try {
      final update = await _updateService.checkForUpdates();

      if (update != null && !update.isMandatory) {
        // Baixar silenciosamente (sem instalar)
        final filePath = await _updateService.downloadUpdate(update);

        if (filePath != null) {
          debugPrint('✅ Atualização baixada: $filePath');
          debugPrint('💡 Usuário pode instalar quando quiser');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Erro na verificação silenciosa: $e');
      return false;
    }
  }
}

// ============================================================================
// EXEMPLO 5: Página de Configurações com Informações de Versão
// ============================================================================

/// Exemplo de página de configurações mostrando versão e botão de atualização
class SettingsPageExample extends StatefulWidget {
  const SettingsPageExample({super.key});

  @override
  State<SettingsPageExample> createState() => _SettingsPageExampleState();
}

class _SettingsPageExampleState extends State<SettingsPageExample> {
  String _currentVersion = 'Carregando...';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    // Obter versão atual
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingUpdate = true;
    });

    try {
      final updateService = UpdateService();
      final update = await updateService.checkForUpdates();

      if (update != null && mounted) {
        await UpdateDialog.show(context, update, updateService);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Você está na versão mais recente!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          // Seção de informações
          const ListTile(
            title: Text('Sobre'),
            subtitle: Text('Informações do aplicativo'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão'),
            subtitle: Text(_currentVersion),
          ),

          const Divider(),

          // Seção de atualizações
          const ListTile(
            title: Text('Atualizações'),
            subtitle: Text('Gerenciar atualizações do aplicativo'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Verificar atualizações'),
            subtitle: const Text('Buscar nova versão disponível'),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : _checkForUpdates,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXEMPLO 6: Notificação de Atualização Disponível
// ============================================================================

/// Exemplo de como mostrar uma notificação discreta sobre atualização
class UpdateNotificationExample extends StatelessWidget {
  final AppUpdate update;
  final VoidCallback onTap;

  const UpdateNotificationExample({
    super.key,
    required this.update,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                update.isMandatory
                    ? Icons.warning_rounded
                    : Icons.system_update_rounded,
                color: update.isMandatory ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      update.isMandatory
                          ? 'Atualização obrigatória disponível'
                          : 'Nova versão disponível',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Versão ${update.version}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EXEMPLO 7: Uso Programático Completo
// ============================================================================

/// Exemplo completo de uso programático do sistema de atualização
class CompleteUpdateFlowExample {
  final UpdateService _updateService = UpdateService();

  /// Fluxo completo de verificação e atualização
  Future<void> performUpdateFlow(BuildContext context) async {
    // 1. Verificar se há atualização
    final update = await _updateService.checkForUpdates();

    if (update == null) {
      debugPrint('✅ Nenhuma atualização disponível');
      return;
    }

    debugPrint('📦 Atualização encontrada: ${update.version}');

    // 2. Mostrar diálogo para o usuário
    if (!context.mounted) return;

    final shouldUpdate = await UpdateDialog.show(
      context,
      update,
      _updateService,
    );

    if (shouldUpdate != true) {
      debugPrint('⏭️ Usuário optou por não atualizar agora');
      return;
    }

    // 3. Download e instalação já são feitos pelo UpdateDialog
    debugPrint('⬇️ Download e instalação iniciados...');
  }
}

