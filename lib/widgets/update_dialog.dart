import 'package:flutter/material.dart';
import '../models/app_update.dart';
import '../services/update_service.dart';

/// Diálogo que notifica o usuário sobre atualizações disponíveis
class UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.update,
    required this.updateService,
  });

  /// Mostra o diálogo de atualização
  ///
  /// Retorna true se o usuário escolheu atualizar, false caso contrário.
  static Future<bool?> show(
    BuildContext context,
    AppUpdate update,
    UpdateService updateService,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !update.isMandatory,
      builder: (context) => UpdateDialog(
        update: update,
        updateService: updateService,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    widget.updateService.onDownloadProgress = (progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    };
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Baixando atualização...';
    });

    try {
      await widget.updateService.downloadAndInstall(widget.update);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Erro ao baixar atualização';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar atualização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMandatory = widget.update.isMandatory;

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              isMandatory ? Icons.warning_rounded : Icons.system_update_rounded,
              color: isMandatory ? Colors.orange : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isMandatory ? 'Atualização Obrigatória' : 'Nova Versão Disponível',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informação da versão
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.new_releases_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Versão ${widget.update.version}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Notas de lançamento
              if (widget.update.releaseNotes != null) ...[
                const Text(
                  'Novidades:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.update.releaseNotes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Mensagem de atualização obrigatória
              if (isMandatory)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta atualização é obrigatória para continuar usando o aplicativo.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Barra de progresso do download
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          // Botão "Mais tarde" (apenas se não for obrigatória)
          if (!isMandatory && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Mais tarde',
                style: TextStyle(color: Colors.white54),
              ),
            ),

          // Botão "Atualizar agora"
          if (!_isDownloading)
            ElevatedButton.icon(
              onPressed: _startUpdate,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Atualizar agora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isMandatory ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

