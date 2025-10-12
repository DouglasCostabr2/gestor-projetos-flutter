# Guia Rápido - Como Usar os Módulos

## 🚀 Início Rápido

### 1. Importar os Módulos

Em qualquer feature, importe apenas o ponto de entrada central:

```dart
import 'package:gestor_projetos_flutter/modules/modules.dart';
```

Isso dá acesso a todos os módulos:
- `authModule`
- `usersModule`
- `clientsModule`
- `companiesModule`
- `projectsModule`
- `tasksModule`
- `catalogModule`
- `filesModule`
- `commentsModule`
- `financeModule`
- `monitoringModule`

### 2. Usar os Módulos

Simplesmente chame os métodos dos módulos:

```dart
// Exemplo: Buscar clientes
final clients = await clientsModule.getClients();

// Exemplo: Criar tarefa
await tasksModule.createTask(
  projectId: projectId,
  title: 'Nova tarefa',
  description: 'Descrição',
);
```

## 📚 Referência Rápida por Módulo

### 🔐 Auth Module

**Uso**: Autenticação e sessão

```dart
// Login
await authModule.signInWithEmail(
  email: 'user@example.com',
  password: 'senha123',
);

// Logout
await authModule.signOut();

// Usuário atual
final user = authModule.currentUser;

// Ouvir mudanças de autenticação
authModule.authStateChanges.listen((state) {
  print('Auth state: $state');
});
```

---

### 👤 Users Module

**Uso**: Perfis e usuários

```dart
// Perfil do usuário atual
final profile = await usersModule.getCurrentProfile();

// Atualizar perfil
await usersModule.updateProfile(
  userId: userId,
  fullName: 'João Silva',
  avatarUrl: 'https://...',
);

// Buscar perfil por ID
final profile = await usersModule.getProfileById(userId);

// Listar todos os perfis
final profiles = await usersModule.getAllProfiles();
```

---

### 👥 Clients Module

**Uso**: Gestão de clientes

```dart
// Listar clientes
final clients = await clientsModule.getClients();

// Buscar cliente por ID
final client = await clientsModule.getClientById(clientId);

// Criar cliente
await clientsModule.createClient(
  name: 'Empresa XYZ',
  email: 'contato@xyz.com',
  phone: '+55 11 99999-9999',
  status: 'active',
);

// Atualizar cliente
await clientsModule.updateClient(
  clientId: clientId,
  name: 'Novo Nome',
  email: 'novo@email.com',
);

// Deletar cliente
await clientsModule.deleteClient(clientId);
```

---

### 🏢 Companies Module

**Uso**: Gestão de empresas

```dart
// Listar empresas de um cliente
final companies = await companiesModule.getCompanies(clientId);

// Buscar empresa por ID
final company = await companiesModule.getCompanyById(companyId);

// Criar empresa
await companiesModule.createCompany(
  clientId: clientId,
  name: 'Filial São Paulo',
  address: 'Av. Paulista, 1000',
);

// Atualizar empresa
await companiesModule.updateCompany(
  companyId: companyId,
  name: 'Novo Nome',
);

// Deletar empresa
await companiesModule.deleteCompany(companyId);
```

---

### 📁 Projects Module

**Uso**: Gestão de projetos

```dart
// Listar projetos
final projects = await projectsModule.getProjects();

// Buscar projeto por ID
final project = await projectsModule.getProjectById(projectId);

// Projetos de um cliente
final projects = await projectsModule.getProjectsByClient(clientId);

// Criar projeto
await projectsModule.createProject(
  name: 'Website Institucional',
  description: 'Desenvolvimento do site',
  clientId: clientId,
  status: 'active',
);

// Atualizar projeto
await projectsModule.updateProject(
  projectId: projectId,
  name: 'Novo Nome',
  status: 'completed',
);

// Deletar projeto
await projectsModule.deleteProject(projectId);

// Membros do projeto
final members = await projectsModule.getProjectMembers(projectId);

// Adicionar membro
await projectsModule.addProjectMember(
  projectId: projectId,
  userId: userId,
  role: 'designer',
);

// Remover membro
await projectsModule.removeProjectMember(
  projectId: projectId,
  userId: userId,
);

// Realtime (ouvir mudanças)
final subscription = projectsModule.subscribeToProjects((payload) {
  print('Projeto atualizado: $payload');
});
```

---

### ✅ Tasks Module

**Uso**: Gestão de tarefas

```dart
// Listar tarefas
final tasks = await tasksModule.getTasks();

// Buscar tarefa por ID
final task = await tasksModule.getTaskById(taskId);

// Tarefas de um projeto
final tasks = await tasksModule.getProjectTasks(projectId);

// Criar tarefa
await tasksModule.createTask(
  projectId: projectId,
  title: 'Criar layout',
  description: 'Layout da homepage',
  status: 'pending',
  priority: 'high',
  dueDate: DateTime.now().add(Duration(days: 7)),
);

// Atualizar tarefa
await tasksModule.updateTask(
  taskId: taskId,
  title: 'Novo título',
  status: 'in_progress',
);

// Deletar tarefa
await tasksModule.deleteTask(taskId);

// Atualizar prioridades por data de vencimento
await tasksModule.updateTasksPriorityByDueDate();

// Obter label de status
final label = tasksModule.getStatusLabel('in_progress'); // "Em Andamento"

// Validar status
final isValid = tasksModule.isValidStatus('pending'); // true

// Definir status de espera
await tasksModule.setTaskWaitingStatus(
  taskId: taskId,
  isWaiting: true,
  waitingReason: 'Aguardando aprovação do cliente',
);

// Realtime (ouvir mudanças)
final subscription = tasksModule.subscribeToProjectTasks(
  projectId,
  (payload) {
    print('Tarefa atualizada: $payload');
  },
);
```

---

### 🛍️ Catalog Module

**Uso**: Produtos e pacotes

```dart
// Listar produtos
final products = await catalogModule.getProducts();

// Buscar produto por ID
final product = await catalogModule.getProductById(productId);

// Listar pacotes
final packages = await catalogModule.getPackages();

// Buscar pacote por ID
final package = await catalogModule.getPackageById(packageId);

// Listar categorias
final categories = await catalogModule.getCategories();

// Criar produto
await catalogModule.createProduct(
  name: 'Logo Design',
  description: 'Criação de logotipo',
  price: 500.0,
  category: 'design',
);

// Atualizar produto
await catalogModule.updateProduct(
  productId: productId,
  name: 'Novo nome',
  price: 600.0,
);

// Deletar produto
await catalogModule.deleteProduct(productId);
```

---

### 📎 Files Module

**Uso**: Arquivos (Google Drive)

```dart
// Salvar arquivo no banco
await filesModule.saveFile(
  taskId: taskId,
  fileName: 'documento.pdf',
  fileUrl: 'https://drive.google.com/...',
  driveFileId: 'abc123',
);

// Arquivos de uma tarefa
final files = await filesModule.getTaskFiles(taskId);

// Deletar arquivo
await filesModule.deleteFile(fileId);

// Cliente Google Drive
final driveApi = await filesModule.getGoogleDriveClient();

// Verificar conexão
final isConnected = await filesModule.hasGoogleDriveConnected();

// Salvar token de refresh
await filesModule.saveGoogleDriveRefreshToken(refreshToken);

// Upload múltiplo
await filesModule.uploadFilesToDrive(
  files: [
    MemoryUploadItem(
      bytes: fileBytes,
      fileName: 'arquivo.pdf',
      mimeType: 'application/pdf',
    ),
  ],
  taskId: taskId,
  projectName: 'Projeto X',
  taskTitle: 'Tarefa Y',
);
```

---

### 💬 Comments Module

**Uso**: Comentários em tarefas

```dart
// Criar comentário
await commentsModule.createComment(
  taskId: taskId,
  content: 'Ótimo trabalho!',
);

// Listar comentários de uma tarefa
final comments = await commentsModule.listByTask(taskId);

// Atualizar comentário
await commentsModule.updateComment(
  commentId: commentId,
  content: 'Comentário atualizado',
);

// Deletar comentário
await commentsModule.deleteComment(commentId);
```

---

### 💰 Finance Module

**Uso**: Gestão financeira

```dart
// Dados financeiros do projeto
final financials = await financeModule.getProjectFinancials(projectId);

// Atualizar financeiro
await financeModule.updateProjectFinancials(
  projectId: projectId,
  estimatedCost: 5000.0,
  actualCost: 4500.0,
);

// Custos adicionais
final costs = await financeModule.getProjectAdditionalCosts(projectId);

// Adicionar custo
await financeModule.addProjectCost(
  projectId: projectId,
  description: 'Hospedagem',
  amount: 100.0,
);

// Remover custo
await financeModule.removeProjectCost(costId);

// Itens do catálogo no projeto
final items = await financeModule.getProjectCatalogItems(projectId);

// Calcular total
final total = await financeModule.calculateProjectTotal(projectId);
```

---

### 📊 Monitoring Module

**Uso**: Monitoramento de usuários

```dart
// Dados de monitoramento
final data = await monitoringModule.fetchMonitoringData(
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

// Atividades de um usuário
final activities = await monitoringModule.getUserActivities(userId);

// Estatísticas do sistema
final stats = await monitoringModule.getSystemStatistics();
// Retorna: { total_users, total_projects, total_tasks, completed_tasks }
```

---

## ⚠️ Regras Importantes

### ✅ FAÇA:

1. **Sempre importe apenas `modules/modules.dart`**
   ```dart
   import 'package:gestor_projetos_flutter/modules/modules.dart';
   ```

2. **Use os módulos via singleton**
   ```dart
   await clientsModule.getClients();
   ```

3. **Trate erros adequadamente**
   ```dart
   try {
     await clientsModule.createClient(...);
   } catch (e) {
     print('Erro: $e');
   }
   ```

### ❌ NÃO FAÇA:

1. **Não importe implementações diretamente**
   ```dart
   import 'package:gestor_projetos_flutter/modules/clients/repository.dart'; // ❌
   ```

2. **Não faça queries diretas ao Supabase**
   ```dart
   Supabase.instance.client.from('clients').select(); // ❌
   ```

3. **Não crie instâncias dos repositórios**
   ```dart
   final repo = ClientsRepository(); // ❌
   ```

---

## 🎯 Exemplos Práticos

### Exemplo 1: Tela de Login

```dart
import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';

class LoginPage extends StatelessWidget {
  Future<void> _login(String email, String password) async {
    try {
      await authModule.signInWithEmail(
        email: email,
        password: password,
      );
      // Navegar para home
    } catch (e) {
      // Mostrar erro
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI...
  }
}
```

### Exemplo 2: Listar e Criar Clientes

```dart
import 'package:flutter/material.dart';
import 'package:gestor_projetos_flutter/modules/modules.dart';

class ClientsPage extends StatefulWidget {
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await clientsModule.getClients();
    setState(() => _clients = clients);
  }

  Future<void> _createClient() async {
    await clientsModule.createClient(
      name: 'Novo Cliente',
      email: 'cliente@example.com',
      status: 'active',
    );
    await _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Clientes')),
      body: ListView.builder(
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          final client = _clients[index];
          return ListTile(
            title: Text(client['name']),
            subtitle: Text(client['email'] ?? ''),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createClient,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

---

## 📖 Mais Informações

- **Arquitetura Completa**: Ver `ARQUITETURA_MODULAR.md`
- **Relatório de Migração**: Ver `RELATORIO_MIGRACAO_MONOLITO_MODULAR.md`
- **Guia de Migração**: Ver `MIGRACAO_MONOLITO_MODULAR.md`

---

**Última atualização**: 2025-10-07

