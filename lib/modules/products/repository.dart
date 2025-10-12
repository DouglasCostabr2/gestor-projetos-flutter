import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import 'contract.dart';

/// Implementação do contrato de produtos e pacotes
class ProductsRepository implements ProductsContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getProductsByCurrency(String currencyCode) async {
    try {
      final response = await _client
          .from('products')
          .select('id, name, price_cents, currency_code')
          .eq('currency_code', currencyCode)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar produtos por moeda: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPackagesByCurrency(String currencyCode) async {
    try {
      final response = await _client
          .from('packages')
          .select('id, name, price_cents, currency_code')
          .eq('currency_code', currencyCode)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pacotes por moeda: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await _client
          .from('products')
          .select('*')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar produtos: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPackages() async {
    try {
      final response = await _client
          .from('packages')
          .select('*')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pacotes: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createProduct({
    required String name,
    required int priceCents,
    required String currencyCode,
    String? description,
  }) async {
    final response = await _client
        .from('products')
        .insert({
          'name': name,
          'price_cents': priceCents,
          'currency_code': currencyCode,
          if (description != null) 'description': description,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>> createPackage({
    required String name,
    required int priceCents,
    required String currencyCode,
    String? description,
  }) async {
    final response = await _client
        .from('packages')
        .insert({
          'name': name,
          'price_cents': priceCents,
          'currency_code': currencyCode,
          if (description != null) 'description': description,
        })
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _client
        .from('products')
        .update(updates)
        .eq('id', productId)
        .select()
        .single();
    return response;
  }

  @override
  Future<Map<String, dynamic>> updatePackage({
    required String packageId,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _client
        .from('packages')
        .update(updates)
        .eq('id', packageId)
        .select()
        .single();
    return response;
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await _client
        .from('products')
        .delete()
        .eq('id', productId);
  }

  @override
  Future<void> deletePackage(String packageId) async {
    await _client
        .from('packages')
        .delete()
        .eq('id', packageId);
  }
}

