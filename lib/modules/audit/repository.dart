import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class FiscalBankAuditRepository {
  final SupabaseClient _client;

  FiscalBankAuditRepository(this._client);

  /// Cria um novo registro de auditoria
  Future<FiscalBankAuditLog?> createAuditLog({
    required String organizationId,
    required String userId,
    required String userName,
    String? userEmail,
    required String actionType,
    String? countryCode,
    String? personType,
    Map<String, dynamic>? changedFields,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      debugPrint('🔍 [REPO] createAuditLog chamado');
      debugPrint('🔍 [REPO] changedFields tipo: ${changedFields?.runtimeType}');
      debugPrint('🔍 [REPO] previousValues tipo: ${previousValues?.runtimeType}');
      debugPrint('🔍 [REPO] newValues tipo: ${newValues?.runtimeType}');

      final insertData = {
        'organization_id': organizationId,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'action_type': actionType,
        'country_code': countryCode,
        'person_type': personType,
        'changed_fields': changedFields ?? {},
        'previous_values': previousValues ?? {},
        'new_values': newValues ?? {},
      };

      debugPrint('🔍 [REPO] insertData criado, tipo: ${insertData.runtimeType}');
      debugPrint('🔍 [REPO] insertData[changed_fields] tipo: ${insertData['changed_fields'].runtimeType}');
      debugPrint('🔍 [REPO] insertData[previous_values] tipo: ${insertData['previous_values'].runtimeType}');
      debugPrint('🔍 [REPO] insertData[new_values] tipo: ${insertData['new_values'].runtimeType}');

      debugPrint('🔍 [REPO] Chamando .insert()...');
      final response = await _client
          .from('fiscal_bank_audit_log')
          .insert(insertData)
          .select()
          .single();

      debugPrint('🔍 [REPO] Insert bem-sucedido!');
      return FiscalBankAuditLog.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('❌ [REPO] Erro ao criar registro de auditoria: $e');
      debugPrint('❌ [REPO] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Busca a última alteração de uma organização
  Future<LatestAuditInfo?> getLatestAudit(String organizationId) async {
    try {
      final response = await _client
          .rpc('get_latest_fiscal_bank_audit', params: {
            'p_organization_id': organizationId,
          })
          .maybeSingle();

      if (response == null) return null;

      return LatestAuditInfo.fromJson(response);
    } catch (e) {
      debugPrint('❌ Erro ao buscar última auditoria: $e');
      return null;
    }
  }

  /// Busca o histórico de alterações de uma organização
  Future<List<FiscalBankAuditLog>> getAuditHistory({
    required String organizationId,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .rpc('get_fiscal_bank_audit_history', params: {
            'p_organization_id': organizationId,
            'p_limit': limit,
          });

      if (response == null) return [];

      return (response as List)
          .map((item) => FiscalBankAuditLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao buscar histórico de auditoria: $e');
      return [];
    }
  }

  /// Busca registros de auditoria com filtros personalizados
  Future<List<FiscalBankAuditLog>> getAuditLogs({
    required String organizationId,
    String? userId,
    String? countryCode,
    String? personType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      var queryBuilder = _client
          .from('fiscal_bank_audit_log')
          .select();

      // Aplicar filtros
      queryBuilder = queryBuilder.eq('organization_id', organizationId);

      if (userId != null) {
        queryBuilder = queryBuilder.eq('user_id', userId);
      }

      if (countryCode != null) {
        queryBuilder = queryBuilder.eq('country_code', countryCode);
      }

      if (personType != null) {
        queryBuilder = queryBuilder.eq('person_type', personType);
      }

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        queryBuilder = queryBuilder.lte('created_at', endDate.toIso8601String());
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => FiscalBankAuditLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao buscar registros de auditoria: $e');
      return [];
    }
  }

  /// Detecta mudanças entre valores antigos e novos
  static Map<String, dynamic> detectChanges({
    required Map<String, dynamic> oldValues,
    required Map<String, dynamic> newValues,
  }) {
    final changes = <String, dynamic>{};

    // Verificar campos novos ou modificados
    newValues.forEach((key, newValue) {
      final oldValue = oldValues[key];
      if (oldValue != newValue) {
        changes[key] = {
          'old': oldValue,
          'new': newValue,
        };
      }
    });

    // Verificar campos removidos
    oldValues.forEach((key, oldValue) {
      if (!newValues.containsKey(key)) {
        changes[key] = {
          'old': oldValue,
          'new': null,
        };
      }
    });

    return changes;
  }

  /// Extrai apenas os nomes dos campos que mudaram
  static List<String> getChangedFieldNames(Map<String, dynamic> changes) {
    return changes.keys.toList();
  }

  /// Formata as mudanças para exibição
  static String formatChanges(Map<String, dynamic> changes) {
    if (changes.isEmpty) return 'Nenhuma alteração';

    final buffer = StringBuffer();
    changes.forEach((field, change) {
      final oldValue = change['old'] ?? 'vazio';
      final newValue = change['new'] ?? 'vazio';
      buffer.writeln('$field: $oldValue → $newValue');
    });

    return buffer.toString().trim();
  }
}

