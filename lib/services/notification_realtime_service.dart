import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../modules/notifications/module.dart';

/// Status da conexão Realtime
enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Serviço global para gerenciar a subscription de notificações em tempo real
///
/// Este serviço garante que as notificações sejam recebidas em tempo real
/// durante toda a sessão do usuário, independentemente de qual página está aberta.
///
/// ## Funcionamento:
///
/// 1. **Inicialização**: Chamado no AppState.initialize() após o login
/// 2. **Subscription**: Cria um canal Realtime do Supabase que escuta mudanças na tabela notifications
/// 3. **Event Bus**: Emite eventos locais via NotificationEventBus para atualizar widgets
/// 4. **Monitoramento**: Monitora o status da conexão e reconecta automaticamente se necessário
/// 5. **Cleanup**: Cancela a subscription no logout
///
/// ## Uso:
///
/// ```dart
/// // No AppState.initialize() ou após login
/// await notificationRealtimeService.initialize();
///
/// // Escutar status da conexão
/// notificationRealtimeService.connectionStatus.listen((status) {
///   print('Status: $status');
/// });
///
/// // No logout
/// notificationRealtimeService.dispose();
/// ```
class NotificationRealtimeService {
  static final NotificationRealtimeService _instance = NotificationRealtimeService._internal();
  factory NotificationRealtimeService() => _instance;
  NotificationRealtimeService._internal();

  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Stream controller para status da conexão
  final _connectionStatusController = StreamController<RealtimeConnectionStatus>.broadcast();
  RealtimeConnectionStatus _currentStatus = RealtimeConnectionStatus.disconnected;

  /// Stream de status da conexão
  Stream<RealtimeConnectionStatus> get connectionStatus => _connectionStatusController.stream;

  /// Status atual da conexão
  RealtimeConnectionStatus get currentStatus => _currentStatus;

  /// Verifica se o serviço está inicializado
  bool get isInitialized => _isInitialized;

  /// Atualiza o status da conexão
  void _updateStatus(RealtimeConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _connectionStatusController.add(status);
      debugPrint('🔔 [NOTIFICATION REALTIME] Status: $status');
    }
  }

  /// Inicializa a subscription de notificações em tempo real
  ///
  /// Deve ser chamado após o login do usuário.
  /// É seguro chamar múltiplas vezes - só inicializa uma vez.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 [NOTIFICATION REALTIME] Já inicializado, ignorando...');
      return;
    }

    _updateStatus(RealtimeConnectionStatus.connecting);
    _reconnectAttempts = 0;

    try {
      debugPrint('🔔 [NOTIFICATION REALTIME] Inicializando subscription global...');

      _realtimeChannel = notificationsModule.subscribeToNotifications(
        onInsert: (notification) {
          debugPrint('🔔 [NOTIFICATION REALTIME] 🆕 Nova notificação recebida!');
          debugPrint('   ID: ${notification.id}');
          debugPrint('   Type: ${notification.type}');
          debugPrint('   Title: ${notification.title}');
          debugPrint('   Is Read: ${notification.isRead}');

          // Emitir evento local para atualizar widgets
          if (!notification.isRead) {
            notificationEventBus.emitCreated(true);
          }
        },
        onUpdate: (notification) {
          debugPrint('🔔 [NOTIFICATION REALTIME] 🔄 Notificação atualizada!');
          debugPrint('   ID: ${notification.id}');
          debugPrint('   Is Read: ${notification.isRead}');

          // Emitir evento local para atualizar widgets
          if (notification.isRead) {
            notificationEventBus.emitMarkedAsRead(notification.id);
          }
        },
        onDelete: (notification) {
          debugPrint('🔔 [NOTIFICATION REALTIME] 🗑️ Notificação deletada!');
          debugPrint('   ID: ${notification.id}');

          // Emitir evento local para atualizar widgets
          notificationEventBus.emitDeleted(notification.id, !notification.isRead);
        },
      );

      _isInitialized = true;
      _updateStatus(RealtimeConnectionStatus.connected);
      _reconnectAttempts = 0; // Reset contador de tentativas
      debugPrint('✅ [NOTIFICATION REALTIME] Subscription global ativa!');
    } catch (e, stackTrace) {
      debugPrint('❌ [NOTIFICATION REALTIME] Erro ao inicializar: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
      _updateStatus(RealtimeConnectionStatus.error);

      // Tentar reconectar automaticamente
      _scheduleReconnect();
    }
  }

  /// Agenda uma tentativa de reconexão
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ [NOTIFICATION REALTIME] Máximo de tentativas de reconexão atingido');
      _updateStatus(RealtimeConnectionStatus.error);
      return;
    }

    _reconnectAttempts++;
    debugPrint('🔄 [NOTIFICATION REALTIME] Tentativa de reconexão $_reconnectAttempts/$_maxReconnectAttempts em ${_reconnectDelay.inSeconds}s...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      debugPrint('🔄 [NOTIFICATION REALTIME] Reconectando...');
      reinitialize();
    });
  }

  /// Cancela a subscription e limpa recursos
  ///
  /// Deve ser chamado no logout do usuário.
  void dispose() {
    if (!_isInitialized) {
      debugPrint('🔔 [NOTIFICATION REALTIME] Não inicializado, nada para limpar');
      return;
    }

    debugPrint('🔔 [NOTIFICATION REALTIME] Cancelando subscription global...');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _isInitialized = false;
    _reconnectAttempts = 0;
    _updateStatus(RealtimeConnectionStatus.disconnected);
    debugPrint('✅ [NOTIFICATION REALTIME] Subscription cancelada');
  }

  /// Reinicializa a subscription
  ///
  /// Útil para reconectar após perda de conexão ou mudança de usuário.
  Future<void> reinitialize() async {
    debugPrint('🔔 [NOTIFICATION REALTIME] Reinicializando...');
    _reconnectTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _isInitialized = false;
    await initialize();
  }

  /// Limpa todos os recursos (incluindo stream controller)
  ///
  /// Deve ser chamado apenas quando o app for fechado.
  void disposeAll() {
    dispose();
    _connectionStatusController.close();
  }
}

/// Instância global do serviço
final notificationRealtimeService = NotificationRealtimeService();

