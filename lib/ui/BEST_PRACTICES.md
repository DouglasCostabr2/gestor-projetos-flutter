# Boas Práticas - Atomic Design

Este documento define as boas práticas e convenções para desenvolvimento de componentes seguindo o padrão Atomic Design.

---

## 🎯 Princípios Fundamentais

### 1. Hierarquia de Dependências

**REGRA DE OURO:** Componentes só podem importar componentes de níveis inferiores ou do mesmo nível.

```
Pages → Templates → Organisms → Molecules → Atoms
  ↓        ↓           ↓           ↓          ↓
  ✅       ✅          ✅          ✅         ❌ (não importa nada)
```

#### ✅ Permitido
```dart
// Molecule importando Atom
import '../../atoms/buttons/primary_button.dart';

// Organism importando Molecule
import '../../molecules/dropdowns/async_dropdown_field.dart';

// Organism importando Atom
import '../../atoms/inputs/generic_text_field.dart';

// Page importando Organism
import '../../../ui/organisms/tables/reusable_data_table.dart';
```

#### ❌ Proibido
```dart
// Atom NÃO pode importar Molecule
import '../../molecules/dropdowns/async_dropdown_field.dart'; // ❌

// Molecule NÃO pode importar Organism
import '../../organisms/tables/reusable_data_table.dart'; // ❌

// Atom NÃO pode importar outro Atom (exceto em casos específicos)
import '../inputs/generic_text_field.dart'; // ⚠️ Evitar
```

---

## 📦 Organização de Arquivos

### Estrutura de Pastas

```
lib/ui/
├── atoms/
│   ├── buttons/
│   │   ├── primary_button.dart
│   │   ├── secondary_button.dart
│   │   └── buttons.dart (barrel file)
│   ├── inputs/
│   │   ├── generic_text_field.dart
│   │   └── inputs.dart (barrel file)
│   └── atoms.dart (barrel file principal)
│
├── molecules/
│   ├── dropdowns/
│   │   ├── async_dropdown_field.dart
│   │   └── dropdowns.dart (barrel file)
│   └── molecules.dart (barrel file principal)
│
└── ui.dart (barrel file raiz)
```

### Nomenclatura de Arquivos

- **Snake case:** `primary_button.dart`, `async_dropdown_field.dart`
- **Descritivo:** Nome deve descrever claramente o componente
- **Sufixos comuns:**
  - `_button.dart` para botões
  - `_field.dart` para campos de input
  - `_dialog.dart` para diálogos
  - `_section.dart` para seções
  - `_cell.dart` para células de tabela

---

## 🔤 Nomenclatura de Classes

### Atoms
```dart
// ✅ BOM - Nome descritivo e específico
class PrimaryButton extends StatelessWidget { }
class GenericTextField extends StatefulWidget { }
class CachedAvatar extends StatelessWidget { }

// ❌ RUIM - Nome genérico demais
class Button extends StatelessWidget { }
class Input extends StatelessWidget { }
class Avatar extends StatelessWidget { }
```

### Molecules
```dart
// ✅ BOM - Indica combinação de atoms
class AsyncDropdownField<T> extends StatefulWidget { }
class UserAvatarName extends StatelessWidget { }
class TableCellAvatar extends StatelessWidget { }

// ❌ RUIM - Não indica que é uma molecule
class Dropdown extends StatelessWidget { }
class UserInfo extends StatelessWidget { }
```

### Organisms
```dart
// ✅ BOM - Nome indica complexidade
class ReusableDataTable extends StatefulWidget { }
class CustomBriefingEditor extends StatefulWidget { }
class CommentsSection extends StatefulWidget { }

// ❌ RUIM - Nome muito genérico
class Table extends StatelessWidget { }
class Editor extends StatelessWidget { }
class Comments extends StatelessWidget { }
```

---

## 📝 Documentação de Componentes

### Template de Documentação

```dart
/// Nome do Componente
///
/// Descrição breve do que o componente faz.
///
/// **Categoria:** Atom | Molecule | Organism
///
/// **Uso:**
/// ```dart
/// PrimaryButton(
///   onPressed: () => print('Clicado'),
///   child: const Text('Salvar'),
/// )
/// ```
///
/// **Parâmetros:**
/// - [onPressed]: Callback quando o botão é pressionado
/// - [child]: Widget filho a ser exibido no botão
/// - [enabled]: Se o botão está habilitado (padrão: true)
///
/// **Exemplo Completo:**
/// ```dart
/// PrimaryButton(
///   onPressed: _saving ? null : _handleSave,
///   child: _saving
///       ? const CircularProgressIndicator()
///       : const Text('Salvar'),
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  /// Callback executado quando o botão é pressionado
  final VoidCallback? onPressed;
  
  /// Widget filho a ser exibido no botão
  final Widget child;
  
  /// Se o botão está habilitado
  final bool enabled;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Implementação
  }
}
```

---

## 🎨 Estilo e Tema

### Use Theme do Material

```dart
// ✅ BOM - Usa cores do tema
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.primary,
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
  ),
  // ...
)

// ❌ RUIM - Cores hardcoded
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  // ...
)
```

### Constantes de Estilo

```dart
// ✅ BOM - Constantes reutilizáveis
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppBorderRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
}

// Uso
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
    ),
  ),
)
```

---

## 🔧 Parâmetros e Props

### Parâmetros Obrigatórios vs Opcionais

```dart
// ✅ BOM - Parâmetros essenciais são required
class GenericTextField extends StatelessWidget {
  final TextEditingController controller;  // required
  final String label;                      // required
  final String? hint;                      // opcional
  final bool required;                     // opcional com default
  final int? maxLength;                    // opcional

  const GenericTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.maxLength,
  });
}

// ❌ RUIM - Tudo opcional
class GenericTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  
  const GenericTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
  });
}
```

### Valores Padrão Sensatos

```dart
// ✅ BOM - Defaults úteis
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showBorder;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40.0,        // Tamanho padrão razoável
    this.showBorder = true,  // Comportamento padrão útil
  });
}
```

---

## 🧪 Testabilidade

### Componentes Testáveis

```dart
// ✅ BOM - Componente facilmente testável
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Key? buttonKey;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: buttonKey,  // Permite encontrar em testes
      onPressed: onPressed,
      child: child,
    );
  }
}

// Teste
testWidgets('PrimaryButton calls onPressed when tapped', (tester) async {
  bool pressed = false;
  
  await tester.pumpWidget(
    MaterialApp(
      home: PrimaryButton(
        buttonKey: const Key('test-button'),
        onPressed: () => pressed = true,
        child: const Text('Test'),
      ),
    ),
  );
  
  await tester.tap(find.byKey(const Key('test-button')));
  expect(pressed, true);
});
```

---

## 🚀 Performance

### Use const quando possível

```dart
// ✅ BOM - Widgets const
const SizedBox(height: 16)
const Text('Label')
const Icon(Icons.add)

// ❌ RUIM - Widgets não-const desnecessariamente
SizedBox(height: 16)
Text('Label')
Icon(Icons.add)
```

### Evite rebuilds desnecessários

```dart
// ✅ BOM - Separa estado local
class MyForm extends StatefulWidget {
  @override
  State<MyForm> createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  final _nameController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GenericTextField(
          controller: _nameController,
          label: 'Nome',
        ),
        const _StaticSection(),  // Não rebuilda
      ],
    );
  }
}

class _StaticSection extends StatelessWidget {
  const _StaticSection();
  
  @override
  Widget build(BuildContext context) {
    return const Text('Seção estática');
  }
}
```

---

## 📋 Checklist de Criação de Componente

Antes de criar um novo componente, verifique:

- [ ] O componente está na categoria correta (Atom/Molecule/Organism)?
- [ ] O nome é descritivo e segue a convenção?
- [ ] Tem documentação adequada (dartdoc)?
- [ ] Parâmetros obrigatórios estão marcados como `required`?
- [ ] Valores padrão são sensatos?
- [ ] Usa `const` onde possível?
- [ ] Usa cores/estilos do tema?
- [ ] Respeita a hierarquia de dependências?
- [ ] Está no barrel file correto?
- [ ] Tem exemplo de uso na documentação?

---

## 🔄 Refatoração

### Quando extrair um componente?

Extraia para um novo componente quando:

1. **Reutilização:** Usado em 2+ lugares
2. **Complexidade:** Mais de 100 linhas
3. **Responsabilidade:** Faz mais de uma coisa
4. **Testabilidade:** Difícil de testar isoladamente

### Exemplo de Refatoração

```dart
// ❌ ANTES - Tudo em um componente
class ProjectForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 50 linhas de header
        // 100 linhas de formulário
        // 30 linhas de footer
        // Total: 180 linhas
      ],
    );
  }
}

// ✅ DEPOIS - Separado em componentes
class ProjectForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ProjectFormHeader(),
        _ProjectFormFields(),
        _ProjectFormFooter(),
      ],
    );
  }
}

class _ProjectFormHeader extends StatelessWidget { }
class _ProjectFormFields extends StatelessWidget { }
class _ProjectFormFooter extends StatelessWidget { }
```

---

## 📚 Recursos Adicionais

- [Atomic Design Methodology](https://bradfrost.com/blog/post/atomic-web-design/)
- [Flutter Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

