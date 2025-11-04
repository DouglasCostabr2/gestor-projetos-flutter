# Fase 2: Análise da Arquitetura Atual

**Data:** 2025-10-13  
**Objetivo:** Preparar o terreno para migração de Organisms

---

## 📊 Arquitetura Atual

### 1. Services (lib/services/)

#### ✅ Bem Estruturados

**Google Drive Services** - Já modularizados:
- `google_drive/auth_service.dart` - Autenticação OAuth
- `google_drive/folder_service.dart` - Gerenciamento de pastas
- `google_drive/file_service.dart` - Gerenciamento de arquivos
- `google_drive/upload_service.dart` - Upload de arquivos
- `google_drive/google_drive_service.dart` - Fachada principal

**Padrão atual:**
```dart
class GoogleDriveService {
  final _authService = GoogleDriveAuthService();
  final _folderService = GoogleDriveFolderService();
  final _fileService = GoogleDriveFileService();
  final _uploadService = GoogleDriveUploadService();
  
  // Métodos delegam para os serviços especializados
}
```

#### ⚠️ Precisam Refatoração

**Services Legados:**
- `google_drive_oauth_service.dart` - Serviço legado (a ser migrado)
- `briefing_image_service.dart` - Acoplado diretamente
- `task_files_repository.dart` - Acoplado diretamente
- `task_comments_repository.dart` - Acoplado diretamente
- `upload_manager.dart` - Acoplado diretamente

**Problema:** Instanciação direta nos widgets/organisms
```dart
// ❌ Acoplamento direto
final driveService = GoogleDriveOAuthService();
final client = await driveService.getAuthedClient();
```

---

### 2. Modules (lib/modules/)

#### ✅ Excelente Arquitetura

**Padrão Contract-Repository:**
```dart
// contract.dart - Interface pública
abstract class ClientsContract {
  Future<List<Map<String, dynamic>>> getClients();
}

// repository.dart - Implementação interna
class ClientsRepository implements ClientsContract {
  final SupabaseClient _client = SupabaseConfig.client;
  // Implementação...
}

// module.dart - Singleton exportado
final ClientsContract clientsModule = ClientsRepository();
```

**Módulos existentes:**
- ✅ auth
- ✅ users
- ✅ clients
- ✅ companies
- ✅ projects
- ✅ tasks
- ✅ products
- ✅ catalog
- ✅ files
- ✅ comments
- ✅ finance
- ✅ monitoring

**Vantagens:**
- Desacoplamento total
- Fácil de testar (mock do contract)
- Singleton gerenciado
- Interface clara

---

### 3. Navigation (lib/src/navigation/)

#### Componentes Atuais

**TabManager** (`tab_manager.dart`):
```dart
class TabManager extends ChangeNotifier {
  final List<TabItem> _tabs = [];
  int _currentIndex = 0;
  final Map<int, List<TabItem>> _tabHistory = {};
  
  // Métodos: addTab, removeTab, selectTab, updateTab, etc.
}
```

**TabManagerScope** (`tab_manager_scope.dart`):
```dart
class TabManagerScope extends InheritedWidget {
  final TabManager tabManager;
  
  static TabManager of(BuildContext context) { }
  static TabManager? maybeOf(BuildContext context) { }
}
```

**TabItem** (`tab_item.dart`):
```dart
class TabItem {
  final String id;
  final String title;
  final IconData icon;
  final Widget page;
  final bool canClose;
  final int selectedMenuIndex;
}
```

**Outros:**
- `route_observer.dart` - RouteObserver global
- `user_role.dart` - Enums de roles

#### ⚠️ Problemas Identificados

1. **TabManager muito acoplado:**
   - Gerencia estado, lógica e histórico
   - Difícil de testar isoladamente
   - Muitas responsabilidades

2. **Acesso via InheritedWidget:**
   - Funciona, mas não é ideal para DI
   - Dificulta testes unitários
   - Acoplamento com BuildContext

3. **Sem interfaces:**
   - Implementação concreta exposta
   - Difícil de mockar em testes

---

### 4. State Management (lib/src/state/)

**AppState** (`app_state.dart`):
```dart
class AppState extends ChangeNotifier {
  bool initialized = false;
  Map<String, dynamic>? profile;
  String role = 'convidado';
  final ValueNotifier<bool> sideMenuCollapsedNotifier;
  
  // Métodos: initialize, refreshProfile, etc.
}
```

**AppStateScope** (`app_state_scope.dart`):
```dart
class AppStateScope extends InheritedWidget {
  final AppState appState;
  
  static AppState of(BuildContext context) { }
}
```

#### ✅ Pontos Positivos
- Usa ValueNotifier para otimizar rebuilds
- Centraliza estado da sessão
- Bem integrado com módulos

#### ⚠️ Melhorias Possíveis
- Poderia usar Provider ou Riverpod
- Separar responsabilidades (auth state vs UI state)

---

## 🎯 Organisms a Migrar

### Categorização por Complexidade

#### 🟢 Baixa Complexidade (Começar por aqui)
1. **StandardDialog** - Dialog padrão
2. **DriveConnectDialog** - Dialog de conexão Google Drive

#### 🟡 Média Complexidade
3. **ReorderableDragList** - Lista drag & drop
4. **GenericTabView** (tabs/) - Sistema de tabs genérico
5. **CommentsSection** - Seção de comentários
6. **TaskFilesSection** - Seção de arquivos de tarefa
7. **FinalProjectSection** - Seção de projeto final

#### 🔴 Alta Complexidade
8. **ReusableDataTable** - Tabela de dados reutilizável
9. **DynamicPaginatedTable** - Tabela paginada
10. **TableSearchFilterBar** - Barra de busca/filtro
11. **CustomBriefingEditor** - Editor de briefing
12. **ChatBriefing** - Editor estilo chat
13. **AppFlowyTextField** - Campo de texto rico
14. **TextFieldWithToolbar** - Campo com toolbar
15. **SideMenu** - Menu lateral
16. **TabBarWidget** - Barra de tabs

---

## 🔍 Dependências dos Organisms

### StandardDialog
- ❌ Nenhuma dependência de service
- ✅ Pronto para migrar

### DriveConnectDialog
- ⚠️ Usa `GoogleDriveOAuthService` diretamente
- 🔧 Precisa: Injetar service via construtor

### CommentsSection
- ⚠️ Usa `task_comments_repository` diretamente
- 🔧 Precisa: Usar módulo de comments

### TaskFilesSection
- ⚠️ Usa `task_files_repository` diretamente
- ⚠️ Usa `GoogleDriveOAuthService` diretamente
- 🔧 Precisa: Injetar services

### FinalProjectSection
- ⚠️ Usa `GoogleDriveOAuthService` diretamente
- ⚠️ Usa `task_files_repository` diretamente
- 🔧 Precisa: Injetar services

### CustomBriefingEditor
- ⚠️ Usa `briefing_image_service` diretamente
- ⚠️ Usa `GoogleDriveOAuthService` diretamente
- 🔧 Precisa: Injetar services

### SideMenu
- ✅ Usa AppStateScope (OK)
- ✅ Usa TabManagerScope (OK)
- ⚠️ Acoplado com TabManager concreto
- 🔧 Precisa: Interface para TabManager

### TabBarWidget
- ✅ Recebe TabManager via construtor
- ⚠️ Acoplado com TabManager concreto
- 🔧 Precisa: Interface para TabManager

### ReusableDataTable
- ✅ Genérico, sem dependências de service
- ✅ Pronto para migrar

---

## 📋 Plano de Ação

### Etapa 1: Service Locator (DI)

**Criar:** `lib/core/di/service_locator.dart`

```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();
  
  final Map<Type, dynamic> _services = {};
  
  void register<T>(T service) {
    _services[T] = service;
  }
  
  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service $T not registered');
    }
    return service as T;
  }
}

// Singleton global
final serviceLocator = ServiceLocator();
```

### Etapa 2: Interfaces para Services

**Criar:** `lib/services/interfaces/`

```dart
// google_drive_service_interface.dart
abstract class IGoogleDriveService {
  Future<http.Client> getAuthedClient();
  Future<void> saveRefreshToken(String userId, String refreshToken);
  Future<bool> hasToken(String userId);
  // ... outros métodos
}

// briefing_image_service_interface.dart
abstract class IBriefingImageService {
  Future<String?> uploadBriefingImage(...);
  // ... outros métodos
}
```

### Etapa 3: Adaptar Services Existentes

```dart
// google_drive_service.dart
class GoogleDriveService implements IGoogleDriveService {
  // Implementação existente
}

// Registrar no service locator
void registerServices() {
  serviceLocator.register<IGoogleDriveService>(GoogleDriveService());
  serviceLocator.register<IBriefingImageService>(BriefingImageService());
}
```

### Etapa 4: Interface para Navigation

**Criar:** `lib/src/navigation/interfaces/tab_manager_interface.dart`

```dart
abstract class ITabManager {
  List<TabItem> get tabs;
  int get currentIndex;
  TabItem? get currentTab;
  
  void addTab(TabItem tab, {bool allowDuplicates = false});
  void removeTab(int index);
  void selectTab(int index);
  void updateTab(int index, TabItem newTab, {bool saveToHistory = true});
  // ... outros métodos
}
```

### Etapa 5: Adaptar TabManager

```dart
class TabManager extends ChangeNotifier implements ITabManager {
  // Implementação existente
}

// Registrar no service locator
void registerNavigation() {
  serviceLocator.register<ITabManager>(TabManager());
}
```

---

## ✅ Benefícios Esperados

1. **Desacoplamento:**
   - Organisms não dependem de implementações concretas
   - Fácil trocar implementações

2. **Testabilidade:**
   - Mock de services via interfaces
   - Testes unitários isolados

3. **Manutenibilidade:**
   - Mudanças em services não afetam organisms
   - Código mais limpo e organizado

4. **Escalabilidade:**
   - Fácil adicionar novos services
   - Preparado para crescimento

---

## 📊 Métricas de Sucesso

- [ ] Service Locator implementado
- [ ] Interfaces criadas para todos os services usados por organisms
- [ ] Services registrados no locator
- [ ] Interface ITabManager criada
- [ ] TabManager implementa ITabManager
- [ ] Compilação sem erros
- [ ] Aplicativo funcionando normalmente
- [ ] Pronto para migrar organisms

---

**Próximo passo:** Implementar Service Locator e interfaces

