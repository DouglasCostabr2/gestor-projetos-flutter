# Arquitetura do Projeto - Gestor de Projetos Flutter

## 📋 Visão Geral

Sistema de gestão de projetos desenvolvido em Flutter para Windows, com backend Supabase (PostgreSQL + Storage + Auth).

---

## 🗄️ Estrutura do Banco de Dados

### Hierarquia de Dependências (Ordem de Deleção)

```
NÍVEL 5 (Mais Profundo - Deletar Primeiro)
├── package_items (referencia products)
└── task_products (referencia products e tasks)

NÍVEL 4 (Filhos de Tarefas)
├── task_files
├── task_comments
└── task_history

NÍVEL 3 (Tarefas e Filhos de Projetos)
├── tasks
├── project_members
├── project_additional_costs
├── project_catalog_items
└── payments

NÍVEL 2 (Projetos e Empresas)
├── projects
└── companies

NÍVEL 1 (Clientes - Pais de Projetos/Empresas)
└── clients

NÍVEL 0 (Catálogos Independentes - Deletar Por Último)
├── client_categories
├── product_categories
├── packages
└── products
```

### Relacionamentos Principais

- **clients** → **projects** (1:N)
- **clients** → **companies** (1:N)
- **projects** → **tasks** (1:N)
- **projects** → **project_members** (N:N)
- **projects** → **payments** (1:N)
- **tasks** → **task_files** (1:N)
- **tasks** → **task_comments** (1:N)
- **products** → **package_items** (1:N)
- **packages** → **package_items** (1:N)

---

## 🎨 Estrutura de Pastas Flutter

```
lib/
├── src/
│   ├── features/          # Módulos por funcionalidade
│   │   ├── home/
│   │   ├── clients/
│   │   ├── projects/
│   │   ├── tasks/
│   │   ├── catalog/
│   │   ├── finance/
│   │   ├── admin/
│   │   ├── monitoring/
│   │   ├── settings/
│   │   └── auth/
│   ├── navigation/        # Sistema de navegação e abas
│   │   ├── app_page.dart
│   │   ├── tab_item.dart
│   │   ├── tab_manager.dart
│   │   └── user_role.dart
│   ├── state/            # Gerenciamento de estado
│   │   └── app_state.dart
│   ├── theme/            # Tema e cores
│   │   └── app_theme.dart
│   └── app_shell.dart    # Shell principal do app
├── widgets/              # Widgets compartilhados
│   ├── side_menu/
│   └── tab_bar/
└── modules/              # Módulos de serviços
    └── modules.dart
```

---

## 🎨 Sistema de Cores (Dark Theme)

```dart
// Backgrounds
surface: 0xFF151515           // Background principal
surfaceContainer: 0xFF151515  // Cards e containers

// Side Menu
cardColor: 0xFF151515         // Fundo do menu
borderColor: 0xFF2A2A2A       // Bordas
selectedFill: 0x1AFFFFFF      // Overlay de seleção (10% branco)

// Tab Bar
tabBarBg: 0xFF1E1E1E          // Fundo da barra de abas
tabSelected: 0xFF151515       // Aba selecionada
tabHover: 0xFF2A2A2A          // Aba em hover

// Textos
onSurface: 0xFFEAEAEA         // Texto principal
onMuted: 0xFF9AA0A6           // Texto secundário

// Accent
primary: 0xFF7AB6FF           // Azul suave
error: 0xFFFF4D4D             // Vermelho
success: 0xFF4CAF50           // Verde
```

---

## 📐 Dimensões e Medidas

### Side Menu
- **Expandido**: 260px
- **Colapsado**: 72px
- **Animação**: Smooth transition

### Tab Bar
- **Altura**: 40px
- **Largura das abas**:
  - Máximo: 260px (mesma do side menu expandido)
  - Mínimo: 120px
  - Dinâmica: divide espaço disponível
- **Border radius**: 8px (cantos superiores)

### Botões
- **Border radius**: 12px
- **Padding**: 16px horizontal, 12px vertical

---

## 🔐 Sistema de Permissões (Roles)

```dart
enum UserRole {
  admin,      // Acesso total
  gestor,     // Gestão de projetos e equipe
  financeiro, // Acesso financeiro
  designer,   // Usuário padrão
  cliente,    // Acesso limitado (sem Clientes/Catálogo)
  usuario,    // Usuário básico
}
```

### Matriz de Acesso

| Página | Admin | Gestor | Financeiro | Designer | Cliente | Usuário |
|--------|-------|--------|------------|----------|---------|---------|
| Home | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Clientes | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Projetos | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Catálogo | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Tarefas | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Financeiro | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Admin | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Monitoramento | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 🖼️ Convenções de Nomenclatura de Imagens

### Supabase Storage

| Tipo | Bucket | Formato | Exemplo |
|------|--------|---------|---------|
| Avatar de Usuário | `avatars` | `avatar-{username}.jpg` | `avatar-douglas-costa.jpg` |
| Avatar de Cliente | `client-avatars` | `{userId}/avatar-{clientname}.jpg` | `{userId}/avatar-empresa-abc.jpg` |
| Thumbnail de Produto | `product-thumbnails` | `thumb-{productname}.jpg` | `thumb-logo-design.jpg` |
| Thumbnail de Pacote | `product-thumbnails` | `thumb-{packagename}.jpg` | `thumb-pacote-premium.jpg` |

### Regras de Sanitização
1. Converter para minúsculas
2. Remover acentos
3. Substituir espaços por hífens
4. Remover caracteres especiais
5. Remover hífens duplicados

---

## 🔄 Sistema de Abas (Tabs)

### Comportamento

- **Home**: Permite múltiplas abas (IDs únicos: `home_0`, `home_1`, etc.)
- **Outras páginas**: Apenas uma aba por tipo (reutiliza se já existe)

### Navegação

- **Side Menu**: Atualiza conteúdo da aba atual (não cria nova)
- **Botão "+"**: Cria nova aba da Home
- **Fechar aba**: Botão X ou clique do meio do mouse

### Largura Dinâmica

```dart
// Calcula largura baseada no espaço disponível
double tabWidth = (availableWidth / tabCount).clamp(120.0, 260.0);
```

---

## 📦 Dependências Principais

- **supabase_flutter**: Backend (auth, database, storage)
- **flutter**: Framework UI
- **Material 3**: Design system

---

## 🚀 Executável

**Caminho**: `build\windows\x64\runner\Debug\gestor_projetos_flutter.exe`

---

## 📝 Padrões de Código

### Widgets
- Sempre usar `const` quando possível
- Preferir `StatelessWidget` quando não há estado
- Usar `AnimatedBuilder` para animações reativas

### Estado
- `ChangeNotifier` para gerenciamento de estado
- `notifyListeners()` após mudanças de estado

### Navegação
- Usar `Navigator.push` para páginas modais
- Sistema de abas para navegação principal

### Cores
- Sempre usar constantes definidas no tema
- Evitar hardcoded colors fora do `app_theme.dart`

---

## 🎯 Próximas Melhorias Sugeridas

1. Persistência de abas (salvar estado ao fechar app)
2. Atalhos de teclado (Ctrl+W, Ctrl+T, Ctrl+Tab)
3. Drag & drop para reordenar abas
4. Contexto menu (clique direito nas abas)
5. Indicador de mudanças não salvas nas abas

