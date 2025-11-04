import 'dart:convert';

/// Modelo para registro de auditoria de dados fiscais e bancários
class FiscalBankAuditLog {
  final String id;
  final String organizationId;
  final String userId;
  final String userName;
  final String? userEmail;
  final String actionType; // 'create', 'update', 'delete'
  final String? countryCode;
  final String? personType; // 'individual', 'business'
  final Map<String, dynamic> changedFields;
  final Map<String, dynamic> previousValues;
  final Map<String, dynamic> newValues;
  final DateTime createdAt;

  FiscalBankAuditLog({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.actionType,
    this.countryCode,
    this.personType,
    required this.changedFields,
    required this.previousValues,
    required this.newValues,
    required this.createdAt,
  });

  /// Cria uma instância a partir de um Map (JSON do Supabase)
  factory FiscalBankAuditLog.fromJson(Map<String, dynamic> json) {
    return FiscalBankAuditLog(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userEmail: json['user_email'] as String?,
      actionType: json['action_type'] as String,
      countryCode: json['country_code'] as String?,
      personType: json['person_type'] as String?,
      changedFields: _parseJsonField(json['changed_fields']),
      previousValues: _parseJsonField(json['previous_values']),
      newValues: _parseJsonField(json['new_values']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converte para Map (JSON para enviar ao Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'action_type': actionType,
      'country_code': countryCode,
      'person_type': personType,
      'changed_fields': changedFields,
      'previous_values': previousValues,
      'new_values': newValues,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Helper para parsear campos JSONB que podem vir como String ou Map
  static Map<String, dynamic> _parseJsonField(dynamic field) {
    if (field == null) return {};
    if (field is Map<String, dynamic>) return field;
    if (field is Map) return Map<String, dynamic>.from(field);
    if (field is String) {
      try {
        final decoded = jsonDecode(field);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return {};
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  /// Cria uma cópia com campos modificados
  FiscalBankAuditLog copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? userName,
    String? userEmail,
    String? actionType,
    String? countryCode,
    String? personType,
    Map<String, dynamic>? changedFields,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
    DateTime? createdAt,
  }) {
    return FiscalBankAuditLog(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      actionType: actionType ?? this.actionType,
      countryCode: countryCode ?? this.countryCode,
      personType: personType ?? this.personType,
      changedFields: changedFields ?? this.changedFields,
      previousValues: previousValues ?? this.previousValues,
      newValues: newValues ?? this.newValues,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'FiscalBankAuditLog(id: $id, userName: $userName, actionType: $actionType, '
        'countryCode: $countryCode, personType: $personType, createdAt: $createdAt)';
  }
}

/// Modelo simplificado para exibir última alteração
class LatestAuditInfo {
  final String userName;
  final String? userEmail;
  final DateTime createdAt;
  final String? countryCode;
  final String? personType;

  LatestAuditInfo({
    required this.userName,
    this.userEmail,
    required this.createdAt,
    this.countryCode,
    this.personType,
  });

  factory LatestAuditInfo.fromJson(Map<String, dynamic> json) {
    return LatestAuditInfo(
      userName: json['user_name'] as String,
      userEmail: json['user_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      countryCode: json['country_code'] as String?,
      personType: json['person_type'] as String?,
    );
  }

  /// Retorna uma descrição formatada da última alteração
  String getFormattedDescription() {
    final buffer = StringBuffer();
    buffer.write('Última alteração por $userName');
    
    if (countryCode != null) {
      buffer.write(' (País: $countryCode');
      if (personType != null) {
        final personTypeLabel = personType == 'individual' 
            ? 'Pessoa Física' 
            : 'Pessoa Jurídica';
        buffer.write(', $personTypeLabel');
      }
      buffer.write(')');
    }
    
    return buffer.toString();
  }

  /// Retorna tempo relativo (ex: "há 2 horas", "há 3 dias")
  String getRelativeTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'há ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'há ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'há ${difference.inHours} horas';
    } else if (difference.inDays < 30) {
      return 'há ${difference.inDays} dias';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'há $months ${months == 1 ? "mês" : "meses"}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'há $years ${years == 1 ? "ano" : "anos"}';
    }
  }

  @override
  String toString() {
    return 'LatestAuditInfo(userName: $userName, createdAt: $createdAt)';
  }
}

