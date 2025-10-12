import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'contract.dart';

/// Implementação do contrato financeiro
class FinanceRepository implements FinanceContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<Map<String, dynamic>?> getProjectFinancials(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select('currency_code, value_cents')
          .eq('id', projectId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar dados financeiros: $e');
      return null;
    }
  }

  @override
  Future<void> updateProjectFinancials({
    required String projectId,
    required String currencyCode,
    required int valueCents,
  }) async {
    await _client
        .from('projects')
        .update({
          'currency_code': currencyCode,
          'value_cents': valueCents,
        })
        .eq('id', projectId);
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectAdditionalCosts(String projectId) async {
    try {
      final response = await _client
          .from('project_additional_costs')
          .select('*')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar custos adicionais: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> addProjectCost({
    required String projectId,
    required String description,
    required String currencyCode,
    required int amountCents,
  }) async {
    final response = await _client
        .from('project_additional_costs')
        .insert({
          'project_id': projectId,
          'description': description,
          'currency_code': currencyCode,
          'amount_cents': amountCents,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<void> removeProjectCost(String costId) async {
    await _client
        .from('project_additional_costs')
        .delete()
        .eq('id', costId);
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectCatalogItems(String projectId) async {
    try {
      final response = await _client
          .from('project_catalog_items')
          .select('*')
          .eq('project_id', projectId)
          .order('position', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar itens do catálogo: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentsByProjects(List<String> projectIds) async {
    try {
      if (projectIds.isEmpty) return [];

      final response = await _client
          .from('payments')
          .select('id, amount_cents, created_at, project_id, projects:project_id(name, currency_code)')
          .inFilter('project_id', projectIds)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pagamentos: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeePayments(String employeeId) async {
    try {
      final response = await _client
          .from('employee_payments')
          .select('id, amount_cents, status, description, project_id, employee_id, projects:project_id(name, currency_code)')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pagamentos de funcionário: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectPayments(String projectId) async {
    try {
      final response = await _client
          .from('payments')
          .select('amount_cents')
          .eq('project_id', projectId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pagamentos do projeto: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createPayment({
    required String projectId,
    required int amountCents,
    required String currencyCode,
  }) async {
    final response = await _client
        .from('payments')
        .insert({
          'project_id': projectId,
          'amount_cents': amountCents,
          'currency_code': currencyCode,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>> createEmployeePayment({
    required String employeeId,
    required String projectId,
    required int amountCents,
    required String currencyCode,
    required String description,
    String status = 'pending',
  }) async {
    final response = await _client
        .from('employee_payments')
        .insert({
          'employee_id': employeeId,
          'project_id': projectId,
          'amount_cents': amountCents,
          'currency_code': currencyCode,
          'description': description,
          'status': status,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>> calculateProjectTotal(String projectId) async {
    final financials = await getProjectFinancials(projectId);
    final costs = await getProjectAdditionalCosts(projectId);
    final catalogItems = await getProjectCatalogItems(projectId);

    final currencyCode = financials?['currency_code'] as String? ?? 'BRL';
    final valueCents = financials?['value_cents'] as int? ?? 0;

    int totalCostsCents = 0;
    for (final cost in costs) {
      if (cost['currency_code'] == currencyCode) {
        totalCostsCents += (cost['amount_cents'] as int?) ?? 0;
      }
    }

    int totalCatalogCents = 0;
    for (final item in catalogItems) {
      if (item['currency_code'] == currencyCode) {
        final unitPrice = (item['unit_price_cents'] as int?) ?? 0;
        final quantity = (item['quantity'] as int?) ?? 1;
        totalCatalogCents += unitPrice * quantity;
      }
    }

    final totalCents = valueCents + totalCostsCents + totalCatalogCents;

    return {
      'currency_code': currencyCode,
      'value_cents': valueCents,
      'costs_cents': totalCostsCents,
      'catalog_cents': totalCatalogCents,
      'total_cents': totalCents,
    };
  }
}

final FinanceContract financeModule = FinanceRepository();

