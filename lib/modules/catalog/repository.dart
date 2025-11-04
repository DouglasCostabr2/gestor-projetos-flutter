import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../common/organization_context.dart';
import 'contract.dart';

/// Implementação do contrato de catálogo
class CatalogRepository implements CatalogContract {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        debugPrint('⚠️ Nenhuma organização ativa - retornando lista vazia');
        return [];
      }

      final response = await _client
          .from('products')
          .select('''
            *,
            created_by_profile:created_by(id, full_name, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .eq('organization_id', orgId)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar produtos: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar produto por ID: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPackages() async {
    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        debugPrint('⚠️ Nenhuma organização ativa - retornando lista vazia');
        return [];
      }

      final response = await _client
          .from('packages')
          .select('''
            *,
            created_by_profile:created_by(id, full_name, avatar_url),
            updated_by_profile:updated_by(id, full_name, avatar_url)
          ''')
          .eq('organization_id', orgId)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar pacotes: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getPackageById(String packageId) async {
    try {
      final response = await _client
          .from('packages')
          .select('*')
          .eq('id', packageId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Erro ao buscar pacote por ID: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final orgId = OrganizationContext.currentOrganizationId;
      if (orgId == null) {
        debugPrint('⚠️ Nenhuma organização ativa - retornando lista vazia');
        return [];
      }

      final response = await _client
          .from('product_categories')
          .select('*')
          .eq('organization_id', orgId)
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar categorias: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createProduct({
    required String name,
    String? description,
    String? category,
    String? categoryId,
    String currencyCode = 'BRL',
    int priceCents = 0,
    Map<String, dynamic>? priceMap,
    String? imageUrl,
    String? imageDriveFileId,
    String? imageThumbUrl,
  }) async {
    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    final productData = <String, dynamic>{
      'name': name.trim(),
      'description': description?.trim(),
      'category': category,
      'category_id': categoryId,
      'currency_code': currencyCode,
      'price_cents': priceCents,
      'organization_id': orgId,
      if (priceMap != null) 'price_map': priceMap,
      'image_url': imageUrl,
      'image_drive_file_id': imageDriveFileId,
      'image_thumb_url': imageThumbUrl,
    };

    debugPrint('🛍️ Criando produto: $name (org: $orgId)');

    final response = await _client
        .from('products')
        .insert(productData)
        .select()
        .single();

    debugPrint('✅ Produto criado com sucesso: ${response['id']}');

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
  Future<void> deleteProduct(String productId) async {
    await _client
        .from('products')
        .delete()
        .eq('id', productId);
  }

  @override
  Future<Map<String, dynamic>> createPackage({
    required String name,
    String? description,
    String? category,
    String? categoryId,
    String currencyCode = 'BRL',
    int priceCents = 0,
    Map<String, dynamic>? priceMap,
    String? imageUrl,
    String? imageDriveFileId,
    String? imageThumbUrl,
  }) async {
    final orgId = OrganizationContext.currentOrganizationId;
    if (orgId == null) throw Exception('Nenhuma organização ativa');

    final packageData = <String, dynamic>{
      'name': name.trim(),
      'description': description?.trim(),
      'category': category,
      'category_id': categoryId,
      'currency_code': currencyCode,
      'price_cents': priceCents,
      'organization_id': orgId,
      if (priceMap != null) 'price_map': priceMap,
      'image_url': imageUrl,
      'image_drive_file_id': imageDriveFileId,
      'image_thumb_url': imageThumbUrl,
    };

    debugPrint('📦 Criando pacote: $name (org: $orgId)');

    final response = await _client
        .from('packages')
        .insert(packageData)
        .select()
        .single();

    debugPrint('✅ Pacote criado com sucesso: ${response['id']}');

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
  Future<void> deletePackage(String packageId) async {
    await _client
        .from('packages')
        .delete()
        .eq('id', packageId);
  }
}

final CatalogContract catalogModule = CatalogRepository();

