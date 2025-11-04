import 'package:flutter/foundation.dart';
import '../tab_item.dart';

/// Interface para o gerenciador de abas
///
/// Define o contrato público para gerenciamento de abas no aplicativo.
/// Permite desacoplamento e facilita testes com mocks.
///
/// ## Implementações:
/// - `TabManager` - Implementação principal
/// - `MockTabManager` - Mock para testes
///
/// ## Uso:
/// ```dart
/// final tabManager = serviceLocator.get<ITabManager>();
/// tabManager.addTab(TabItem(...));
/// ```
abstract class ITabManager extends ChangeNotifier {
  // ========== GETTERS ==========

  /// Lista de todas as abas abertas (somente leitura)
  List<TabItem> get tabs;

  /// Índice da aba atualmente selecionada
  int get currentIndex;

  /// Aba atualmente selecionada (null se não houver abas)
  TabItem? get currentTab;

  // ========== NAVEGAÇÃO ==========

  /// Verifica se a aba atual pode voltar no histórico
  ///
  /// Retorna true se há histórico disponível para voltar.
  bool canGoBack();

  /// Volta para a página anterior na aba atual
  ///
  /// Remove o último item do histórico e restaura a aba anterior.
  /// Não faz nada se não houver histórico.
  void goBack();

  // ========== GERENCIAMENTO DE ABAS ==========

  /// Adiciona uma nova aba
  ///
  /// Parâmetros:
  /// - [tab]: Aba a ser adicionada
  /// - [allowDuplicates]: Se false, não adiciona se já existir aba com mesmo ID
  ///
  /// Se [allowDuplicates] for false e já existir uma aba com o mesmo ID,
  /// apenas seleciona a aba existente em vez de criar uma nova.
  void addTab(TabItem tab, {bool allowDuplicates = false});

  /// Remove uma aba pelo índice
  ///
  /// Parâmetros:
  /// - [index]: Índice da aba a ser removida
  ///
  /// Se a aba removida for a atual, seleciona a aba anterior.
  /// Se for a primeira aba, seleciona a próxima.
  void removeTab(int index);

  /// Seleciona uma aba pelo índice
  ///
  /// Parâmetros:
  /// - [index]: Índice da aba a ser selecionada
  void selectTab(int index);

  /// Seleciona uma aba pelo ID
  ///
  /// Parâmetros:
  /// - [id]: ID da aba a ser selecionada
  ///
  /// Não faz nada se não encontrar aba com o ID especificado.
  void selectTabById(String id);

  // ========== ATUALIZAÇÃO DE ABAS ==========

  /// Atualiza o título de uma aba
  ///
  /// Parâmetros:
  /// - [id]: ID da aba
  /// - [newTitle]: Novo título
  void updateTabTitle(String id, String newTitle);

  /// Atualiza uma aba completamente
  ///
  /// Parâmetros:
  /// - [index]: Índice da aba
  /// - [newTab]: Nova aba
  /// - [saveToHistory]: Se true, salva a aba atual no histórico
  ///
  /// Se [saveToHistory] for true, a aba atual é salva no histórico
  /// antes de ser substituída, permitindo voltar com goBack().
  void updateTab(int index, TabItem newTab, {bool saveToHistory = true});

  // ========== OPERAÇÕES EM LOTE ==========

  /// Fecha todas as abas exceto a especificada
  ///
  /// Parâmetros:
  /// - [index]: Índice da aba a manter aberta
  void closeOtherTabs(int index);

  /// Fecha todas as abas que podem ser fechadas
  ///
  /// Mantém apenas abas com canClose = false.
  void closeAllTabs();

  /// Limpa todas as abas e histórico
  ///
  /// Remove TODAS as abas (incluindo as que não podem ser fechadas)
  /// e limpa todo o histórico. Usado principalmente no logout para
  /// garantir que o próximo usuário não veja as abas do usuário anterior.
  void clearAllTabs();
}

