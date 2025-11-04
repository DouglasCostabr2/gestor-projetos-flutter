# 🎨 UI Components - Atomic Design

Esta pasta contém todos os componentes de UI organizados seguindo o padrão **Atomic Design**.

## 📖 Documentação

> 💡 **Novo aqui?** Comece pelo [GETTING_STARTED.md](GETTING_STARTED.md) - Guia de 5 minutos!

- 🚀 **[GETTING_STARTED.md](GETTING_STARTED.md)** - Guia de início rápido (5 minutos)
- 📇 **[INDEX.md](INDEX.md)** - Índice completo da documentação
- 📘 **[README.md](README.md)** - Este arquivo (visão geral completa)
- 🔍 **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Referência rápida para consulta
- 💡 **[EXAMPLES.md](EXAMPLES.md)** - Exemplos práticos de uso
- ✨ **[BEST_PRACTICES.md](BEST_PRACTICES.md)** - Boas práticas e padrões
- 🔄 **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Guia de migração de imports
- 📊 **[ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md)** - Status da migração
- 📁 **[STRUCTURE.md](STRUCTURE.md)** - Estrutura visual completa
- 🗺️ **[ROADMAP.md](ROADMAP.md)** - Plano de evolução

---

## 📚 Estrutura

```
ui/
├── atoms/          # Componentes básicos indivisíveis
├── molecules/      # Combinações simples de átomos
├── organisms/      # Componentes complexos
├── templates/      # Layouts de página
└── ui.dart         # Barrel file principal (exporta tudo)
```

---

## 🔹 ATOMS (Átomos)

**Componentes básicos e indivisíveis** - os blocos de construção fundamentais.

### Características:
- Não podem ser decompostos em componentes menores
- Altamente reutilizáveis
- Sem lógica de negócio
- Exemplos: botões, inputs, ícones, avatares

### Localização:
- `atoms/buttons/` - Botões (PrimaryButton, SecondaryButton, etc.)
- `atoms/inputs/` - Campos de entrada (GenericTextField, GenericTextArea, etc.)
- `atoms/avatars/` - Avatares (CachedAvatar)

### Import:
```dart
import 'package:gestor_projetos_flutter/ui/atoms/atoms.dart';
```

---

## 🔸 MOLECULES (Moléculas)

**Combinações simples de átomos** - grupos de átomos funcionando juntos.

### Características:
- Combinam 2 ou mais átomos
- Têm uma função específica
- Ainda são relativamente simples
- Exemplos: campo de busca, dropdown, card básico

### Localização:
- `molecules/dropdowns/` - Dropdowns (AsyncDropdownField, SearchableDropdownField)
- `molecules/table_cells/` - Células de tabela (TableCellAvatar, TableCellCurrency)
- `molecules/user_avatar_name.dart` - Avatar + Nome

### Import:
```dart
import 'package:gestor_projetos_flutter/ui/molecules/molecules.dart';
```

---

## 🔶 ORGANISMS (Organismos)

**Componentes complexos** - seções distintas de uma interface.

### Características:
- Combinam moléculas e/ou átomos
- Formam seções completas da UI
- Podem ter lógica complexa
- Exemplos: header, sidebar, formulário completo, tabela

### Localização:
- `organisms/navigation/` - Navegação (SideMenu, TabBar)
- `organisms/tables/` - Tabelas (ReusableDataTable, DynamicPaginatedTable)
- `organisms/editors/` - Editores (CustomBriefingEditor, ChatBriefing)
- `organisms/sections/` - Seções (CommentsSection, TaskFilesSection)
- `organisms/dialogs/` - Diálogos (StandardDialog)
- `organisms/tabs/` - Tabs (GenericTabView)
- `organisms/lists/` - Listas (ReorderableDragList)

### Import:
```dart
import 'package:gestor_projetos_flutter/ui/organisms/organisms.dart';
```

---

## 📄 TEMPLATES (Templates)

**Layouts de página** - estruturas de página sem dados reais.

### Características:
- Definem a estrutura da página
- Não contêm dados reais
- Reutilizáveis para múltiplas páginas
- Exemplos: layout de lista, layout de detalhes

### Import:
```dart
import 'package:gestor_projetos_flutter/ui/templates/templates.dart';
```

---

## 📱 PAGES (Páginas)

**Páginas completas** - instâncias de templates com dados reais.

### Localização:
As páginas permanecem em `lib/src/features/*/` organizadas por funcionalidade.

---

## 🎯 Boas Práticas

### 1. Hierarquia de Dependências
```
Pages → Templates → Organisms → Molecules → Atoms
```

**Regras:**
- ✅ Atoms podem importar outros atoms
- ✅ Molecules podem importar atoms e outras molecules
- ✅ Organisms podem importar atoms, molecules e outros organisms
- ❌ Atoms NÃO podem importar molecules ou organisms
- ❌ Molecules NÃO podem importar organisms

### 2. Import Único
Prefira usar o barrel file principal:
```dart
// ✅ Recomendado
import 'package:gestor_projetos_flutter/ui/ui.dart';

// ⚠️ Alternativa (mais específico)
import 'package:gestor_projetos_flutter/ui/atoms/atoms.dart';
import 'package:gestor_projetos_flutter/ui/molecules/molecules.dart';
```

### 3. Nomenclatura
- **Atoms:** Nome descritivo + tipo (ex: `PrimaryButton`, `GenericTextField`)
- **Molecules:** Nome descritivo da função (ex: `SearchableDropdownField`, `UserAvatarName`)
- **Organisms:** Nome da seção/componente (ex: `SideMenu`, `CommentsSection`)

### 4. Documentação
Cada componente deve ter:
- Comentário de documentação no topo
- Exemplos de uso
- Parâmetros documentados

---

## 🔄 Migração

Esta estrutura foi criada através de uma refatoração incremental da estrutura anterior (`lib/widgets/`).

### Histórico:
- **Antes:** `lib/widgets/` (estrutura plana)
- **Depois:** `lib/ui/` (Atomic Design)

### Compatibilidade:
Durante a migração, ambas as estruturas coexistem. Após a conclusão, `lib/widgets/` será removida.

---

## 📚 Referências

- [Atomic Design by Brad Frost](https://bradfrost.com/blog/post/atomic-web-design/)
- [Atomic Design Methodology](https://atomicdesign.bradfrost.com/)

---

**Última atualização:** 2025-10-13  
**Status:** ✅ Estrutura criada e em migração

