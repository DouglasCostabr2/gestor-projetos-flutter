/// Componentes de input genéricos reutilizáveis
///
/// Este módulo fornece componentes de input consistentes e type-safe
/// para uso em todo o projeto.
///
/// ## 📦 Componentes Disponíveis
///
/// ### 1. GenericTextField
/// Campo de texto simples com validação e formatação.
///
/// **Quando usar:**
/// - Campos de texto simples (nome, título, etc.)
/// - Campos com máscaras customizadas
/// - Campos com validação específica
///
/// **Exemplo:**
/// ```dart
/// GenericTextField(
///   controller: _nameController,
///   labelText: 'Nome *',
///   hintText: 'Digite seu nome',
///   validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
/// )
/// ```
///
/// ### 2. GenericTextArea
/// Campo de texto multilinha para descrições e notas.
///
/// **Quando usar:**
/// - Descrições
/// - Notas
/// - Comentários
/// - Qualquer texto longo
///
/// **Exemplo:**
/// ```dart
/// GenericTextArea(
///   controller: _descriptionController,
///   labelText: 'Descrição',
///   minLines: 3,
///   maxLines: 8,
///   maxLength: 500,
///   showCounter: true,
/// )
/// ```
///
/// ### 3. GenericNumberField
/// Campo numérico com validação de range e formatação.
///
/// **Quando usar:**
/// - Quantidades
/// - Preços
/// - Valores numéricos em geral
///
/// **Exemplo:**
/// ```dart
/// GenericNumberField(
///   controller: _priceController,
///   labelText: 'Preço',
///   allowDecimals: true,
///   prefixText: 'R\$ ',
///   min: 0,
/// )
/// ```
///
/// ### 4. GenericEmailField
/// Campo de email com validação integrada.
///
/// **Quando usar:**
/// - Campos de email
///
/// **Exemplo:**
/// ```dart
/// GenericEmailField(
///   controller: _emailController,
///   labelText: 'Email *',
///   required: true,
/// )
/// ```
///
/// ### 5. GenericPhoneField
/// Campo de telefone com máscara brasileira.
///
/// **Quando usar:**
/// - Campos de telefone
///
/// **Exemplo:**
/// ```dart
/// GenericPhoneField(
///   controller: _phoneController,
///   labelText: 'Telefone',
///   hintText: '(00) 00000-0000',
/// )
/// ```
///
/// ### 6. GenericCheckbox
/// Checkbox com label e validação.
///
/// **Quando usar:**
/// - Campos de seleção booleana
/// - Aceite de termos
/// - Ativação/desativação de opções
/// - Seleção múltipla com tristate
///
/// **Exemplo:**
/// ```dart
/// GenericCheckbox(
///   value: _isActive,
///   onChanged: (value) => setState(() => _isActive = value),
///   label: 'Ativo',
/// )
/// ```
///
/// ## 🎨 Design Consistente
///
/// Todos os componentes seguem o tema global definido em `app_theme.dart`:
/// - BorderRadius: 10
/// - Filled: true
/// - FillColor: surfaceContainerHighest
/// - FocusedBorder: primary color com width 2
///
/// ## 📝 Boas Práticas
///
/// 1. **Use o componente mais específico:**
///    - Email → GenericEmailField
///    - Telefone → GenericPhoneField
///    - Número → GenericNumberField
///    - Texto longo → GenericTextArea
///    - Texto simples → GenericTextField
///
/// 2. **Sempre use controller ou initialValue, nunca ambos**
///
/// 3. **Marque campos obrigatórios com * no labelText:**
///    ```dart
///    labelText: 'Nome *'
///    ```
///
/// 4. **Use validator para validações customizadas:**
///    ```dart
///    validator: (value) {
///      if (value?.isEmpty ?? true) return 'Campo obrigatório';
///      if (value!.length < 3) return 'Mínimo 3 caracteres';
///      return null;
///    }
///    ```
///
/// 5. **Desabilite campos durante salvamento:**
///    ```dart
///    enabled: !_saving
///    ```
library;

export 'generic_text_field.dart';
export 'generic_text_area.dart';
export 'generic_number_field.dart';
export 'generic_email_field.dart';
export 'generic_phone_field.dart';
export 'generic_checkbox.dart';

