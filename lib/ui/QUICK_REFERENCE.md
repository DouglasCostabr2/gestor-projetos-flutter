# Referência Rápida - Atomic Design

Guia rápido para consulta durante o desenvolvimento.

---

## 📦 Import

```dart
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

---

## 🔹 Atoms

### Buttons

| Componente | Uso | Exemplo |
|------------|-----|---------|
| `PrimaryButton` | Ação principal | Salvar, Confirmar, Criar |
| `SecondaryButton` | Ação secundária | Cancelar, Voltar |
| `OutlineButton` | Ação terciária | Editar, Ver Mais |
| `DangerButton` | Ação destrutiva | Excluir, Remover |
| `SuccessButton` | Ação positiva | Aprovar, Concluir |
| `IconButtonCustom` | Ação com ícone | Adicionar, Buscar |
| `TextButtonCustom` | Link/texto | Ajuda, Saiba Mais |

### Inputs

| Componente | Uso |
|------------|-----|
| `GenericTextField` | Campo de texto simples |
| `GenericTextArea` | Campo de texto multilinha |
| `GenericNumberField` | Campo numérico |
| `GenericDatePicker` | Seletor de data |
| `GenericCheckbox` | Checkbox |
| `GenericColorPicker` | Seletor de cor |

### Avatars

| Componente | Uso |
|------------|-----|
| `CachedAvatar` | Avatar com cache de imagem |

---

## 🔸 Molecules

### Dropdowns

| Componente | Uso |
|------------|-----|
| `AsyncDropdownField<T>` | Dropdown que carrega dados async |
| `SearchableDropdownField<T>` | Dropdown com busca |
| `MultiSelectDropdownField<T>` | Dropdown multi-seleção |

### Table Cells

| Componente | Uso |
|------------|-----|
| `TableCellAvatar` | Célula com avatar |
| `TableCellAvatarList` | Célula com lista de avatares |
| `TableCellBadge` | Célula com badge/tag |
| `TableCellDate` | Célula com data formatada |
| `TableCellText` | Célula com texto |
| `TableCellUpdatedBy` | Célula com usuário + data |

### User Components

| Componente | Uso |
|------------|-----|
| `UserAvatarName` | Avatar + nome do usuário |

---

## 🎨 Padrões Comuns

### Formulário Básico

```dart
Column(
  children: [
    GenericTextField(
      controller: _controller,
      label: 'Nome',
      required: true,
    ),
    const SizedBox(height: 16),
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SecondaryButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        PrimaryButton(
          onPressed: _handleSave,
          child: const Text('Salvar'),
        ),
      ],
    ),
  ],
)
```

### Dropdown Async

```dart
AsyncDropdownField<String>(
  label: 'Cliente',
  value: _selectedId,
  onChanged: (value) => setState(() => _selectedId = value),
  fetchItems: () async {
    final response = await supabase
        .from('clients')
        .select('id, name');
    return (response as List).map((item) {
      return DropdownItem<String>(
        value: item['id'],
        label: item['name'],
      );
    }).toList();
  },
)
```

### Card com Avatar

```dart
Card(
  child: ListTile(
    leading: CachedAvatar(
      imageUrl: user['avatar_url'],
      name: user['name'],
      size: 40,
    ),
    title: Text(user['name']),
    subtitle: Text(user['email']),
    trailing: IconButtonCustom(
      icon: Icons.edit,
      onPressed: () => _handleEdit(user),
    ),
  ),
)
```

---

## 🎯 Hierarquia

```
❌ Atoms → NÃO importa nada
✅ Molecules → Atoms
✅ Organisms → Atoms + Molecules
✅ Templates → Atoms + Molecules + Organisms
✅ Pages → Atoms + Molecules + Organisms + Templates
```

---

## 📏 Espaçamentos

```dart
const SizedBox(height: 4)   // xs
const SizedBox(height: 8)   // sm
const SizedBox(height: 16)  // md (padrão)
const SizedBox(height: 24)  // lg
const SizedBox(height: 32)  // xl
```

---

## 🎨 Cores do Tema

```dart
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.secondary
Theme.of(context).colorScheme.error
Theme.of(context).colorScheme.surface
Theme.of(context).colorScheme.background
```

---

## ✅ Checklist Rápido

Ao criar componente:

- [ ] Nome descritivo
- [ ] Categoria correta (Atom/Molecule/Organism)
- [ ] Documentação (dartdoc)
- [ ] `required` nos parâmetros obrigatórios
- [ ] `const` onde possível
- [ ] Usa tema (não hardcode cores)
- [ ] No barrel file correto
- [ ] Respeita hierarquia

---

## 🔗 Links Úteis

- [README.md](README.md) - Documentação completa
- [EXAMPLES.md](EXAMPLES.md) - Exemplos de uso
- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Boas práticas
- [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia de migração
- [ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md) - Status

---

## 🆘 Troubleshooting

### Import não encontrado
```dart
// ❌ Erro
import 'package:gestor_projetos_flutter/ui/atoms/buttons/primary_button.dart';

// ✅ Solução
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

### Componente não encontrado
Verifique se está no barrel file:
- `lib/ui/atoms/buttons/buttons.dart`
- `lib/ui/atoms/atoms.dart`
- `lib/ui/ui.dart`

### Erro de hierarquia
```dart
// ❌ Atom importando Molecule
import '../../molecules/dropdowns/async_dropdown_field.dart';

// ✅ Molecule importando Atom
import '../../atoms/buttons/primary_button.dart';
```

---

## 📊 Estatísticas Atuais

- **Atoms:** 14 componentes
- **Molecules:** 10 componentes
- **Organisms:** Em migração
- **Total migrado:** 24 componentes

---

**Última atualização:** 2025-10-13

