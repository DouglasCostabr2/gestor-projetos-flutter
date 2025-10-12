# Padrões de Modais do Sistema

Este documento define os padrões visuais e de comportamento para todos os modais (diálogos) do sistema.

## Componentes Padrão

### 1. StandardDialog

Use `StandardDialog` para formulários e conteúdo complexo.

**Características:**
- Header fixo com título e botão X
- Conteúdo scrollável
- Rodapé fixo opcional com botões de ação
- Largura e altura configuráveis

**Exemplo de uso:**
```dart
showDialog(
  context: context,
  builder: (context) => StandardDialog(
    title: 'Novo Cliente',
    maxWidth: 600,
    maxHeight: 700,
    child: Form(
      child: Column(
        children: [
          // Campos do formulário
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _save,
        child: const Text('Salvar'),
      ),
    ],
  ),
);
```

### 2. ConfirmDialog

Use `ConfirmDialog` para confirmações simples.

**Características:**
- Título
- Mensagem
- Botões Cancelar e Confirmar
- Suporte para ações destrutivas (cor vermelha)

**Exemplo de uso:**
```dart
final confirm = await showDialog<bool>(
  context: context,
  builder: (context) => ConfirmDialog(
    title: 'Confirmar Exclusão',
    message: 'Deseja realmente excluir o cliente "João"?',
    confirmText: 'Excluir',
    isDestructive: true,
  ),
);

if (confirm == true) {
  // Executar ação
}
```

## Padrões Visuais

### Header
- **Cor de fundo**: `Theme.of(context).colorScheme.surfaceContainerHighest`
- **Padding**: `EdgeInsets.all(16)`
- **Borda inferior**: `Theme.of(context).colorScheme.outlineVariant`
- **Título**: `Theme.of(context).textTheme.titleLarge`
- **Botão fechar**: `IconButton` com ícone `Icons.close`

### Conteúdo
- **Padding padrão**: `EdgeInsets.all(24)`
- **Scrollável**: Sempre usar `SingleChildScrollView`

### Rodapé (Actions)
- **Cor de fundo**: `Theme.of(context).colorScheme.surface`
- **Padding**: `EdgeInsets.all(16)`
- **Borda superior**: `Theme.of(context).colorScheme.outlineVariant`
- **Alinhamento**: `MainAxisAlignment.end`
- **Espaçamento entre botões**: `8px`

### Botões
- **Cancelar**: `TextButton`
- **Confirmar/Salvar**: `FilledButton`
- **Ações destrutivas**: `FilledButton` com `backgroundColor: Theme.of(context).colorScheme.error`

## Dimensões Padrão

| Tipo de Modal | Largura Máxima | Altura Máxima |
|---------------|----------------|---------------|
| Formulário simples | 600px | 85% da tela |
| Formulário complexo | 720px | 88% da tela |
| Confirmação | 420px | auto |
| Seleção de lista | 560px | 80% da tela |

## Checklist de Migração

Para migrar modais existentes para o padrão:

- [ ] Substituir `AlertDialog` simples por `ConfirmDialog` (para confirmações)
- [ ] Substituir `Dialog` customizado por `StandardDialog` (para formulários)
- [ ] Verificar se o header tem:
  - [ ] Título com `titleLarge`
  - [ ] Botão X para fechar
  - [ ] Cor de fundo `surfaceContainerHighest`
  - [ ] Borda inferior
- [ ] Verificar se o conteúdo:
  - [ ] Está dentro de `SingleChildScrollView`
  - [ ] Tem padding de 24px
- [ ] Verificar se o rodapé (se existir):
  - [ ] Tem borda superior
  - [ ] Botões alinhados à direita
  - [ ] Espaçamento de 8px entre botões
- [ ] Verificar botões:
  - [ ] Cancelar = `TextButton`
  - [ ] Confirmar = `FilledButton`
  - [ ] Destrutivo = `FilledButton` com cor de erro

## Modais Migrados ✅

### Confirmações de Exclusão (ConfirmDialog)
1. ✅ `clients_page.dart` - Exclusão de cliente na tabela
2. ✅ `client_detail_page.dart` - Exclusão de cliente no header
3. ✅ `client_detail_page.dart` - Exclusão de empresa na tabela
4. ✅ `client_categories_page.dart` - Exclusão de categoria
5. ✅ `tasks_page.dart` - Exclusão de tarefa (com aviso sobre Google Drive)
6. ✅ `catalog_page.dart` - Exclusão de item do catálogo
7. ✅ `admin_page.dart` - Exclusão de usuário
8. ✅ `project_detail_page.dart` - Exclusão de tarefa
9. ✅ `subtasks_section.dart` - Exclusão de sub task
10. ✅ `task_assets_section.dart` - Remoção de asset

### Formulários (StandardDialog)
1. ✅ `client_categories_page.dart` - Formulário de categoria

## Modais a Migrar

### Alta Prioridade
1. `catalog_page.dart` - Formulários de categoria de produtos/pacotes (ainda usa AlertDialog)
2. `project_form_dialog.dart` - Formulário de projeto
3. `company_form_dialog.dart` - Formulário de empresa

### Média Prioridade
4. `project_members_dialog.dart` - Gerenciamento de membros
5. `quick_forms.dart` - Todos os formulários rápidos
6. `client_form.dart` - Formulário de cliente (já tem boa estrutura, precisa ajustes menores)

### Baixa Prioridade
7. `drive_connect_dialog.dart` - Conexão com Google Drive
8. `finance_page.dart` - Modal de valores pendentes

## Notas Importantes

1. **Sempre use os componentes padrão** (`StandardDialog` ou `ConfirmDialog`) ao invés de criar modais customizados
2. **Mantenha a consistência** - todos os modais devem ter a mesma aparência
3. **Teste a responsividade** - verifique se o modal funciona bem em diferentes tamanhos de tela
4. **Acessibilidade** - sempre forneça `tooltip` nos botões e labels descritivos

