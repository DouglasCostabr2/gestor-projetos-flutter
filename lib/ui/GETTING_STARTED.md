# 🚀 Guia de Início Rápido - Atomic Design

Bem-vindo ao sistema de componentes Atomic Design! Este guia vai te ajudar a começar em **5 minutos**.

---

## ⚡ Início em 3 Passos

### 1️⃣ Importe o UI

```dart
import 'package:gestor_projetos_flutter/ui/ui.dart';
```

Pronto! Você tem acesso a **todos** os componentes.

### 2️⃣ Use um Componente

```dart
PrimaryButton(
  onPressed: () => print('Clicou!'),
  child: const Text('Salvar'),
)
```

### 3️⃣ Combine Componentes

```dart
Column(
  children: [
    GenericTextField(
      controller: _controller,
      label: 'Nome',
    ),
    const SizedBox(height: 16),
    PrimaryButton(
      onPressed: _handleSave,
      child: const Text('Salvar'),
    ),
  ],
)
```

**Parabéns! Você já está usando Atomic Design! 🎉**

---

## 📚 Próximos Passos

### Nível 1: Básico (5 minutos)

1. ✅ Você está aqui!
2. 📖 Leia [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Lista de componentes
3. 💡 Veja [EXAMPLES.md](EXAMPLES.md) - Exemplos práticos

### Nível 2: Intermediário (15 minutos)

1. 📘 Leia [README.md](README.md) - Entenda os conceitos
2. 📁 Veja [STRUCTURE.md](STRUCTURE.md) - Conheça a organização
3. ✨ Estude [BEST_PRACTICES.md](BEST_PRACTICES.md) - Aprenda padrões

### Nível 3: Avançado (30 minutos)

1. 🔄 Leia [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Migre código antigo
2. 📊 Veja [ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md) - Status completo
3. 🗺️ Explore [ROADMAP.md](ROADMAP.md) - Próximos passos

---

## 🎯 Casos de Uso Comuns

### Criar um Formulário

```dart
class MyForm extends StatefulWidget {
  @override
  State<MyForm> createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GenericTextField(
          controller: _nameController,
          label: 'Nome',
          required: true,
        ),
        const SizedBox(height: 16),
        GenericTextField(
          controller: _emailController,
          label: 'Email',
          required: true,
        ),
        const SizedBox(height: 24),
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
    );
  }

  void _handleSave() {
    // Salvar dados
  }
}
```

### Usar Dropdown Assíncrono

```dart
AsyncDropdownField<String>(
  label: 'Cliente',
  value: _selectedClientId,
  onChanged: (value) => setState(() => _selectedClientId = value),
  fetchItems: () async {
    final response = await Supabase.instance.client
        .from('clients')
        .select('id, name')
        .order('name');
    
    return (response as List).map((item) {
      return DropdownItem<String>(
        value: item['id'],
        label: item['name'],
      );
    }).toList();
  },
)
```

### Exibir Avatar

```dart
CachedAvatar(
  imageUrl: user['avatar_url'],
  name: user['name'],
  size: 40,
)
```

### Criar Card de Usuário

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

## 🔍 Encontrar Componentes

### Por Tipo

| Preciso de... | Use... | Exemplo |
|---------------|--------|---------|
| Botão principal | `PrimaryButton` | Salvar, Confirmar |
| Botão secundário | `SecondaryButton` | Cancelar, Voltar |
| Campo de texto | `GenericTextField` | Nome, Email |
| Área de texto | `GenericTextArea` | Descrição, Observações |
| Seletor | `AsyncDropdownField` | Cliente, Categoria |
| Avatar | `CachedAvatar` | Foto do usuário |
| Data | `GenericDatePicker` | Data de entrega |

### Por Categoria

- **Buttons:** [QUICK_REFERENCE.md#buttons](QUICK_REFERENCE.md#buttons)
- **Inputs:** [QUICK_REFERENCE.md#inputs](QUICK_REFERENCE.md#inputs)
- **Dropdowns:** [QUICK_REFERENCE.md#dropdowns](QUICK_REFERENCE.md#dropdowns)
- **Table Cells:** [QUICK_REFERENCE.md#table-cells](QUICK_REFERENCE.md#table-cells)

---

## ❓ FAQ

### Como importar componentes?

```dart
// ✅ Recomendado - Import único
import 'package:gestor_projetos_flutter/ui/ui.dart';

// ⚠️ Alternativa - Import por categoria
import 'package:gestor_projetos_flutter/ui/atoms/atoms.dart';
import 'package:gestor_projetos_flutter/ui/molecules/molecules.dart';
```

### Onde encontro exemplos?

Veja [EXAMPLES.md](EXAMPLES.md) - Mais de 50 exemplos práticos!

### Como criar um novo componente?

Siga [BEST_PRACTICES.md](BEST_PRACTICES.md) - Guia completo de boas práticas.

### Onde está a lista completa de componentes?

Consulte [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Referência rápida com todos os componentes.

### Como migrar código antigo?

Use [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia passo a passo de migração.

---

## 🎨 Padrões Visuais

### Espaçamentos

```dart
const SizedBox(height: 8)   // Pequeno
const SizedBox(height: 16)  // Médio (padrão)
const SizedBox(height: 24)  // Grande
```

### Cores

```dart
// ✅ Use cores do tema
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.error

// ❌ Evite cores hardcoded
Colors.blue
Colors.red
```

### Botões

```dart
// Ação principal
PrimaryButton(...)

// Ação secundária
SecondaryButton(...)

// Ação destrutiva
DangerButton(...)

// Ação positiva
SuccessButton(...)
```

---

## 🛠️ Ferramentas Úteis

### Validar Estrutura

```bash
bash scripts/validate_atomic_design.sh
```

### Analisar Código

```bash
flutter analyze lib/ui/
```

### Executar Aplicativo

```bash
./build/windows/x64/runner/Debug/gestor_projetos_flutter.exe
```

---

## 📖 Documentação Completa

### Essencial
- 🚀 [GETTING_STARTED.md](GETTING_STARTED.md) - Este arquivo
- 📇 [INDEX.md](INDEX.md) - Índice de navegação
- 🔍 [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Referência rápida

### Aprendizado
- 📘 [README.md](README.md) - Conceitos fundamentais
- 💡 [EXAMPLES.md](EXAMPLES.md) - Exemplos práticos
- ✨ [BEST_PRACTICES.md](BEST_PRACTICES.md) - Boas práticas

### Referência
- 📁 [STRUCTURE.md](STRUCTURE.md) - Estrutura completa
- 🔄 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) - Guia de migração
- 📊 [ATOMIC_DESIGN_STATUS.md](ATOMIC_DESIGN_STATUS.md) - Status
- 🗺️ [ROADMAP.md](ROADMAP.md) - Plano futuro

---

## 💡 Dicas Rápidas

### ✅ Faça

- Use import único: `import 'package:gestor_projetos_flutter/ui/ui.dart';`
- Use `const` sempre que possível
- Siga a hierarquia: Atoms → Molecules → Organisms
- Consulte a documentação quando em dúvida

### ❌ Evite

- Imports individuais de cada componente
- Cores hardcoded (use tema)
- Criar componentes sem consultar padrões
- Quebrar a hierarquia de dependências

---

## 🎯 Checklist de Início

- [ ] Li este guia (GETTING_STARTED.md)
- [ ] Importei `ui.dart` no meu arquivo
- [ ] Usei meu primeiro componente
- [ ] Consultei QUICK_REFERENCE.md
- [ ] Vi exemplos em EXAMPLES.md
- [ ] Entendi a hierarquia (Atoms → Molecules → Organisms)
- [ ] Sei onde encontrar documentação (INDEX.md)

---

## 🆘 Precisa de Ajuda?

1. **Consulte a documentação:**
   - Comece pelo [INDEX.md](INDEX.md)
   - Veja exemplos em [EXAMPLES.md](EXAMPLES.md)

2. **Verifique os padrões:**
   - Leia [BEST_PRACTICES.md](BEST_PRACTICES.md)
   - Consulte [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

3. **Troubleshooting:**
   - Veja [QUICK_REFERENCE.md#troubleshooting](QUICK_REFERENCE.md#troubleshooting)

---

## 🎉 Pronto para Começar!

Você agora tem tudo que precisa para usar o sistema Atomic Design!

**Próximo passo:** Abra [QUICK_REFERENCE.md](QUICK_REFERENCE.md) e escolha um componente para usar!

---

**Boa codificação! 🚀**

---

**Última atualização:** 2025-10-13  
**Versão:** 1.0.0

