/// Contrato público do módulo de catálogo
/// Define as operações disponíveis para gestão de produtos e pacotes
/// 
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de catálogo.
/// Nenhum código externo deve acessar a implementação interna diretamente.
abstract class CatalogContract {
  /// Buscar todos os produtos
  Future<List<Map<String, dynamic>>> getProducts();

  /// Buscar produto por ID
  Future<Map<String, dynamic>?> getProductById(String productId);

  /// Buscar todos os pacotes
  Future<List<Map<String, dynamic>>> getPackages();

  /// Buscar pacote por ID
  Future<Map<String, dynamic>?> getPackageById(String packageId);

  /// Buscar categorias de produtos
  Future<List<Map<String, dynamic>>> getCategories();

  /// Criar um novo produto
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
  });

  /// Atualizar um produto
  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required Map<String, dynamic> updates,
  });

  /// Deletar um produto
  Future<void> deleteProduct(String productId);

  /// Criar um novo pacote
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
  });

  /// Atualizar um pacote
  Future<Map<String, dynamic>> updatePackage({
    required String packageId,
    required Map<String, dynamic> updates,
  });

  /// Deletar um pacote
  Future<void> deletePackage(String packageId);
}

