# Arquitetura de Monolito Modular - Diagrama Visual

## 🏛️ Visão Geral da Arquitetura

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APLICAÇÃO FLUTTER                            │
│                      (Artefato Único - Monolito)                     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        CAMADA DE FEATURES                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Login    │ │ Clients  │ │ Projects │ │  Tasks   │ │ Finance  │ │
│  │  Page    │ │  Page    │ │  Page    │ │  Page    │ │  Page    │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │  import 'modules/modules.dart' │
                    └───────────────┬───────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CAMADA DE CONTRATOS (INTERFACES)                  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    modules/modules.dart                       │  │
│  │  Ponto de Entrada Central - Exporta todos os contratos       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │
│  │  Auth   │ │  Users  │ │ Clients │ │Projects │ │  Tasks  │     │
│  │Contract │ │Contract │ │Contract │ │Contract │ │Contract │     │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     │
│                                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐     │
│  │Catalog  │ │  Files  │ │Comments │ │ Finance │ │Monitor  │     │
│  │Contract │ │Contract │ │Contract │ │Contract │ │Contract │     │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘     │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    Comunicação via Chamadas de Função
                    (Não há chamadas de rede/HTTP)
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  CAMADA DE IMPLEMENTAÇÃO (PRIVADA)                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      MÓDULO AUTH                              │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │  │
│  │  │ AuthContract   │  │ AuthRepository │  │  authModule    │ │  │
│  │  │  (Interface)   │◄─┤ (Implementação)│◄─┤  (Singleton)   │ │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      MÓDULO USERS                             │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │  │
│  │  │UsersContract   │  │UsersRepository │  │  usersModule   │ │  │
│  │  │  (Interface)   │◄─┤ (Implementação)│◄─┤  (Singleton)   │ │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     MÓDULO CLIENTS                            │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │  │
│  │  │ClientsContract │  │ClientsRepo     │  │ clientsModule  │ │  │
│  │  │  (Interface)   │◄─┤ (Implementação)│◄─┤  (Singleton)   │ │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ... (mais 8 módulos com a mesma estrutura)                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      CAMADA DE INFRAESTRUTURA                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Supabase Client                            │  │
│  │  • Database (PostgreSQL)                                      │  │
│  │  • Authentication                                             │  │
│  │  • Realtime Subscriptions                                    │  │
│  │  • Storage                                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Google Drive API                           │  │
│  │  • OAuth 2.0                                                  │  │
│  │  • File Upload/Download                                       │  │
│  │  • Folder Management                                          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 Fluxo de Comunicação

### Exemplo: Buscar Clientes

```
┌─────────────┐
│ ClientsPage │  Feature solicita dados
└──────┬──────┘
       │ clientsModule.getClients()
       ▼
┌──────────────────┐
│ ClientsContract  │  Interface pública (contrato)
└──────┬───────────┘
       │ Implementação
       ▼
┌──────────────────┐
│ ClientsRepository│  Implementação privada
└──────┬───────────┘
       │ Query SQL
       ▼
┌──────────────────┐
│ Supabase Client  │  Infraestrutura
└──────┬───────────┘
       │ HTTP Request
       ▼
┌──────────────────┐
│ PostgreSQL DB    │  Banco de dados
└──────────────────┘
```

### Exemplo: Comunicação Entre Módulos

```
┌──────────────────┐
│ UsersRepository  │  Precisa do usuário atual
└──────┬───────────┘
       │ authModule.currentUser  ✅ VIA CONTRATO
       ▼
┌──────────────────┐
│  AuthContract    │  Interface pública
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ AuthRepository   │  Implementação
└──────────────────┘

❌ PROIBIDO: UsersRepository → AuthRepository (chamada direta)
✅ CORRETO:  UsersRepository → AuthContract → AuthRepository
```

## 📦 Estrutura de Diretórios

```
lib/
├── modules/                          # CAMADA DE MÓDULOS
│   ├── modules.dart                  # ⭐ Ponto de entrada central
│   │
│   ├── auth/                         # Módulo de Autenticação
│   │   ├── contract.dart             # Interface pública
│   │   ├── repository.dart           # Implementação privada
│   │   ├── models.dart               # Modelos de dados
│   │   └── module.dart               # Exporta contrato + singleton
│   │
│   ├── users/                        # Módulo de Usuários
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── clients/                      # Módulo de Clientes
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── companies/                    # Módulo de Empresas
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── projects/                     # Módulo de Projetos
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── tasks/                        # Módulo de Tarefas
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── catalog/                      # Módulo de Catálogo
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── files/                        # Módulo de Arquivos
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── comments/                     # Módulo de Comentários
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   ├── finance/                      # Módulo Financeiro
│   │   ├── contract.dart
│   │   ├── repository.dart
│   │   ├── models.dart
│   │   └── module.dart
│   │
│   └── monitoring/                   # Módulo de Monitoramento
│       ├── contract.dart
│       ├── repository.dart
│       ├── models.dart
│       └── module.dart
│
├── src/                              # CAMADA DE FEATURES
│   ├── features/
│   │   ├── auth/
│   │   │   └── login_page.dart       # ✅ Usa authModule
│   │   ├── clients/
│   │   │   └── clients_page.dart     # ✅ Usa clientsModule
│   │   ├── projects/
│   │   │   └── projects_page.dart    # Usa projectsModule
│   │   └── tasks/
│   │       └── tasks_page.dart       # Usa tasksModule
│   │
│   └── state/
│       └── app_state.dart            # ✅ Usa authModule + usersModule
│
├── services/                         # ⚠️ LEGADO (a ser removido)
│   ├── supabase_service.dart         # ❌ Deprecated
│   ├── task_priority_updater.dart    # ❌ Migrado para tasksModule
│   └── ...
│
└── config/
    └── supabase_config.dart          # Configuração central
```

## 🎯 Princípios SOLID Aplicados

### 1. Single Responsibility Principle (SRP)
Cada módulo tem uma única responsabilidade de negócio:
- `auth` → Autenticação
- `clients` → Gestão de clientes
- `tasks` → Gestão de tarefas

### 2. Open/Closed Principle (OCP)
Módulos são abertos para extensão, fechados para modificação:
- Novos módulos podem ser adicionados sem alterar existentes
- Contratos podem ter novas implementações

### 3. Liskov Substitution Principle (LSP)
Implementações podem ser substituídas sem quebrar o sistema:
- `AuthRepository` pode ser trocado por `MockAuthRepository` em testes
- Contratos garantem compatibilidade

### 4. Interface Segregation Principle (ISP)
Contratos são específicos e focados:
- Cada contrato expõe apenas operações relevantes
- Features não dependem de métodos que não usam

### 5. Dependency Inversion Principle (DIP)
Features dependem de abstrações, não de implementações:
- Features → Contratos (abstrações)
- Contratos ← Implementações (concretas)

## 🔒 Garantias de Isolamento

### ✅ O que é PERMITIDO:

1. **Features importam módulos**:
   ```dart
   import 'package:gestor_projetos_flutter/modules/modules.dart';
   ```

2. **Features usam contratos**:
   ```dart
   final clients = await clientsModule.getClients();
   ```

3. **Módulos usam outros módulos via contratos**:
   ```dart
   // Dentro de UsersRepository
   final user = authModule.currentUser; // ✅ Via contrato
   ```

### ❌ O que é PROIBIDO:

1. **Features importam implementações**:
   ```dart
   import 'package:gestor_projetos_flutter/modules/clients/repository.dart'; // ❌
   ```

2. **Módulos importam outros módulos diretamente**:
   ```dart
   import '../auth/repository.dart'; // ❌
   ```

3. **Features fazem queries diretas**:
   ```dart
   Supabase.instance.client.from('clients').select(); // ❌
   ```

4. **Chamadas diretas entre implementações**:
   ```dart
   // Dentro de UsersRepository
   final auth = AuthRepository(); // ❌ Chamada direta
   ```

## 🚀 Benefícios da Arquitetura

### 1. Manutenibilidade
- Código organizado e estruturado
- Fácil localizar funcionalidades
- Mudanças isoladas em módulos

### 2. Testabilidade
- Módulos podem ser testados isoladamente
- Mocks fáceis via contratos
- Testes unitários e de integração

### 3. Escalabilidade
- Fácil adicionar novos módulos
- Crescimento sustentável
- Preparado para equipes maiores

### 4. Performance
- Chamadas de função (não rede)
- Sem overhead de serialização
- Mantém benefícios do monolito

### 5. Preparação para Microsserviços
- Contratos facilitam migração futura
- Módulos podem ser extraídos
- Comunicação já está bem definida

## 📊 Comparação: Antes vs Depois

### Antes (Monolito Tradicional)

```
❌ Código Espaguete
❌ Dependências cruzadas descontroladas
❌ Difícil manutenção
❌ Difícil testar
❌ Acoplamento alto
❌ Queries SQL espalhadas
```

### Depois (Monolito Modular)

```
✅ Código organizado em módulos
✅ Dependências controladas via contratos
✅ Fácil manutenção
✅ Fácil testar
✅ Baixo acoplamento
✅ Lógica de dados centralizada
```

## 🎓 Referências e Padrões

- **Hexagonal Architecture** (Ports and Adapters)
- **Domain-Driven Design** (DDD)
- **SOLID Principles**
- **Separation of Concerns** (SoC)
- **Dependency Injection**
- **Repository Pattern**
- **Singleton Pattern**

---

**Arquitetura implementada em**: 2025-10-07  
**Status**: ✅ Completa e Validada

