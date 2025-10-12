/// Componentes de botão genéricos reutilizáveis
///
/// Este módulo fornece componentes de botão consistentes e type-safe
/// para uso em todo o projeto.
///
/// ## 📦 Componentes Disponíveis
///
/// ### 1. PrimaryButton
/// Botão principal para ações primárias (salvar, criar, confirmar).
///
/// **Quando usar:**
/// - Ação principal do formulário
/// - Confirmação de ações importantes
/// - Criação de novos itens
///
/// **Exemplo:**
/// ```dart
/// PrimaryButton(
///   onPressed: _save,
///   label: 'Salvar',
///   icon: Icons.save,
///   isLoading: _saving,
/// )
/// ```
///
/// ### 2. SecondaryButton
/// Botão secundário para ações secundárias (cancelar, voltar).
///
/// **Quando usar:**
/// - Ação secundária do formulário
/// - Cancelamento de ações
/// - Navegação de volta
///
/// **Exemplo:**
/// ```dart
/// SecondaryButton(
///   onPressed: () => Navigator.pop(context),
///   label: 'Cancelar',
/// )
/// ```
///
/// ### 3. TextOnlyButton
/// Botão de texto para ações terciárias (ver detalhes, expandir).
///
/// **Quando usar:**
/// - Ações menos importantes
/// - Links de navegação
/// - Ações de visualização
///
/// **Exemplo:**
/// ```dart
/// TextOnlyButton(
///   onPressed: _viewDetails,
///   label: 'Ver Detalhes',
///   icon: Icons.arrow_forward,
/// )
/// ```
///
/// ### 4. DangerButton
/// Botão de ação destrutiva (excluir, remover permanentemente).
///
/// **Quando usar:**
/// - Exclusão de itens
/// - Ações irreversíveis
/// - Cancelamento permanente
///
/// **Exemplo:**
/// ```dart
/// DangerButton(
///   onPressed: _delete,
///   label: 'Excluir',
///   icon: Icons.delete,
///   outlined: false, // filled (padrão) ou outlined
/// )
/// ```
///
/// ### 5. IconTextButton
/// Botão tonal com ícone e texto (ações secundárias com destaque).
///
/// **Quando usar:**
/// - Adicionar itens
/// - Ações secundárias com ícone
/// - Botões de toolbar
///
/// **Exemplo:**
/// ```dart
/// IconTextButton(
///   onPressed: _addItem,
///   icon: Icons.add,
///   label: 'Adicionar Item',
/// )
/// ```
///
/// ### 6. OutlineButton
/// Botão com outline customizado (background escuro e borda).
///
/// **Quando usar:**
/// - Ações em lote (excluir selecionados, mover selecionados, etc.)
/// - Indicador de itens selecionados
/// - Ações de seleção múltipla
///
/// **Exemplo:**
/// ```dart
/// OutlineButton(
///   onPressed: _deleteSelected,
///   label: '$selectedCount selecionado${selectedCount > 1 ? 's' : ''}',
///   icon: Icons.delete,
/// )
/// ```
///
/// ### 7. IconOnlyButton
/// Botão apenas com ícone (sem texto).
///
/// **Quando usar:**
/// - Ações rápidas em toolbars
/// - Botões de edição/exclusão em tabelas
/// - Ícones de ação em cards
/// - Botões de navegação
///
/// **Exemplo:**
/// ```dart
/// IconOnlyButton(
///   onPressed: _edit,
///   icon: Icons.edit,
///   tooltip: 'Editar',
/// )
/// ```
///
/// **Exemplo com variante:**
/// ```dart
/// IconOnlyButton(
///   onPressed: _delete,
///   icon: Icons.delete,
///   tooltip: 'Excluir',
///   variant: IconButtonVariant.filled,
/// )
/// ```
///
/// ## 🎨 Design Consistente
///
/// Todos os componentes seguem o tema global definido em `app_theme.dart`:
/// - BorderRadius: 8
/// - Padding: horizontal 16, vertical 12
/// - Cores do tema (primary, error, etc.)
/// - Loading state integrado
///
/// ## 📝 Boas Práticas
///
/// 1. **Use o componente mais específico:**
///    - Ação principal → PrimaryButton
///    - Ação secundária → SecondaryButton
///    - Ação terciária → TextOnlyButton
///    - Ação destrutiva → DangerButton
///    - Ação com ícone → IconTextButton
///
/// 2. **Use isLoading para estados de carregamento:**
///    ```dart
///    PrimaryButton(
///      onPressed: _saving ? null : _save,
///      label: 'Salvar',
///      isLoading: _saving,
///    )
///    ```
///
/// 3. **Desabilite botões durante operações:**
///    ```dart
///    onPressed: _saving ? null : _save
///    ```
///
/// 4. **Use ícones para clareza:**
///    ```dart
///    PrimaryButton(
///      onPressed: _create,
///      label: 'Criar Novo',
///      icon: Icons.add,
///    )
///    ```
///
/// 5. **Use DangerButton para ações destrutivas:**
///    ```dart
///    DangerButton(
///      onPressed: _delete,
///      label: 'Excluir',
///      icon: Icons.delete,
///    )
///    ```
///
/// ## 🎯 Hierarquia de Botões
///
/// Em um formulário típico:
///
/// ```dart
/// Row(
///   mainAxisAlignment: MainAxisAlignment.end,
///   children: [
///     TextOnlyButton(
///       onPressed: () => Navigator.pop(context),
///       label: 'Cancelar',
///     ),
///     const SizedBox(width: 8),
///     PrimaryButton(
///       onPressed: _save,
///       label: 'Salvar',
///       isLoading: _saving,
///     ),
///   ],
/// )
/// ```
///
/// Em um dialog de confirmação:
///
/// ```dart
/// Row(
///   mainAxisAlignment: MainAxisAlignment.end,
///   children: [
///     SecondaryButton(
///       onPressed: () => Navigator.pop(context),
///       label: 'Cancelar',
///     ),
///     const SizedBox(width: 8),
///     DangerButton(
///       onPressed: _delete,
///       label: 'Excluir',
///       icon: Icons.delete,
///     ),
///   ],
/// )
/// ```
library;

export 'primary_button.dart';
export 'secondary_button.dart';
export 'text_only_button.dart';
export 'danger_button.dart';
export 'icon_text_button.dart';
export 'outline_button.dart';
export 'icon_only_button.dart';

