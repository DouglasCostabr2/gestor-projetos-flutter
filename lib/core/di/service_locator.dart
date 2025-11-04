/// Service Locator para Dependency Injection
///
/// Implementa o padrão Service Locator para gerenciar dependências
/// de forma centralizada e desacoplada.
///
/// ## Uso:
///
/// ### 1. Registrar services (no main.dart):
/// ```dart
/// void main() async {
///   // Registrar services
///   serviceLocator.register<IGoogleDriveService>(GoogleDriveService());
///   serviceLocator.register<ITabManager>(TabManager());
///   
///   runApp(MyApp());
/// }
/// ```
///
/// ### 2. Obter services:
/// ```dart
/// // Em qualquer lugar do código
/// final driveService = serviceLocator.get<IGoogleDriveService>();
/// await driveService.getAuthedClient();
/// ```
///
/// ### 3. Registrar factories (para instâncias novas):
/// ```dart
/// serviceLocator.registerFactory<IMyService>(() => MyService());
/// final service = serviceLocator.get<IMyService>(); // Nova instância
/// ```
///
/// ## Vantagens:
/// - Desacoplamento total entre componentes
/// - Fácil de testar (mock de interfaces)
/// - Gerenciamento centralizado de dependências
/// - Suporte a singletons e factories
library;

/// Service Locator singleton para gerenciar dependências
class ServiceLocator {
  // Singleton pattern
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Armazenamento de services (singletons)
  final Map<Type, dynamic> _services = {};
  
  // Armazenamento de factories (para criar novas instâncias)
  final Map<Type, Function> _factories = {};

  /// Registra um service singleton
  /// 
  /// O mesmo service será retornado sempre que solicitado.
  /// 
  /// Exemplo:
  /// ```dart
  /// serviceLocator.register<IGoogleDriveService>(GoogleDriveService());
  /// ```
  void register<T>(T service) {
    _services[T] = service;
  }

  /// Registra uma factory para criar novas instâncias
  /// 
  /// Uma nova instância será criada cada vez que solicitado.
  /// 
  /// Exemplo:
  /// ```dart
  /// serviceLocator.registerFactory<IMyService>(() => MyService());
  /// ```
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Obtém um service registrado
  /// 
  /// Lança exceção se o service não estiver registrado.
  /// 
  /// Exemplo:
  /// ```dart
  /// final driveService = serviceLocator.get<IGoogleDriveService>();
  /// ```
  T get<T>() {
    // Primeiro tenta obter de singletons
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    
    // Depois tenta criar via factory
    if (_factories.containsKey(T)) {
      final factory = _factories[T] as T Function();
      return factory();
    }
    
    throw ServiceNotRegisteredException(T);
  }

  /// Tenta obter um service, retorna null se não encontrado
  /// 
  /// Exemplo:
  /// ```dart
  /// final service = serviceLocator.tryGet<IMyService>();
  /// if (service != null) {
  ///   // Usar service
  /// }
  /// ```
  T? tryGet<T>() {
    try {
      return get<T>();
    } catch (_) {
      return null;
    }
  }

  /// Verifica se um service está registrado
  /// 
  /// Exemplo:
  /// ```dart
  /// if (serviceLocator.isRegistered<IMyService>()) {
  ///   // Service está disponível
  /// }
  /// ```
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }

  /// Remove um service registrado
  /// 
  /// Útil para testes ou para substituir implementações.
  /// 
  /// Exemplo:
  /// ```dart
  /// serviceLocator.unregister<IMyService>();
  /// ```
  void unregister<T>() {
    _services.remove(T);
    _factories.remove(T);
  }

  /// Remove todos os services registrados
  /// 
  /// Útil para testes.
  /// 
  /// Exemplo:
  /// ```dart
  /// serviceLocator.reset();
  /// ```
  void reset() {
    _services.clear();
    _factories.clear();
  }

  /// Retorna lista de todos os types registrados
  /// 
  /// Útil para debug.
  List<Type> get registeredTypes {
    return [..._services.keys, ..._factories.keys];
  }
}

/// Exceção lançada quando um service não está registrado
class ServiceNotRegisteredException implements Exception {
  final Type type;
  
  ServiceNotRegisteredException(this.type);
  
  @override
  String toString() {
    return 'ServiceNotRegisteredException: Service of type $type is not registered.\n'
        'Make sure to register it before using:\n'
        'serviceLocator.register<$type>(${type}Implementation());';
  }
}

/// Instância global do Service Locator
/// 
/// Use esta instância em todo o aplicativo.
/// 
/// Exemplo:
/// ```dart
/// // Registrar
/// serviceLocator.register<IMyService>(MyService());
/// 
/// // Obter
/// final service = serviceLocator.get<IMyService>();
/// ```
final serviceLocator = ServiceLocator();

