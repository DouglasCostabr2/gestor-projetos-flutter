import 'package:flutter/material.dart';
import 'tab_item.dart';
import 'interfaces/tab_manager_interface.dart';

/// Gerenciador de abas que mantém o estado de todas as abas abertas
///
/// Implementa a interface ITabManager para permitir desacoplamento
/// e facilitar testes com mocks.
class TabManager extends ChangeNotifier implements ITabManager {
  final List<TabItem> _tabs = [];
  int _currentIndex = 0;

  // Histórico de navegação para cada aba (índice da aba -> lista de TabItems)
  final Map<int, List<TabItem>> _tabHistory = {};

  @override
  List<TabItem> get tabs => List.unmodifiable(_tabs);

  @override
  int get currentIndex => _currentIndex;

  @override
  TabItem? get currentTab => _tabs.isEmpty ? null : _tabs[_currentIndex];

  /// Verifica se a aba atual pode voltar
  @override
  bool canGoBack() {
    if (_currentIndex < 0 || _currentIndex >= _tabs.length) return false;
    final history = _tabHistory[_currentIndex];
    return history != null && history.isNotEmpty;
  }

  /// Volta para a página anterior na aba atual
  @override
  void goBack() {
    if (!canGoBack()) return;

    final history = _tabHistory[_currentIndex]!;
    final previousTab = history.removeLast();

    debugPrint('⬅️ TabManager.goBack:');
    debugPrint('   Voltando de "${_tabs[_currentIndex].id}" para "${previousTab.id}"');
    debugPrint('   Histórico restante: ${history.map((t) => t.id).toList()}');

    _tabs[_currentIndex] = previousTab;
    notifyListeners();
  }

  /// Adiciona uma nova aba
  @override
  void addTab(TabItem tab, {bool allowDuplicates = false}) {
    debugPrint('🔍 TabManager.addTab chamado:');
    debugPrint('   ID da nova aba: "${tab.id}"');
    debugPrint('   allowDuplicates: $allowDuplicates');
    debugPrint('   Abas existentes (${_tabs.length}): ${_tabs.map((t) => t.id).toList()}');

    if (!allowDuplicates) {
      // Verifica se já existe uma aba com o mesmo ID
      final existingIndex = _tabs.indexWhere((t) => t.id == tab.id);
      debugPrint('   Procurando aba com ID "${tab.id}"...');
      debugPrint('   Índice encontrado: $existingIndex');

      if (existingIndex != -1) {
        // Se já existe, apenas seleciona ela
        debugPrint('   ✅ ABA JÁ EXISTE! Selecionando aba no índice $existingIndex');
        _currentIndex = existingIndex;
        notifyListeners();
        return;
      }
    }

    // Adiciona nova aba e seleciona
    debugPrint('   ➕ CRIANDO NOVA ABA');
    _tabs.add(tab);
    _currentIndex = _tabs.length - 1;
    debugPrint('   Total de abas agora: ${_tabs.length}');
    debugPrint('   Abas: ${_tabs.map((t) => t.id).toList()}');

    notifyListeners();
  }

  /// Remove uma aba pelo índice
  @override
  void removeTab(int index) {
    debugPrint('🗑️ TabManager.removeTab chamado:');
    debugPrint('   Índice a remover: $index');
    debugPrint('   Abas antes: ${_tabs.map((t) => t.id).toList()}');

    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];
    if (!tab.canClose) return;

    _tabs.removeAt(index);

    // Limpar histórico da aba removida
    _tabHistory.remove(index);

    // Reindexar históricos (mover índices maiores para baixo)
    final newHistory = <int, List<TabItem>>{};
    _tabHistory.forEach((key, value) {
      if (key > index) {
        newHistory[key - 1] = value;
      } else if (key < index) {
        newHistory[key] = value;
      }
    });
    _tabHistory.clear();
    _tabHistory.addAll(newHistory);

    debugPrint('   Aba "${tab.id}" removida');
    debugPrint('   Abas depois: ${_tabs.map((t) => t.id).toList()}');

    // Ajusta o índice atual
    if (_tabs.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= _tabs.length) {
      _currentIndex = _tabs.length - 1;
    } else if (index < _currentIndex) {
      _currentIndex--;
    }

    notifyListeners();
  }

  /// Remove uma aba pelo ID
  void removeTabById(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      removeTab(index);
    }
  }

  /// Seleciona uma aba pelo índice
  @override
  void selectTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Seleciona uma aba pelo ID
  @override
  void selectTabById(String id) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      selectTab(index);
    }
  }

  /// Atualiza o título de uma aba
  @override
  void updateTabTitle(String id, String newTitle) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tabs[index] = _tabs[index].copyWith(title: newTitle);
      notifyListeners();
    }
  }

  /// Atualiza o conteúdo completo de uma aba
  void updateTabContent(int index, Widget page, String title, IconData icon) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index] = _tabs[index].copyWith(
        page: page,
        title: title,
        icon: icon,
      );
      notifyListeners();
    }
  }

  /// Atualiza uma aba completamente (incluindo ID)
  @override
  void updateTab(int index, TabItem newTab, {bool saveToHistory = true}) {
    if (index >= 0 && index < _tabs.length) {
      // Salvar a aba atual no histórico antes de atualizar
      if (saveToHistory) {
        final currentTab = _tabs[index];
        _tabHistory[index] ??= [];
        _tabHistory[index]!.add(currentTab);

        debugPrint('📚 TabManager.updateTab: Salvando no histórico');
        debugPrint('   Aba anterior: "${currentTab.id}"');
        debugPrint('   Nova aba: "${newTab.id}"');
        debugPrint('   Histórico da aba $index: ${_tabHistory[index]!.map((t) => t.id).toList()}');
      }

      _tabs[index] = newTab;
      notifyListeners();
    }
  }

  /// Fecha todas as abas exceto a especificada
  @override
  void closeOtherTabs(int index) {
    if (index < 0 || index >= _tabs.length) return;
    
    final tabToKeep = _tabs[index];
    _tabs.clear();
    _tabs.add(tabToKeep);
    _currentIndex = 0;
    
    notifyListeners();
  }

  /// Fecha todas as abas
  @override
  void closeAllTabs() {
    _tabs.removeWhere((tab) => tab.canClose);

    if (_tabs.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= _tabs.length) {
      _currentIndex = _tabs.length - 1;
    }

    notifyListeners();
  }

  /// Limpa todas as abas e histórico
  @override
  void clearAllTabs() {
    debugPrint('🧹 TabManager.clearAllTabs: Limpando todas as abas e histórico');
    _tabs.clear();
    _tabHistory.clear();
    _currentIndex = 0;
    notifyListeners();
  }
}

