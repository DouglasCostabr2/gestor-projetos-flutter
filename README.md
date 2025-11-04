# Gestor de Projetos Flutter

Um aplicativo Flutter para gestão de projetos integrado com Supabase.

## 🚀 Configuração do Supabase

### 1. Criar conta no Supabase
1. Acesse [supabase.com](https://supabase.com)
2. Crie uma conta gratuita
3. Crie um novo projeto

### 2. Obter credenciais
1. No dashboard do seu projeto Supabase, vá em **Settings** > **API**
2. Copie a **URL** e a **anon public key**

### 3. Configurar no projeto
1. Abra o arquivo `lib/config/supabase_config.dart`
2. Substitua as constantes pelas suas credenciais:

```dart
static const String supabaseUrl = 'https://seu-projeto.supabase.co';
static const String supabaseAnonKey = 'sua-anon-key-aqui';
```

## 📦 Dependências Instaladas

- **supabase_flutter**: ^2.9.1 - SDK oficial do Supabase para Flutter

## 🛠️ Funcionalidades Disponíveis

### Autenticação
- Login/Registro com email e senha
- Logout
- Monitoramento de estado de autenticação

### Banco de Dados
- Operações CRUD (Create, Read, Update, Delete)
- Consultas em tempo real
- Filtros e ordenação

### Storage
- Upload de arquivos
- Download de arquivos
- URLs públicas

### Realtime
- Escuta de mudanças em tempo real
- Broadcast de mensagens
- Presence (presença de usuários)

## 📁 Estrutura do Projeto

```
lib/
├── ui/                         # 🎨 Atomic Design (NOVO)
│   ├── atoms/                  # Componentes básicos (buttons, inputs, avatars)
│   ├── molecules/              # Combinações simples (dropdowns, table_cells)
│   ├── organisms/              # Componentes complexos (em migração)
│   ├── templates/              # Templates de páginas
│   └── ui.dart                 # Barrel file principal
│
├── src/
│   ├── features/               # Funcionalidades por módulo
│   │   ├── auth/              # Autenticação
│   │   ├── clients/           # Clientes
│   │   ├── projects/          # Projetos
│   │   ├── tasks/             # Tarefas
│   │   ├── catalog/           # Catálogo de produtos
│   │   └── ...
│   ├── navigation/            # Sistema de navegação e tabs
│   ├── state/                 # Gerenciamento de estado
│   └── app_shell.dart         # Shell principal do app
│
├── modules/                    # Lógica de negócio
│   ├── auth/
│   ├── clients/
│   ├── projects/
│   └── tasks/
│
├── services/                   # Serviços (Supabase, Google Drive, etc.)
├── widgets/                    # Widgets reutilizáveis (organisms em migração)
├── config/                     # Configurações
└── main.dart                   # Ponto de entrada
```

### 🎨 Atomic Design

O projeto segue o padrão **Atomic Design** para organização de componentes UI:

- **Atoms** (`lib/ui/atoms/`): Componentes básicos indivisíveis
  - Buttons, Inputs, Avatars

- **Molecules** (`lib/ui/molecules/`): Combinações simples de atoms
  - Dropdowns, Table Cells, User Avatar + Name

- **Organisms** (`lib/ui/organisms/`): Componentes complexos
  - Em migração de `lib/widgets/`

- **Templates** (`lib/ui/templates/`): Layouts de páginas

- **Pages** (`lib/src/features/*/`): Páginas completas

📖 **Documentação completa:** [lib/ui/README.md](lib/ui/README.md)
📊 **Status da migração:** [lib/ui/ATOMIC_DESIGN_STATUS.md](lib/ui/ATOMIC_DESIGN_STATUS.md)

## 🚀 Como usar

### Exemplo de uso básico:

```dart
import 'package:gestor_projetos_flutter/services/supabase_service.dart';

// Fazer login
final response = await SupabaseService.signInWithEmail(
  email: 'usuario@email.com',
  password: 'senha123',
);

// Buscar projetos
final projects = await SupabaseService.getProjects();

// Criar novo projeto
final newProject = await SupabaseService.createProject(
  name: 'Meu Projeto',
  description: 'Descrição do projeto',
);
```

## 📚 Recursos Úteis

- [Documentação do Supabase](https://supabase.com/docs)
- [Supabase Flutter Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Documentação do Flutter](https://docs.flutter.dev/)
