# Componentes de Botão Genéricos

Componentes reutilizáveis e consistentes para botões em todo o aplicativo.

---

## 📦 Componentes Disponíveis

### 1. PrimaryButton
Botão principal para ações primárias.

**Características:**
- ✅ Background preenchido (FilledButton)
- ✅ Cor do tema global
- ✅ BorderRadius 12
- ✅ Suporta ícone opcional
- ✅ Loading state integrado

**Exemplo básico:**
```dart
PrimaryButton(
  onPressed: _save,
  label: 'Salvar',
)
```

**Exemplo com ícone:**
```dart
PrimaryButton(
  onPressed: _create,
  label: 'Criar Novo',
  icon: Icons.add,
)
```

**Exemplo com loading:**
```dart
PrimaryButton(
  onPressed: _saving ? null : _save,
  label: 'Salvar',
  isLoading: _saving,
)
```

---

### 2. SecondaryButton
Botão secundário para ações secundárias.

**Características:**
- ✅ Borda outline (OutlinedButton)
- ✅ Cor do tema global
- ✅ BorderRadius 12
- ✅ Suporta ícone opcional
- ✅ Loading state integrado

**Exemplo:**
```dart
SecondaryButton(
  onPressed: () => Navigator.pop(context),
  label: 'Cancelar',
)
```

**Exemplo com ícone:**
```dart
SecondaryButton(
  onPressed: _export,
  label: 'Exportar',
  icon: Icons.download,
)
```

---

### 3. TextOnlyButton
Botão de texto para ações terciárias.

**Características:**
- ✅ Apenas texto (TextButton)
- ✅ Sem background
- ✅ Cor do tema global
- ✅ BorderRadius 12
- ✅ Suporta ícone opcional

**Exemplo:**
```dart
TextOnlyButton(
  onPressed: _viewDetails,
  label: 'Ver Detalhes',
  icon: Icons.arrow_forward,
)
```

---

### 4. DangerButton
Botão de ação destrutiva.

**Características:**
- ✅ Background vermelho (ou outline vermelho)
- ✅ Texto branco (ou vermelho se outlined)
- ✅ BorderRadius 12
- ✅ Suporta ícone opcional
- ✅ Loading state integrado
- ✅ Modo filled ou outlined

**Exemplo filled:**
```dart
DangerButton(
  onPressed: _delete,
  label: 'Excluir',
  icon: Icons.delete,
)
```

**Exemplo outlined:**
```dart
DangerButton(
  onPressed: _delete,
  label: 'Excluir',
  icon: Icons.delete,
  outlined: true,
)
```

---

### 5. IconTextButton
Botão tonal com ícone e texto.

**Características:**
- ✅ Background tonal (FilledButton.tonal)
- ✅ Ícone + texto obrigatórios
- ✅ Cor do tema global
- ✅ BorderRadius 12
- ✅ Loading state integrado

**Exemplo:**
```dart
IconTextButton(
  onPressed: _addItem,
  icon: Icons.add,
  label: 'Adicionar Item',
)
```

---

### 6. IconOnlyButton
Botão apenas com ícone (sem texto).

**Características:**
- ✅ Apenas ícone (IconButton)
- ✅ Sem texto
- ✅ Tooltip opcional
- ✅ Loading state integrado
- ✅ 4 variantes: standard, filled, tonal, outlined
- ✅ Tamanho customizável

**Exemplo básico (standard):**
```dart
IconOnlyButton(
  onPressed: _edit,
  icon: Icons.edit,
  tooltip: 'Editar',
)
```

**Exemplo filled:**
```dart
IconOnlyButton(
  onPressed: _delete,
  icon: Icons.delete,
  tooltip: 'Excluir',
  variant: IconButtonVariant.filled,
)
```

**Exemplo tonal:**
```dart
IconOnlyButton(
  onPressed: _settings,
  icon: Icons.settings,
  tooltip: 'Configurações',
  variant: IconButtonVariant.tonal,
)
```

**Exemplo outlined:**
```dart
IconOnlyButton(
  onPressed: _info,
  icon: Icons.info,
  tooltip: 'Informações',
  variant: IconButtonVariant.outlined,
)
```

**Exemplo com loading:**
```dart
IconOnlyButton(
  onPressed: _loading ? null : _refresh,
  icon: Icons.refresh,
  tooltip: 'Recarregar',
  isLoading: _loading,
)
```

**Quando usar:**
- ✅ Ações rápidas em toolbars
- ✅ Botões de edição/exclusão em tabelas
- ✅ Ícones de ação em cards
- ✅ Botões de navegação
- ✅ Quando o espaço é limitado

---

## 🎨 Design Consistente

Todos os componentes seguem o tema global definido em `app_theme.dart`:

```dart
// Tema global
filledButtonTheme: FilledButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
    foregroundColor: WidgetStateProperty.all(scheme.onSurface),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
)
```

**Características visuais:**
- ✅ BorderRadius: 12
- ✅ Padding: horizontal 16, vertical 12
- ✅ Cores do tema global
- ✅ Loading state com CircularProgressIndicator

---

## 📝 Guia de Uso

### Importação

```dart
import 'package:gestor_projetos_flutter/widgets/buttons/buttons.dart';
```

### Escolhendo o Componente Certo

| Tipo de Ação | Componente | Exemplo |
|--------------|------------|---------|
| Ação principal (salvar, criar) | PrimaryButton | Salvar formulário |
| Ação secundária (cancelar, voltar) | SecondaryButton | Cancelar operação |
| Ação terciária (ver, expandir) | TextOnlyButton | Ver detalhes |
| Ação destrutiva (excluir, remover) | DangerButton | Excluir item |
| Ação com ícone (adicionar, recarregar) | IconTextButton | Adicionar item |

### Boas Práticas

#### 1. Use isLoading para estados de carregamento
```dart
PrimaryButton(
  onPressed: _saving ? null : _save,
  label: 'Salvar',
  isLoading: _saving,
)
```

#### 2. Desabilite botões durante operações
```dart
onPressed: _saving ? null : _save
```

#### 3. Use ícones para clareza
```dart
PrimaryButton(
  onPressed: _create,
  label: 'Criar Novo',
  icon: Icons.add,
)
```

#### 4. Use DangerButton para ações destrutivas
```dart
DangerButton(
  onPressed: _delete,
  label: 'Excluir',
  icon: Icons.delete,
)
```

#### 5. Hierarquia de botões em formulários
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextOnlyButton(
      onPressed: () => Navigator.pop(context),
      label: 'Cancelar',
    ),
    const SizedBox(width: 8),
    PrimaryButton(
      onPressed: _save,
      label: 'Salvar',
      isLoading: _saving,
    ),
  ],
)
```

---

## 🔄 Migração de Código Existente

### Antes (FilledButton inline):
```dart
FilledButton(
  onPressed: _saving ? null : _save,
  child: const Text('Salvar'),
)
```

### Depois (PrimaryButton):
```dart
PrimaryButton(
  onPressed: _saving ? null : _save,
  label: 'Salvar',
  isLoading: _saving,
)
```

**Benefícios:**
- ✅ Loading state integrado
- ✅ Mais legível
- ✅ Consistente

---

### Antes (TextButton inline):
```dart
TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text('Cancelar'),
)
```

### Depois (TextOnlyButton):
```dart
TextOnlyButton(
  onPressed: () => Navigator.pop(context),
  label: 'Cancelar',
)
```

---

### Antes (FilledButton.tonal inline):
```dart
FilledButton.tonal(
  onPressed: _addItem,
  child: Row(
    children: [
      const Icon(Icons.add),
      const SizedBox(width: 8),
      const Text('Adicionar Item'),
    ],
  ),
)
```

### Depois (IconTextButton):
```dart
IconTextButton(
  onPressed: _addItem,
  icon: Icons.add,
  label: 'Adicionar Item',
)
```

**Benefícios:**
- ✅ Menos código
- ✅ Ícone integrado
- ✅ Mais legível

---

## 🎯 Exemplos Práticos

### Formulário de Cliente
```dart
actions: [
  TextOnlyButton(
    onPressed: _saving ? null : () => Navigator.pop(context),
    label: 'Cancelar',
  ),
  PrimaryButton(
    onPressed: _saving ? null : _save,
    label: isEditing ? 'Salvar' : 'Criar',
    isLoading: _saving,
  ),
],
```

### Dialog de Confirmação de Exclusão
```dart
actions: [
  SecondaryButton(
    onPressed: () => Navigator.pop(context, false),
    label: 'Cancelar',
  ),
  DangerButton(
    onPressed: () => Navigator.pop(context, true),
    label: 'Excluir',
    icon: Icons.delete,
  ),
],
```

### Toolbar com Ações
```dart
Row(
  children: [
    IconTextButton(
      onPressed: _addCost,
      icon: Icons.add,
      label: 'Adicionar Custo',
    ),
    const SizedBox(width: 8),
    IconTextButton(
      onPressed: _addItem,
      icon: Icons.shopping_cart,
      label: 'Adicionar Item',
    ),
  ],
)
```

---

## 📚 Documentação Adicional

- [Tema Global](../../src/theme/app_theme.dart)
- [Componentes Input](../inputs/README.md)
- [Componentes Dropdown](../dropdowns/README.md)
- [Guia de Estilo](../../docs/STYLE_GUIDE.md)

