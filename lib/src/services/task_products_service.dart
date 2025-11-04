import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço utilitário para carregar e salvar vínculos de produtos de uma task.
/// Reutilizado por QuickTaskForm e SubTaskFormDialog.
class TaskProductsService {
  /// Carrega os produtos vinculados a uma task já resolvendo o comentário atual
  /// do catálogo do projeto (project_catalog_items ou package_items), para que
  /// mudanças no projeto se reflitam automaticamente na task.
  /// Retorna a lista no formato usado pelos formulários:
  /// { productId, packageId, label, packageName, comment, thumbUrl }
  static Future<List<Map<String, dynamic>>> loadLinkedProducts(
    String taskId, {
    required String projectId,
  }) async {
    final client = Supabase.instance.client;
    try {
      // 1) Buscar vínculos task_products
      final rows = await client
          .from('task_products')
          .select('product_id, package_id')
          .eq('task_id', taskId);
      if (rows.isEmpty) return [];

      // Coletar ids
      final productIds = <String>{};
      final packageIds = <String>{};
      final prodPkgPairs = <String>{}; // key: productId:packageId
      for (final row in rows) {
        final pid = (row['product_id'] ?? '').toString();
        final pkg = (row['package_id'] ?? '').toString();
        if (pid.isEmpty) continue;
        productIds.add(pid);
        if (pkg.isNotEmpty) {
          packageIds.add(pkg);
          prodPkgPairs.add('$pid:$pkg');
        }
      }

      // 2) Buscar detalhes dos produtos (nome e thumb)
      final nameByProduct = <String, String>{};
      final thumbByProduct = <String, String?>{};
      if (productIds.isNotEmpty) {
        final inList = productIds.map((e) => '"$e"').join(',');
        final prods = await client
            .from('products')
            .select('id, name, image_url, image_thumb_url')
            .filter('id', 'in', '($inList)');
        for (final p in (prods as List)) {
          final id = (p['id'] ?? '').toString();
          nameByProduct[id] = (p['name'] ?? '-') as String;
          thumbByProduct[id] = (p['image_thumb_url'] as String?) ?? (p['image_url'] as String?);
        }
      }

      // 3) Buscar comentários atuais do catálogo do projeto
      // 3a) Produtos diretos do catálogo
      final commentByProduct = <String, String?>{}; // productId -> comment
      final directProductIds = rows
          .where((r) => (r['package_id'] == null || (r['package_id'] as String).isEmpty))
          .map((r) => (r['product_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (directProductIds.isNotEmpty) {
        final inList = directProductIds.map((e) => '"$e"').join(',');
        final cat = await client
            .from('project_catalog_items')
            .select('item_id, comment')
            .eq('project_id', projectId)
            .eq('kind', 'product')
            .filter('item_id', 'in', '($inList)');
        for (final r in (cat as List)) {
          final id = (r['item_id'] ?? '').toString();
          commentByProduct[id] = r['comment'] as String?;
        }
      }

      // 3b) Produtos vindos de pacotes (comentário está em package_items)
      final commentByProdPkg = <String, String?>{}; // productId:packageId -> comment
      if (packageIds.isNotEmpty) {
        final inPkg = packageIds.map((e) => '"$e"').join(',');
        final pkgItems = await client
            .from('package_items')
            .select('package_id, product_id, comment')
            .filter('package_id', 'in', '($inPkg)');
        for (final r in (pkgItems as List)) {
          final pkgId = (r['package_id'] ?? '').toString();
          final pid = (r['product_id'] ?? '').toString();
          if (pid.isEmpty || pkgId.isEmpty) continue;
          final key = '$pid:$pkgId';
          if (prodPkgPairs.contains(key)) {
            commentByProdPkg[key] = r['comment'] as String?;
          }
        }
      }

      // 4) Nomes dos pacotes para exibir no cartão
      final packageNameById = <String, String>{};
      if (packageIds.isNotEmpty) {
        final inList = packageIds.map((e) => '"$e"').join(',');
        final rowsPkg = await client
            .from('packages')
            .select('id, name')
            .filter('id', 'in', '($inList)');
        for (final r in (rowsPkg as List)) {
          packageNameById[(r['id'] ?? '').toString()] = (r['name'] ?? '-') as String;
        }
      }

      // 5) Montar saída
      final out = <Map<String, dynamic>>[];
      for (final row in rows) {
        final productId = (row['product_id'] ?? '').toString();
        if (productId.isEmpty) continue;
        final packageId = (row['package_id'] ?? '').toString();
        final isPkg = packageId.isNotEmpty;
        final label = nameByProduct[productId] ?? '-';
        final comment = isPkg
            ? (commentByProdPkg['$productId:$packageId'] ?? '')
            : (commentByProduct[productId] ?? '');
        out.add({
          'productId': productId,
          'packageId': isPkg ? packageId : null,
          'label': label,
          'packageName': isPkg ? (packageNameById[packageId] ?? '-') : null,
          'comment': comment,
          'thumbUrl': thumbByProduct[productId],
        });
      }

      return out;
    } catch (e) {
      debugPrint('Erro ao carregar task_products: $e');
      return [];
    }
  }

  /// Salva os vínculos de produtos para uma task (substitui os existentes)
  static Future<void> saveLinkedProducts({
    required String taskId,
    required List<Map<String, dynamic>> linkedProducts,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    try {
      // Buscar produtos vinculados anteriormente para comparar
      final oldProducts = await client
          .from('task_products')
          .select('product_id, package_id')
          .eq('task_id', taskId);

      final oldProductKeys = (oldProducts as List).map((p) {
        final productId = p['product_id'] as String;
        final packageId = p['package_id'] as String?;
        return '$productId:${packageId ?? ""}';
      }).toSet();

      final newProductKeys = linkedProducts.map((p) {
        final productId = p['productId'] as String;
        final packageId = p['packageId'] as String?;
        return '$productId:${packageId ?? ""}';
      }).toSet();

      // Remover vínculos atuais
      await client.from('task_products').delete().eq('task_id', taskId);

      // Inserir novos
      if (linkedProducts.isNotEmpty) {
        final inserts = linkedProducts.map((p) => {
              'task_id': taskId,
              'product_id': p['productId'],
              'package_id': p['packageId'],
              if (userId != null) 'created_by': userId,
            }).toList();
        await client.from('task_products').insert(inserts);
      }

      // Registrar no histórico apenas produtos que foram adicionados
      if (userId != null) {
        final addedProducts = linkedProducts.where((p) {
          final productId = p['productId'] as String;
          final packageId = p['packageId'] as String?;
          final key = '$productId:${packageId ?? ""}';
          return !oldProductKeys.contains(key);
        }).toList();

        for (final product in addedProducts) {
          try {
            final label = product['label'] as String? ?? 'Produto';
            final packageName = product['packageName'] as String?;
            final productLabel = packageName != null && packageName.isNotEmpty
                ? '$label ($packageName)'
                : label;

            await client.from('task_history').insert({
              'task_id': taskId,
              'user_id': userId,
              'action': 'updated',
              'field_name': 'product_linked',
              'old_value': null,
              'new_value': productLabel,
            });
          } catch (e) {
            debugPrint('Erro ao registrar histórico de vinculação: $e');
          }
        }

        // Registrar produtos removidos
        final removedProductKeys = oldProductKeys.difference(newProductKeys);
        if (removedProductKeys.isNotEmpty) {
          // Buscar labels dos produtos removidos
          final oldProductsList = (oldProducts as List).where((p) {
            final productId = p['product_id'] as String;
            final packageId = p['package_id'] as String?;
            final key = '$productId:${packageId ?? ""}';
            return removedProductKeys.contains(key);
          }).toList();

          for (final oldProduct in oldProductsList) {
            try {
              // Buscar nome do produto
              final productId = oldProduct['product_id'] as String;
              final packageId = oldProduct['package_id'] as String?;

              final productData = await client
                  .from('products')
                  .select('name')
                  .eq('id', productId)
                  .maybeSingle();

              String productLabel = productData?['name'] as String? ?? 'Produto';

              if (packageId != null && packageId.isNotEmpty) {
                final packageData = await client
                    .from('packages')
                    .select('name')
                    .eq('id', packageId)
                    .maybeSingle();
                final packageName = packageData?['name'] as String?;
                if (packageName != null && packageName.isNotEmpty) {
                  productLabel = '$productLabel ($packageName)';
                }
              }

              await client.from('task_history').insert({
                'task_id': taskId,
                'user_id': userId,
                'action': 'updated',
                'field_name': 'product_unlinked',
                'old_value': productLabel,
                'new_value': null,
              });
            } catch (e) {
              debugPrint('Erro ao registrar histórico de desvinculação: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Falha ao salvar task_products: $e');
      rethrow;
    }
  }
}

