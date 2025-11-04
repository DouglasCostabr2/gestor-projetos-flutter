import 'package:flutter/material.dart';
import '../../../services/google_drive_oauth_service.dart';

/// Diálogo para conectar ao Google Drive
///
/// Fornece uma interface simples para autenticação OAuth com Google Drive.
/// Abre automaticamente o navegador para autorização e fecha ao concluir.
///
/// ## Uso:
/// ```dart
/// final result = await showDialog<bool>(
///   context: context,
///   builder: (context) => DriveConnectDialog(
///     service: GoogleDriveOAuthService(),
///     saveAsShared: true, // Opcional: salvar como conta compartilhada
///     organizationId: 'org-id', // Obrigatório se saveAsShared=true
///   ),
/// );
///
/// if (result == true) {
///   // Conexão bem-sucedida
/// }
/// ```
class DriveConnectDialog extends StatefulWidget {
  final GoogleDriveOAuthService service;
  final bool saveAsShared;
  final String? organizationId;

  const DriveConnectDialog({
    super.key,
    required this.service,
    this.saveAsShared = false,
    this.organizationId,
  });

  @override
  State<DriveConnectDialog> createState() => _DriveConnectDialogState();
}

class _DriveConnectDialogState extends State<DriveConnectDialog> {
  final _codeCtrl = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final _ = await widget.service.connectWithLoopback(
        saveAsShared: widget.saveAsShared,
        organizationId: widget.organizationId,
        onAuthUrl: (url, opened) {
          if (!opened) {
            setState(() {
              _error = 'Não foi possível abrir o navegador automaticamente. '
                  'Copie e cole este link:\n$url';
            });
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conectar ao Google Drive'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_working) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Uma janela do navegador será aberta para você autorizar. '
              'Ao concluir, esta janela fechará automaticamente.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _working
              ? null
              : () async {
                  setState(() {
                    _working = true;
                    _error = null;
                  });

                  try {
                    final nav = Navigator.of(context);
                    final _ = await widget.service.connectWithLoopback(
                      saveAsShared: widget.saveAsShared,
                      organizationId: widget.organizationId,
                    );

                    if (!mounted) return;
                    nav.pop(true);
                  } catch (e) {
                    setState(() {
                      _error = 'Falha: $e';
                    });
                  } finally {
                    if (mounted) {
                      setState(() {
                        _working = false;
                      });
                    }
                  }
                },
          child: const Text('Conectar'),
        ),
      ],
    );
  }
}

