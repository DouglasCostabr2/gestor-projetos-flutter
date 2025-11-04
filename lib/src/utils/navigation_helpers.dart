import 'package:flutter/material.dart';
import '../navigation/tab_manager_scope.dart';
import '../navigation/tab_item.dart';
import '../features/tasks/task_detail_page.dart';
import '../features/projects/project_detail_page.dart';
import '../features/clients/client_detail_page.dart';

/// Helpers de navegação reutilizáveis para todo o app
/// Centraliza a lógica de navegação entre páginas usando TabManager
class NavigationHelpers {
  /// Navega para a página de detalhes de uma tarefa
  /// Atualiza a aba atual em vez de criar uma nova
  /// 
  /// Parâmetros:
  /// - [context]: BuildContext para acessar o TabManager
  /// - [taskId]: ID da tarefa
  /// - [taskTitle]: Título da tarefa (usado como título da aba)
  static void navigateToTaskDetail(
    BuildContext context,
    String taskId,
    String taskTitle,
  ) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager == null) return;

    final tabId = 'task_$taskId';
    final currentTab = tabManager.currentTab;
    
    final updatedTab = TabItem(
      id: tabId,
      title: taskTitle,
      icon: Icons.task,
      page: TaskDetailPage(
        key: ValueKey('task_$taskId'),
        taskId: taskId,
      ),
      canClose: true,
      selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0,
    );
    
    tabManager.updateTab(tabManager.currentIndex, updatedTab);
  }

  /// Navega para a página de detalhes de um projeto
  /// Atualiza a aba atual em vez de criar uma nova
  /// 
  /// Parâmetros:
  /// - [context]: BuildContext para acessar o TabManager
  /// - [projectId]: ID do projeto
  /// - [projectTitle]: Título do projeto (usado como título da aba)
  static void navigateToProjectDetail(
    BuildContext context,
    String projectId,
    String projectTitle,
  ) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager == null) return;

    final tabId = 'project_$projectId';
    final currentTab = tabManager.currentTab;
    
    final updatedTab = TabItem(
      id: tabId,
      title: projectTitle,
      icon: Icons.folder,
      page: ProjectDetailPage(
        key: ValueKey('project_$projectId'),
        projectId: projectId,
      ),
      canClose: true,
      selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0,
    );
    
    tabManager.updateTab(tabManager.currentIndex, updatedTab);
  }

  /// Navega para a página de detalhes de um cliente
  /// Atualiza a aba atual em vez de criar uma nova
  /// 
  /// Parâmetros:
  /// - [context]: BuildContext para acessar o TabManager
  /// - [clientId]: ID do cliente
  /// - [clientName]: Nome do cliente (usado como título da aba)
  static void navigateToClientDetail(
    BuildContext context,
    String clientId,
    String clientName,
  ) {
    final tabManager = TabManagerScope.maybeOf(context);
    if (tabManager == null) return;

    final tabId = 'client_$clientId';
    final currentTab = tabManager.currentTab;
    
    final updatedTab = TabItem(
      id: tabId,
      title: clientName,
      icon: Icons.business,
      page: ClientDetailPage(
        key: ValueKey('client_$clientId'),
        clientId: clientId,
      ),
      canClose: true,
      selectedMenuIndex: currentTab?.selectedMenuIndex ?? 0,
    );
    
    tabManager.updateTab(tabManager.currentIndex, updatedTab);
  }
}

