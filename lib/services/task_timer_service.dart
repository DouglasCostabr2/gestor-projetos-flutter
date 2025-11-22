import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modules/time_tracking/module.dart';

/// Serviço para gerenciar o estado do cronômetro de tarefas
/// 
/// Características:
/// - Gerencia estado do timer (running/paused/stopped)
/// - Persiste estado em SharedPreferences
/// - Sincroniza automaticamente com banco de dados
/// - Retoma automaticamente ao reabrir app
/// - Singleton pattern
class TaskTimerService extends ChangeNotifier {
  static final TaskTimerService _instance = TaskTimerService._internal();
  factory TaskTimerService() => _instance;
  TaskTimerService._internal();

  // Estado do timer
  String? _activeTaskId;
  String? _activeTimeLogId;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  // Getters públicos
  String? get activeTaskId => _activeTaskId;
  String? get activeTimeLogId => _activeTimeLogId;
  DateTime? get startTime => _startTime;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _isRunning;

  // Chaves para SharedPreferences
  static const String _keyActiveTaskId = 'timer_active_task_id';
  static const String _keyActiveTimeLogId = 'timer_active_time_log_id';
  static const String _keyStartTime = 'timer_start_time';
  static const String _keyElapsedSeconds = 'timer_elapsed_seconds';

  /// Inicializar o serviço e restaurar estado salvo
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedTaskId = prefs.getString(_keyActiveTaskId);
      final savedTimeLogId = prefs.getString(_keyActiveTimeLogId);
      final savedStartTime = prefs.getString(_keyStartTime);
      final savedElapsed = prefs.getInt(_keyElapsedSeconds) ?? 0;

      if (savedTaskId != null && savedTimeLogId != null && savedStartTime != null) {
        _activeTaskId = savedTaskId;
        _activeTimeLogId = savedTimeLogId;
        _startTime = DateTime.parse(savedStartTime);
        _elapsedSeconds = savedElapsed;

        // Verificar se o time_log ainda existe e está ativo no banco
        final activeLog = await timeTrackingModule.getActiveTimeLog(taskId: savedTaskId);
        
        if (activeLog != null && activeLog['id'] == savedTimeLogId) {
          // Retomar o timer
          _resumeTimer();
        } else {
          // Limpar estado se o time_log não existe mais
          await _clearState();
        }
      }
    } catch (e) {
      await _clearState();
    }
  }

  /// Iniciar cronômetro para uma tarefa
  Future<void> start(String taskId) async {
    try {
      // Parar timer atual se houver
      if (_isRunning) {
        await stop();
      }

      // Criar novo time_log no banco
      final timeLogId = await timeTrackingModule.startTimeLog(taskId: taskId);

      // Atualizar estado
      _activeTaskId = taskId;
      _activeTimeLogId = timeLogId;
      _startTime = DateTime.now();
      _elapsedSeconds = 0;
      _isRunning = true;

      // Salvar estado
      await _saveState();

      // Iniciar timer
      _startTimer();

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Pausar cronômetro (mantém o time_log ativo)
  Future<void> pause() async {
    if (!_isRunning) return;

    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    await _saveState();
    notifyListeners();
  }

  /// Retomar cronômetro pausado
  Future<void> resume() async {
    if (_isRunning || _activeTimeLogId == null) return;

    _isRunning = true;
    _resumeTimer();

    await _saveState();
    notifyListeners();
  }

  /// Parar cronômetro e finalizar time_log
  ///
  /// [description] - Descrição opcional da atividade realizada
  /// [skipNotify] - Se true, não notifica listeners (útil ao fechar app)
  Future<void> stop({String? description, bool skipNotify = false}) async {
    if (_activeTimeLogId == null) return;

    try {
      // Limpar timer imediatamente para evitar atualizações durante o fechamento
      _isRunning = false;
      _timer?.cancel();
      _timer = null;

      // Finalizar time_log no banco com descrição opcional
      await timeTrackingModule.stopTimeLog(
        timeLogId: _activeTimeLogId!,
        description: description,
      );

      // Limpar estado
      _activeTaskId = null;
      _activeTimeLogId = null;
      _startTime = null;
      _elapsedSeconds = 0;

      await _clearState();

      // Só notifica listeners se não for durante fechamento do app
      if (!skipNotify) {
        notifyListeners();
      }

    } catch (e) {
      rethrow;
    }
  }

  /// Verificar se há um timer ativo para uma tarefa específica
  bool isActiveForTask(String taskId) {
    return _activeTaskId == taskId && _isRunning;
  }

  /// Obter tempo formatado (HH:MM:SS)
  String getFormattedTime() {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Métodos privados

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
      
      // Salvar estado a cada minuto para evitar perda de dados
      if (_elapsedSeconds % 60 == 0) {
        _saveState();
      }
    });
  }

  void _resumeTimer() {
    // Calcular tempo decorrido desde o início
    if (_startTime != null) {
      final now = DateTime.now();
      final totalElapsed = now.difference(_startTime!).inSeconds;
      _elapsedSeconds = totalElapsed;
    }

    _isRunning = true;
    _startTimer();
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_activeTaskId != null && _activeTimeLogId != null && _startTime != null) {
        await prefs.setString(_keyActiveTaskId, _activeTaskId!);
        await prefs.setString(_keyActiveTimeLogId, _activeTimeLogId!);
        await prefs.setString(_keyStartTime, _startTime!.toIso8601String());
        await prefs.setInt(_keyElapsedSeconds, _elapsedSeconds);
      } else {
        await _clearState();
      }
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  Future<void> _clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveTaskId);
      await prefs.remove(_keyActiveTimeLogId);
      await prefs.remove(_keyStartTime);
      await prefs.remove(_keyElapsedSeconds);
    } catch (e) {
      // Ignorar erro (operação não crítica)
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Instância global do serviço de timer
final taskTimerService = TaskTimerService();

