import 'package:flutter/foundation.dart';

/// Controller para gerenciar paginação de dados
/// 
/// OTIMIZAÇÃO: Permite carregar dados em lotes para melhorar performance
/// 
/// Uso:
/// ```dart
/// final _paginationController = PaginationController(
///   pageSize: 50,
///   onLoadPage: (offset, limit) async {
///     return await supabase.from('tasks')
///       .select('*')
///       .range(offset, offset + limit - 1);
///   },
/// );
/// 
/// // Carregar primeira página
/// await _paginationController.loadFirstPage();
/// 
/// // Carregar próxima página
/// await _paginationController.loadNextPage();
/// ```
class PaginationController<T> extends ChangeNotifier {
  /// Tamanho da página (quantos itens por página)
  final int pageSize;
  
  /// Função para carregar uma página de dados
  /// Recebe offset e limit, retorna lista de itens
  final Future<List<T>> Function(int offset, int limit) onLoadPage;
  
  /// Itens carregados até agora
  List<T> _items = [];
  List<T> get items => _items;
  
  /// Página atual (0-based)
  int _currentPage = 0;
  int get currentPage => _currentPage;
  
  /// Se está carregando dados
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  /// Se há mais páginas para carregar
  bool _hasMore = true;
  bool get hasMore => _hasMore;
  
  /// Erro durante carregamento
  String? _error;
  String? get error => _error;
  
  PaginationController({
    required this.pageSize,
    required this.onLoadPage,
  });
  
  /// Carregar primeira página (limpa dados existentes)
  Future<void> loadFirstPage() async {
    _currentPage = 0;
    _items = [];
    _hasMore = true;
    _error = null;
    await _loadPage();
  }
  
  /// Carregar próxima página (adiciona aos dados existentes)
  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoading) return;
    _currentPage++;
    await _loadPage();
  }
  
  /// Recarregar página atual
  Future<void> reload() async {
    await loadFirstPage();
  }
  
  /// Carregar página atual
  Future<void> _loadPage() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final offset = _currentPage * pageSize;
      final newItems = await onLoadPage(offset, pageSize);
      
      if (_currentPage == 0) {
        _items = newItems;
      } else {
        _items.addAll(newItems);
      }
      
      // Se retornou menos itens que o pageSize, não há mais páginas
      _hasMore = newItems.length >= pageSize;
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Limpar todos os dados
  void clear() {
    _items = [];
    _currentPage = 0;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
}

