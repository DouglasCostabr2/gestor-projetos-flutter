import 'package:flutter/material.dart';
import '../../../../services/notification_realtime_service.dart';

/// Indicador visual do status da conexão Realtime
/// 
/// Mostra um pequeno ícone colorido indicando se as notificações em tempo real
/// estão funcionando corretamente.
/// 
/// ## Cores:
/// - 🟢 Verde: Conectado
/// - 🟡 Amarelo: Conectando
/// - 🔴 Vermelho: Erro/Desconectado
class RealtimeStatusIndicator extends StatefulWidget {
  /// Se true, mostra um tooltip com informações detalhadas
  final bool showTooltip;
  
  /// Tamanho do indicador
  final double size;

  const RealtimeStatusIndicator({
    super.key,
    this.showTooltip = true,
    this.size = 8.0,
  });

  @override
  State<RealtimeStatusIndicator> createState() => _RealtimeStatusIndicatorState();
}

class _RealtimeStatusIndicatorState extends State<RealtimeStatusIndicator> {
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _status = notificationRealtimeService.currentStatus;
    
    // Escutar mudanças de status
    notificationRealtimeService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  Color _getColorForStatus(RealtimeConnectionStatus status) {
    switch (status) {
      case RealtimeConnectionStatus.connected:
        return const Color(0xFF4CAF50); // Verde
      case RealtimeConnectionStatus.connecting:
        return const Color(0xFFFFC107); // Amarelo
      case RealtimeConnectionStatus.disconnected:
      case RealtimeConnectionStatus.error:
        return const Color(0xFFF44336); // Vermelho
    }
  }

  String _getMessageForStatus(RealtimeConnectionStatus status) {
    switch (status) {
      case RealtimeConnectionStatus.connected:
        return 'Notificações em tempo real ativas';
      case RealtimeConnectionStatus.connecting:
        return 'Conectando...';
      case RealtimeConnectionStatus.disconnected:
        return 'Desconectado';
      case RealtimeConnectionStatus.error:
        return 'Erro na conexão - tentando reconectar';
    }
  }

  IconData _getIconForStatus(RealtimeConnectionStatus status) {
    switch (status) {
      case RealtimeConnectionStatus.connected:
        return Icons.check_circle;
      case RealtimeConnectionStatus.connecting:
        return Icons.sync;
      case RealtimeConnectionStatus.disconnected:
      case RealtimeConnectionStatus.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForStatus(_status);
    final message = _getMessageForStatus(_status);
    final icon = _getIconForStatus(_status);

    final indicator = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );

    if (!widget.showTooltip) {
      return indicator;
    }

    return Tooltip(
      message: message,
      preferBelow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 6),
          Icon(
            icon,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }
}

