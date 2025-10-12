/// Ponto de entrada do módulo de produtos e pacotes
/// 
/// Este arquivo exporta APENAS o contrato e a instância singleton.
/// A implementação interna permanece privada ao módulo.
library;

export 'contract.dart';
import 'repository.dart';
import 'contract.dart';

/// Instância ÚNICA do módulo de produtos
/// Use esta instância em todo o código ao invés de criar novas instâncias
final ProductsContract productsModule = ProductsRepository();

