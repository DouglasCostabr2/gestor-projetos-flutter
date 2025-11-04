/// Modelos de dados do módulo de rastreamento de tempo
library;

/// Modelo para um registro de tempo (sessão de trabalho)
class TimeLog {
  final String id;
  final String taskId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeLog({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Criar TimeLog a partir de um Map do Supabase
  factory TimeLog.fromMap(Map<String, dynamic> map) {
    return TimeLog(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      durationSeconds: map['duration_seconds'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Converter TimeLog para Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Verificar se a sessão está ativa (em andamento)
  bool get isActive => endTime == null;

  /// Obter duração formatada (HH:MM:SS)
  String get formattedDuration {
    final seconds = durationSeconds ?? 0;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Copiar com novos valores
  TimeLog copyWith({
    String? id,
    String? taskId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeLog(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Modelo para estatísticas de tempo de um usuário
class UserTimeStats {
  final String userId;
  final int totalSeconds;
  final int sessionCount;
  final double averageSessionSeconds;
  final DateTime? firstSession;
  final DateTime? lastSession;

  UserTimeStats({
    required this.userId,
    required this.totalSeconds,
    required this.sessionCount,
    required this.averageSessionSeconds,
    this.firstSession,
    this.lastSession,
  });

  /// Criar UserTimeStats a partir de um Map
  factory UserTimeStats.fromMap(Map<String, dynamic> map) {
    return UserTimeStats(
      userId: map['user_id'] as String,
      totalSeconds: map['total_seconds'] as int,
      sessionCount: map['session_count'] as int,
      averageSessionSeconds: (map['average_session_seconds'] as num).toDouble(),
      firstSession: map['first_session'] != null ? DateTime.parse(map['first_session'] as String) : null,
      lastSession: map['last_session'] != null ? DateTime.parse(map['last_session'] as String) : null,
    );
  }

  /// Obter tempo total formatado (HH:MM:SS)
  String get formattedTotalTime {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Obter média formatada (HH:MM:SS)
  String get formattedAverageTime {
    final avgSeconds = averageSessionSeconds.round();
    final hours = avgSeconds ~/ 3600;
    final minutes = (avgSeconds % 3600) ~/ 60;
    final secs = avgSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

