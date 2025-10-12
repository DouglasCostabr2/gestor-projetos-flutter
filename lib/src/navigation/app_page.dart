/// Enum que representa todas as páginas disponíveis no aplicativo
enum AppPage {
  home,
  clients,
  projects,
  catalog,
  tasks,
  finance,
  admin,
  monitoring,
}

/// Extensão para obter informações sobre cada página
extension AppPageExtension on AppPage {
  /// Retorna o índice da página (para compatibilidade com código legado)
  int get index {
    switch (this) {
      case AppPage.home:
        return 0;
      case AppPage.clients:
        return 1;
      case AppPage.projects:
        return 2;
      case AppPage.catalog:
        return 3;
      case AppPage.tasks:
        return 4;
      case AppPage.finance:
        return 5;
      case AppPage.admin:
        return 6;
      case AppPage.monitoring:
        return 7;
    }
  }

  /// Retorna a página correspondente ao índice
  static AppPage fromIndex(int index) {
    switch (index) {
      case 0:
        return AppPage.home;
      case 1:
        return AppPage.clients;
      case 2:
        return AppPage.projects;
      case 3:
        return AppPage.catalog;
      case 4:
        return AppPage.tasks;
      case 5:
        return AppPage.finance;
      case 6:
        return AppPage.admin;
      case 7:
        return AppPage.monitoring;
      default:
        return AppPage.home; // Fallback seguro
    }
  }

  /// Retorna o label da página
  String get label {
    switch (this) {
      case AppPage.home:
        return 'Home';
      case AppPage.clients:
        return 'Clientes';
      case AppPage.projects:
        return 'Projetos';
      case AppPage.catalog:
        return 'Catálogo';
      case AppPage.tasks:
        return 'Tarefas';
      case AppPage.finance:
        return 'Financeiro';
      case AppPage.admin:
        return 'Admin';
      case AppPage.monitoring:
        return 'Monitoramento';
    }
  }
}

