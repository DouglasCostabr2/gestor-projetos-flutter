# GenericCheckbox - Guia de Uso

## 📦 Componente Criado

**Arquivo:** `lib/widgets/inputs/generic_checkbox.dart`

**Status:** ✅ Pronto para uso

---

## 🎯 Quando Usar

O `GenericCheckbox` é ideal para **formulários** onde você precisa de campos booleanos:

### ✅ Casos de Uso Recomendados

1. **Campos de ativação/desativação**
   - Ativo/Inativo
   - Habilitado/Desabilitado
   - Público/Privado

2. **Aceite de termos**
   - "Aceito os termos e condições"
   - "Li e concordo com a política de privacidade"

3. **Opções booleanas em formulários**
   - "Enviar notificações por email"
   - "Permitir comentários"
   - "Marcar como urgente"

4. **Seleção múltipla com tristate**
   - "Selecionar todos"
   - Estados: null (parcial), true (todos), false (nenhum)

### ✅ Uso em Tabelas (Sem Label)

5. **Checkboxes de seleção em tabelas**
   - Use `GenericCheckbox` **sem label** para manter consistência
   - Exemplo: `ReusableDataTable` usa `GenericCheckbox` para seleção de linhas

### ❌ Quando NÃO Usar

1. **Checkboxes em listas de tarefas/briefing**
   - Use os componentes específicos como `CustomBriefingEditor`
   - Esses têm comportamento e estilo específicos

2. **Checkboxes inline em widgets muito customizados**
   - Se o checkbox faz parte de um widget muito específico com layout complexo

---

## 📝 Exemplos de Uso

### Exemplo 1: Campo Ativo/Inativo (Básico)

```dart
import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';

class MyForm extends StatefulWidget {
  @override
  State<MyForm> createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  bool _isActive = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GenericCheckbox(
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value ?? false),
          label: 'Ativo',
          enabled: !_saving,
        ),
      ],
    );
  }
}
```

### Exemplo 2: Aceite de Termos (Com Validação)

```dart
class TermsForm extends StatefulWidget {
  @override
  State<TermsForm> createState() => _TermsFormState();
}

class _TermsFormState extends State<TermsForm> {
  final _formKey = GlobalKey<FormState>();
  bool _acceptTerms = false;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Processar formulário
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          GenericCheckbox(
            value: _acceptTerms,
            onChanged: (value) => setState(() => _acceptTerms = value ?? false),
            label: 'Aceito os termos e condições *',
            validator: (value) {
              if (value != true) {
                return 'Você deve aceitar os termos para continuar';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
```

### Exemplo 3: Múltiplas Opções

```dart
class NotificationSettings extends StatefulWidget {
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  bool _emailNotifications = true;
  bool _pushNotifications = false;
  bool _smsNotifications = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notificações',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GenericCheckbox(
          value: _emailNotifications,
          onChanged: (value) => setState(() => _emailNotifications = value ?? false),
          label: 'Receber notificações por email',
          enabled: !_saving,
        ),
        const SizedBox(height: 8),
        GenericCheckbox(
          value: _pushNotifications,
          onChanged: (value) => setState(() => _pushNotifications = value ?? false),
          label: 'Receber notificações push',
          enabled: !_saving,
        ),
        const SizedBox(height: 8),
        GenericCheckbox(
          value: _smsNotifications,
          onChanged: (value) => setState(() => _smsNotifications = value ?? false),
          label: 'Receber notificações por SMS',
          enabled: !_saving,
        ),
      ],
    );
  }
}
```

### Exemplo 4: Tristate (Selecionar Todos)

```dart
class SelectAllExample extends StatefulWidget {
  @override
  State<SelectAllExample> createState() => _SelectAllExampleState();
}

class _SelectAllExampleState extends State<SelectAllExample> {
  bool? _selectAll; // null = parcial, true = todos, false = nenhum
  bool _option1 = false;
  bool _option2 = false;
  bool _option3 = false;

  void _updateSelectAll() {
    if (_option1 && _option2 && _option3) {
      _selectAll = true;
    } else if (!_option1 && !_option2 && !_option3) {
      _selectAll = false;
    } else {
      _selectAll = null; // Parcialmente selecionado
    }
  }

  void _onSelectAllChanged(bool? value) {
    setState(() {
      if (value == true) {
        _option1 = true;
        _option2 = true;
        _option3 = true;
        _selectAll = true;
      } else {
        _option1 = false;
        _option2 = false;
        _option3 = false;
        _selectAll = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GenericCheckbox(
          value: _selectAll,
          onChanged: _onSelectAllChanged,
          label: 'Selecionar todos',
          tristate: true,
        ),
        const Divider(),
        GenericCheckbox(
          value: _option1,
          onChanged: (value) {
            setState(() {
              _option1 = value ?? false;
              _updateSelectAll();
            });
          },
          label: 'Opção 1',
        ),
        GenericCheckbox(
          value: _option2,
          onChanged: (value) {
            setState(() {
              _option2 = value ?? false;
              _updateSelectAll();
            });
          },
          label: 'Opção 2',
        ),
        GenericCheckbox(
          value: _option3,
          onChanged: (value) {
            setState(() {
              _option3 = value ?? false;
              _updateSelectAll();
            });
          },
          label: 'Opção 3',
        ),
      ],
    );
  }
}
```

### Exemplo 5: Label à Esquerda

```dart
GenericCheckbox(
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value ?? false),
  label: 'Habilitado',
  labelPosition: CheckboxLabelPosition.left,
)
```

### Exemplo 6: Sem Label (Apenas Checkbox)

```dart
GenericCheckbox(
  value: _isChecked,
  onChanged: (value) => setState(() => _isChecked = value ?? false),
)
```

---

## 🎨 Personalização

### Cores Customizadas

```dart
GenericCheckbox(
  value: _isActive,
  onChanged: (value) => setState(() => _isActive = value ?? false),
  label: 'Ativo',
  activeColor: Colors.green,
  checkColor: Colors.white,
)
```

### Espaçamento Customizado

```dart
GenericCheckbox(
  value: _isActive,
  onChanged: (value) => setState(() => _isActive = value ?? false),
  label: 'Ativo',
  spacing: 12.0, // Espaço entre checkbox e label
  padding: const EdgeInsets.all(8), // Padding ao redor
)
```

### Estilo do Label

```dart
GenericCheckbox(
  value: _isActive,
  onChanged: (value) => setState(() => _isActive = value ?? false),
  label: 'Ativo',
  labelStyle: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
)
```

---

## 🔧 Propriedades

| Propriedade | Tipo | Obrigatório | Descrição |
|-------------|------|-------------|-----------|
| `value` | `bool?` | ✅ | Valor atual do checkbox |
| `onChanged` | `ValueChanged<bool?>?` | ❌ | Callback quando o valor muda |
| `label` | `String?` | ❌ | Texto do label |
| `labelStyle` | `TextStyle?` | ❌ | Estilo do texto do label |
| `labelPosition` | `CheckboxLabelPosition` | ❌ | Posição do label (left/right) |
| `enabled` | `bool` | ❌ | Se o checkbox está habilitado (padrão: true) |
| `tristate` | `bool` | ❌ | Se permite estado null (padrão: false) |
| `activeColor` | `Color?` | ❌ | Cor quando marcado |
| `checkColor` | `Color?` | ❌ | Cor do check |
| `validator` | `String? Function(bool?)?` | ❌ | Função de validação |
| `errorText` | `String?` | ❌ | Mensagem de erro manual |
| `spacing` | `double` | ❌ | Espaçamento entre checkbox e label (padrão: 8.0) |
| `padding` | `EdgeInsetsGeometry?` | ❌ | Padding ao redor do componente |
| `onTap` | `VoidCallback?` | ❌ | Callback customizado ao tocar |

---

## ✅ Conclusão

O `GenericCheckbox` está pronto para uso em **formulários** do projeto!

**Principais benefícios:**
- ✅ Design consistente com o tema global
- ✅ Validação integrada
- ✅ Suporte a tristate
- ✅ Click no label também marca/desmarca
- ✅ Fácil de usar e customizar

**Próximos passos:**
- Use em novos formulários que precisem de campos booleanos
- Considere migrar formulários existentes que usam `Checkbox` + `Text` inline

