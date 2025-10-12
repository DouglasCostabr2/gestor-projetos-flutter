/// Contrato público do módulo de produtos e pacotes
///
/// Define as operações disponíveis para gestão de produtos e pacotes do catálogo.
/// Produtos e pacotes são itens que podem ser adicionados a projetos.
///
/// IMPORTANTE: Este é o ÚNICO ponto de comunicação com o módulo de produtos.
/// Nenhum código externo deve acessar a implementação interna diretamente.
///
/// Exemplo de uso:
/// ```dart
/// // Buscar produtos em BRL
/// final products = await productsModule.getProductsByCurrency('BRL');
///
/// // Criar novo produto
/// final newProduct = await productsModule.createProduct(
///   name: 'Logo Design',
///   priceCents: 50000, // R$ 500,00
///   currencyCode: 'BRL',
///   description: 'Design de logotipo profissional',
/// );
/// ```
abstract class ProductsContract {
  /// Buscar produtos filtrados por moeda
  ///
  /// Retorna lista de produtos que possuem a moeda especificada.
  /// Útil para exibir apenas produtos compatíveis com a moeda do projeto.
  ///
  /// Parâmetros:
  /// - [currencyCode]: Código da moeda (ex: 'BRL', 'USD', 'EUR')
  ///
  /// Retorna: Lista de produtos ordenados por nome
  ///
  /// Exemplo:
  /// ```dart
  /// final products = await productsModule.getProductsByCurrency('BRL');
  /// ```
  Future<List<Map<String, dynamic>>> getProductsByCurrency(String currencyCode);

  /// Buscar pacotes filtrados por moeda
  ///
  /// Retorna lista de pacotes que possuem a moeda especificada.
  /// Útil para exibir apenas pacotes compatíveis com a moeda do projeto.
  ///
  /// Parâmetros:
  /// - [currencyCode]: Código da moeda (ex: 'BRL', 'USD', 'EUR')
  ///
  /// Retorna: Lista de pacotes ordenados por nome
  ///
  /// Exemplo:
  /// ```dart
  /// final packages = await productsModule.getPackagesByCurrency('USD');
  /// ```
  Future<List<Map<String, dynamic>>> getPackagesByCurrency(String currencyCode);

  /// Buscar todos os produtos
  ///
  /// Retorna lista completa de produtos cadastrados, independente da moeda.
  ///
  /// Retorna: Lista de todos os produtos ordenados por nome
  Future<List<Map<String, dynamic>>> getProducts();

  /// Buscar todos os pacotes
  ///
  /// Retorna lista completa de pacotes cadastrados, independente da moeda.
  ///
  /// Retorna: Lista de todos os pacotes ordenados por nome
  Future<List<Map<String, dynamic>>> getPackages();

  /// Criar novo produto
  ///
  /// Parâmetros:
  /// - [name]: Nome do produto (obrigatório)
  /// - [priceCents]: Preço em centavos (obrigatório, ex: 50000 = R$ 500,00)
  /// - [currencyCode]: Código da moeda (obrigatório, ex: 'BRL')
  /// - [description]: Descrição do produto (opcional)
  ///
  /// Retorna: Produto criado com todos os campos
  ///
  /// Exemplo:
  /// ```dart
  /// final product = await productsModule.createProduct(
  ///   name: 'Logo Design',
  ///   priceCents: 50000,
  ///   currencyCode: 'BRL',
  ///   description: 'Design profissional de logotipo',
  /// );
  /// ```
  Future<Map<String, dynamic>> createProduct({
    required String name,
    required int priceCents,
    required String currencyCode,
    String? description,
  });

  /// Criar novo pacote
  ///
  /// Parâmetros:
  /// - [name]: Nome do pacote (obrigatório)
  /// - [priceCents]: Preço em centavos (obrigatório, ex: 100000 = R$ 1.000,00)
  /// - [currencyCode]: Código da moeda (obrigatório, ex: 'BRL')
  /// - [description]: Descrição do pacote (opcional)
  ///
  /// Retorna: Pacote criado com todos os campos
  ///
  /// Exemplo:
  /// ```dart
  /// final package = await productsModule.createPackage(
  ///   name: 'Pacote Completo',
  ///   priceCents: 100000,
  ///   currencyCode: 'BRL',
  ///   description: 'Logo + Cartão + Site',
  /// );
  /// ```
  Future<Map<String, dynamic>> createPackage({
    required String name,
    required int priceCents,
    required String currencyCode,
    String? description,
  });

  /// Atualizar produto existente
  ///
  /// Parâmetros:
  /// - [productId]: ID do produto a ser atualizado (obrigatório)
  /// - [updates]: Mapa com campos a serem atualizados (obrigatório)
  ///
  /// Retorna: Produto atualizado
  ///
  /// Exemplo:
  /// ```dart
  /// final updated = await productsModule.updateProduct(
  ///   productId: 'abc-123',
  ///   updates: {'name': 'Novo Nome', 'priceCents': 60000},
  /// );
  /// ```
  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    required Map<String, dynamic> updates,
  });

  /// Atualizar pacote existente
  ///
  /// Parâmetros:
  /// - [packageId]: ID do pacote a ser atualizado (obrigatório)
  /// - [updates]: Mapa com campos a serem atualizados (obrigatório)
  ///
  /// Retorna: Pacote atualizado
  ///
  /// Exemplo:
  /// ```dart
  /// final updated = await productsModule.updatePackage(
  ///   packageId: 'xyz-789',
  ///   updates: {'description': 'Nova descrição'},
  /// );
  /// ```
  Future<Map<String, dynamic>> updatePackage({
    required String packageId,
    required Map<String, dynamic> updates,
  });

  /// Deletar produto
  ///
  /// Remove permanentemente um produto do catálogo.
  ///
  /// Parâmetros:
  /// - [productId]: ID do produto a ser deletado
  ///
  /// Exemplo:
  /// ```dart
  /// await productsModule.deleteProduct('abc-123');
  /// ```
  Future<void> deleteProduct(String productId);

  /// Deletar pacote
  ///
  /// Remove permanentemente um pacote do catálogo.
  ///
  /// Parâmetros:
  /// - [packageId]: ID do pacote a ser deletado
  ///
  /// Exemplo:
  /// ```dart
  /// await productsModule.deletePackage('xyz-789');
  /// ```
  Future<void> deletePackage(String packageId);
}

