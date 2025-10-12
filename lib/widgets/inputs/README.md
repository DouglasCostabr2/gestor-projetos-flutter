# Componentes de Input Genéricos

Componentes reutilizáveis e consistentes para campos de entrada de dados.

---

## 📦 Componentes Disponíveis

### 1. GenericTextField
Campo de texto simples com validação e formatação.

**Características:**
- ✅ Validação customizável
- ✅ Máscaras e formatadores
- ✅ Prefixo e sufixo (ícone ou texto)
- ✅ Contador de caracteres opcional
- ✅ Suporte a senha (obscureText)

**Exemplo básico:**
```dart
GenericTextField(
  controller: _nameController,
  labelText: 'Nome *',
  hintText: 'Digite seu nome',
  validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
  enabled: !_saving,
)
```

**Exemplo com máscara:**
```dart
GenericTextField(
  controller: _cepController,
  labelText: 'CEP',
  hintText: '00000-000',
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    CepInputFormatter(),
  ],
)
```

**Exemplo de senha:**
```dart
GenericTextField(
  controller: _passwordController,
  labelText: 'Senha *',
  obscureText: true,
  prefixIcon: Icon(Icons.lock_outline),
)
```

---

### 2. GenericTextArea
Campo de texto multilinha para descrições e notas.

**Características:**
- ✅ Múltiplas linhas
- ✅ Altura expansível ou fixa
- ✅ Contador de caracteres opcional
- ✅ Label alinhado com hint (topo)

**Exemplo:**
```dart
GenericTextArea(
  controller: _descriptionController,
  labelText: 'Descrição',
  hintText: 'Digite a descrição do projeto...',
  minLines: 3,
  maxLines: 8,
  maxLength: 500,
  showCounter: true,
  enabled: !_saving,
)
```

**Exemplo sem limite de linhas:**
```dart
GenericTextArea(
  controller: _notesController,
  labelText: 'Notas',
  minLines: 5,
  maxLines: null, // Expansível infinitamente
)
```

---

### 3. GenericNumberField
Campo numérico com validação de range e formatação.

**Características:**
- ✅ Aceita apenas números
- ✅ Suporta decimais opcionalmente
- ✅ Validação de range (min/max)
- ✅ Prefixo e sufixo (ex: R$, kg)

**Exemplo (inteiro):**
```dart
GenericNumberField(
  controller: _quantityController,
  labelText: 'Quantidade *',
  hintText: '0',
  allowDecimals: false,
  min: 1,
  max: 100,
  validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
)
```

**Exemplo (decimal com moeda):**
```dart
GenericNumberField(
  controller: _priceController,
  labelText: 'Preço',
  hintText: '0,00',
  allowDecimals: true,
  decimalDigits: 2,
  prefixText: 'R\$ ',
  min: 0,
)
```

**Exemplo (peso):**
```dart
GenericNumberField(
  controller: _weightController,
  labelText: 'Peso',
  allowDecimals: true,
  suffixText: 'kg',
)
```

---

### 4. GenericEmailField
Campo de email com validação integrada.

**Características:**
- ✅ Validação de formato de email
- ✅ Teclado de email automático
- ✅ Ícone de email padrão
- ✅ Campo obrigatório opcional

**Exemplo:**
```dart
GenericEmailField(
  controller: _emailController,
  labelText: 'Email *',
  hintText: 'seu@email.com',
  required: true,
  enabled: !_saving,
)
```

**Exemplo com validação customizada:**
```dart
GenericEmailField(
  controller: _emailController,
  labelText: 'Email corporativo *',
  required: true,
  validator: (value) {
    if (value != null && !value.endsWith('@empresa.com')) {
      return 'Use email corporativo (@empresa.com)';
    }
    return null;
  },
)
```

---

### 5. GenericPhoneField
Campo de telefone com máscara brasileira.

**Características:**
- ✅ Máscara automática: (00) 0000-0000 ou (00) 00000-0000
- ✅ Suporta celular (11 dígitos) e fixo (10 dígitos)
- ✅ Teclado numérico
- ✅ Ícone de telefone padrão
- ✅ Validação de formato

**Exemplo:**
```dart
GenericPhoneField(
  controller: _phoneController,
  labelText: 'Telefone',
  hintText: '(00) 00000-0000',
  required: false,
  enabled: !_saving,
)
```

**Exemplo obrigatório:**
```dart
GenericPhoneField(
  controller: _phoneController,
  labelText: 'Telefone *',
  required: true,
  invalidPhoneMessage: 'Telefone inválido',
  requiredMessage: 'Informe o telefone',
)
```

---

### 6. GenericCheckbox
Checkbox com label e validação.

**Características:**
- ✅ Label customizável (à direita ou esquerda)
- ✅ Validação opcional
- ✅ Suporte a tristate (null, true, false)
- ✅ Cores customizáveis
- ✅ Click no label também marca/desmarca

**Exemplo básico:**
```dart
GenericCheckbox(
  value: _isActive,
  onChanged: (value) => setState(() => _isActive = value),
  label: 'Ativo',
  enabled: !_saving,
)
```

**Exemplo com validação:**
```dart
GenericCheckbox(
  value: _acceptTerms,
  onChanged: (value) => setState(() => _acceptTerms = value),
  label: 'Aceito os termos e condições *',
  validator: (value) => value != true ? 'Você deve aceitar os termos' : null,
)
```

**Exemplo tristate (selecionar todos):**
```dart
GenericCheckbox(
  value: _selectAll, // pode ser null, true ou false
  onChanged: (value) => setState(() => _selectAll = value),
  label: 'Selecionar todos',
  tristate: true,
)
```

**Exemplo sem label:**
```dart
GenericCheckbox(
  value: _isChecked,
  onChanged: (value) => setState(() => _isChecked = value),
)
```

**Exemplo com label à esquerda:**
```dart
GenericCheckbox(
  value: _isEnabled,
  onChanged: (value) => setState(() => _isEnabled = value),
  label: 'Habilitado',
  labelPosition: CheckboxLabelPosition.left,
)
```

---

## 🎨 Design Consistente

Todos os componentes seguem o tema global definido em `app_theme.dart`:

```dart
InputDecorationTheme(
  filled: true,
  fillColor: scheme.surfaceContainerHighest, // 0xFF151515
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: scheme.outlineVariant),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: scheme.primary, width: 2),
  ),
)
```

**Características visuais:**
- ✅ BorderRadius: 10 (arredondado)
- ✅ Filled: true (fundo preenchido)
- ✅ FillColor: 0xFF151515 (dark theme)
- ✅ FocusedBorder: cor primária com width 2
- ✅ Label: cor onSurfaceVariant
- ✅ Hint: cor onSurfaceVariant com alpha 0.7

---

## 📝 Guia de Uso

### Importação

```dart
import 'package:gestor_projetos_flutter/widgets/inputs/inputs.dart';
```

### Escolhendo o Componente Certo

| Tipo de Dado | Componente | Exemplo |
|--------------|------------|---------|
| Nome, título, texto curto | GenericTextField | Nome do projeto |
| Descrição, notas, texto longo | GenericTextArea | Descrição do projeto |
| Quantidade, número inteiro | GenericNumberField (allowDecimals: false) | Quantidade de itens |
| Preço, valor decimal | GenericNumberField (allowDecimals: true) | Preço do produto |
| Email | GenericEmailField | Email do cliente |
| Telefone | GenericPhoneField | Telefone de contato |
| Seleção booleana, ativo/inativo | GenericCheckbox | Ativo, Aceitar termos |

### Boas Práticas

#### 1. Marque campos obrigatórios com *
```dart
labelText: 'Nome *'
```

#### 2. Use controller OU initialValue, nunca ambos
```dart
// ✅ Correto
GenericTextField(
  controller: _nameController,
  labelText: 'Nome',
)

// ✅ Correto
GenericTextField(
  initialValue: 'Valor inicial',
  labelText: 'Nome',
)

// ❌ Errado
GenericTextField(
  controller: _nameController,
  initialValue: 'Valor inicial', // ERRO!
  labelText: 'Nome',
)
```

#### 3. Desabilite campos durante salvamento
```dart
enabled: !_saving
```

#### 4. Use validação apropriada
```dart
validator: (value) {
  if (value?.isEmpty ?? true) return 'Campo obrigatório';
  if (value!.length < 3) return 'Mínimo 3 caracteres';
  return null;
}
```

#### 5. Use hintText para exemplos
```dart
hintText: 'Ex: João Silva'
```

---

## 🔄 Migração de Código Existente

### Antes (TextFormField inline):
```dart
TextFormField(
  controller: _name,
  decoration: const InputDecoration(
    labelText: 'Nome *',
    border: OutlineInputBorder(),
  ),
  validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
)
```

### Depois (GenericTextField):
```dart
GenericTextField(
  controller: _name,
  labelText: 'Nome *',
  validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
)
```

**Benefícios:**
- ✅ Menos código
- ✅ Design consistente (não precisa especificar border)
- ✅ Mais legível

---

## 🎯 Próximos Passos

1. ✅ Componentes criados
2. ⏳ Migrar formulários existentes
3. ⏳ Criar testes
4. ⏳ Adicionar mais componentes conforme necessário:
   - GenericDateField (campo de data)
   - GenericPasswordField (senha com toggle de visibilidade)
   - GenericCurrencyField (moeda com formatação)
   - GenericCepField (CEP com busca automática)

---

## 📚 Documentação Adicional

- [Tema Global](../../src/theme/app_theme.dart)
- [Componentes Dropdown](../dropdowns/README.md)
- [Guia de Estilo](../../docs/STYLE_GUIDE.md)

