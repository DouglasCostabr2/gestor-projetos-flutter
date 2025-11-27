# Arquitetura: Componente SelectableContainer

## Objetivo

Criar um container reutilizável e padronizado para habilitar a seleção de texto em áreas específicas da aplicação, garantindo consistência e facilitando a manutenção.

## Estrutura

### 1. Componente Base: `SelectableContainer`
**Localização**: `lib/ui/molecules/containers/selectable_container.dart`

**Responsabilidades**:
- Envolver o conteúdo em um `SelectionArea`
- Centralizar a configuração de seleção de texto
- Permitir fácil atualização do comportamento de seleção em toda a app

**Parâmetros**:
```dart
SelectableContainer(
  child: Widget,              // Obrigatório: O conteúdo a ser selecionável
  focusNode: FocusNode?,      // Opcional: Controle de foco
  selectionControls: ...,     // Opcional: Controles customizados
)
```

## Benefícios da Arquitetura

### 1. **Padronização**
- ✅ Garante que todas as áreas selecionáveis usem o mesmo mecanismo (`SelectionArea`)
- ✅ Evita inconsistências entre diferentes telas

### 2. **Manutenibilidade**
- ✅ Se o Flutter mudar a forma recomendada de seleção (ex: de `SelectableText` para `SelectionArea`), basta atualizar um arquivo
- ✅ Correções de bugs ou melhorias na seleção aplicam-se globalmente

### 3. **Simplicidade**
- ✅ Desenvolvedores não precisam lembrar de configurar `SelectionArea` manualmente
- ✅ Abstrai a complexidade do widget nativo

## Onde Usar

### Uso Atual
1. **`TaskBriefingSection`** - Briefing da tarefa
2. **`CommentsSection`** - Lista de comentários
3. **`TaskDetailPage`** - Detalhes da tarefa

### Quando Usar
- Sempre que houver blocos de texto read-only que o usuário possa querer copiar
- Em descrições, comentários, logs, e detalhes de itens

## Exemplo de Uso

```dart
// Antes (Uso direto)
SelectionArea(
  child: Column(
    children: [
      Text('Texto 1'),
      Text('Texto 2'),
    ],
  ),
)

// Depois (Componente Reutilizável)
SelectableContainer(
  child: Column(
    children: [
      Text('Texto 1'),
      Text('Texto 2'),
    ],
  ),
)
```

## Princípios Seguidos

1. **DRY (Don't Repeat Yourself)**: Centraliza a lógica de seleção.
2. **Encapsulamento**: Esconde detalhes de implementação do Flutter.
3. **Design System**: Integra-se à biblioteca de componentes do projeto (`molecules/containers`).
