# 📢 Sistema de Menções (@mentions)

## 🎯 Visão Geral

O sistema de menções permite que usuários mencionem outros usuários em comentários, tarefas e projetos usando a sintaxe `@NomeDoUsuário`. As menções são armazenadas no banco de dados e podem ser usadas para notificações futuras.

## ✨ Características

- ✅ **Autocomplete inteligente**: Ao digitar `@`, aparece um dropdown com lista de usuários
- ✅ **Busca em tempo real**: Filtra usuários conforme você digita
- ✅ **Destaque visual**: Menções são destacadas com cor diferente (branco, negrito)
- ✅ **Hover card**: Ao passar o mouse sobre uma menção, exibe card com avatar, nome e cargo do usuário
- ✅ **Formato oculto**: Durante a edição, exibe apenas `@Nome` mas armazena `@[Nome](id)` internamente
- ✅ **Proteção de estrutura**: Impede que o usuário edite acidentalmente o ID da menção
- ✅ **Foco automático**: Após selecionar uma menção, o foco retorna automaticamente ao campo
- ✅ **Armazenamento estruturado**: Menções são salvas no banco de dados com IDs únicos
- ✅ **Suporte universal**: Funciona em comentários, tarefas e projetos
- ✅ **Integração com editor**: Funciona automaticamente no GenericBlockEditor

## 📦 Componentes

### 1. **MentionTextField**
Campo de texto com suporte a menções.

```dart
import 'package:gestor_projetos_flutter/ui/molecules/inputs/mention_text_field.dart';

MentionTextField(
  controller: _controller,
  decoration: InputDecoration(
    hintText: 'Digite @ para mencionar alguém...',
  ),
  onMentionsChanged: (userIds) {
    print('Usuários mencionados: $userIds');
  },
)
```

### 2. **MentionText**
Widget para exibir texto com menções destacadas.

```dart
import 'package:gestor_projetos_flutter/ui/molecules/text/mention_text.dart';

MentionText(
  text: 'Olá @[João Silva](user-123), tudo bem?',
  style: TextStyle(fontSize: 14),
  onMentionTap: (userId, userName) {
    print('Clicou em: $userName ($userId)');
  },
)
```

### 3. **MentionsService**
Serviço para gerenciar menções no banco de dados.

```dart
import 'package:gestor_projetos_flutter/services/mentions_service.dart';

// Salvar menções de um comentário
await mentionsService.saveCommentMentions(
  commentId: 'comment-123',
  content: 'Olá @[João Silva](user-123)!',
);

// Buscar menções de um comentário
final mentions = await mentionsService.getCommentMentions('comment-123');

// Buscar comentários onde o usuário foi mencionado
final userMentions = await mentionsService.getCommentMentionsForUser('user-123');
```

## 🗄️ Estrutura do Banco de Dados

### Tabelas

#### `comment_mentions`
Armazena menções em comentários.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID | ID único da menção |
| `comment_id` | UUID | ID do comentário |
| `mentioned_user_id` | UUID | ID do usuário mencionado |
| `mentioned_by_user_id` | UUID | ID do usuário que mencionou |
| `created_at` | TIMESTAMPTZ | Data de criação |

#### `task_mentions`
Armazena menções em tarefas.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID | ID único da menção |
| `task_id` | UUID | ID da tarefa |
| `mentioned_user_id` | UUID | ID do usuário mencionado |
| `mentioned_by_user_id` | UUID | ID do usuário que mencionou |
| `field_name` | VARCHAR(50) | Campo onde foi mencionado ('title', 'description', 'briefing') |
| `created_at` | TIMESTAMPTZ | Data de criação |

#### `project_mentions`
Armazena menções em projetos.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `id` | UUID | ID único da menção |
| `project_id` | UUID | ID do projeto |
| `mentioned_user_id` | UUID | ID do usuário mencionado |
| `mentioned_by_user_id` | UUID | ID do usuário que mencionou |
| `field_name` | VARCHAR(50) | Campo onde foi mencionado ('title', 'description') |
| `created_at` | TIMESTAMPTZ | Data de criação |

### Políticas RLS

Todas as tabelas têm políticas RLS configuradas:

- ✅ Usuários podem ver menções em conteúdo que têm acesso
- ✅ Usuários podem ver menções onde foram mencionados
- ✅ Usuários podem criar menções em conteúdo que têm acesso
- ✅ Usuários podem deletar menções que criaram

## 💻 Formato de Armazenamento

As menções são armazenadas no formato:

```
@[Nome do Usuário](user_id)
```

**Exemplo:**
```
Olá @[João Silva](550e8400-e29b-41d4-a716-446655440000), tudo bem?
```

### Durante a Edição (TextField)
O usuário vê apenas:
```
Olá @João Silva, tudo bem?
```

Mas o texto armazenado internamente é:
```
Olá @[João Silva](550e8400-e29b-41d4-a716-446655440000), tudo bem?
```

Isso é feito através do `MentionTextEditingController` que sobrescreve o método `buildTextSpan()` para formatar a exibição.

### Durante a Visualização (MentionText)
O texto é exibido como:
```
Olá @João Silva, tudo bem?
```

Com as seguintes características:
- **Destaque visual**: `@João Silva` aparece em branco e negrito
- **Hover card**: Ao passar o mouse, exibe card com avatar, nome e cargo
- **Clicável**: Opcionalmente pode executar ação ao clicar (ex: abrir perfil)

## 🔧 Integração com GenericBlockEditor

O `GenericBlockEditor` já tem suporte automático a menções:

```dart
GenericBlockEditor(
  initialJson: _json,
  enabled: true,
  showToolbar: true,
  onChanged: (json) {
    setState(() => _json = json);
  },
)
```

**Recursos:**
- ✅ Autocomplete ao digitar `@`
- ✅ Destaque visual de menções
- ✅ Funciona em todos os blocos de texto
- ✅ Compatível com imagens, checkboxes e tabelas

## 📝 Uso em Comentários

O sistema de comentários (`CommentsSection`) já está integrado:

```dart
CommentsSection(
  task: taskData,
  pageScrollController: _scrollController,
)
```

**Funcionalidades:**
- ✅ Autocomplete de usuários ao digitar `@`
- ✅ Menções são salvas automaticamente no banco
- ✅ Menções são destacadas visualmente
- ✅ Suporte a clique em menções (futuro)

## 🔧 Componentes Técnicos

### MentionTextEditingController
Controller customizado que formata menções durante a edição.

**Funcionalidades:**
- Sobrescreve `buildTextSpan()` para exibir `@Nome` ao invés de `@[Nome](id)`
- Mantém o texto completo com IDs no `controller.text`
- Aplica formatação visual (branco, negrito) às menções

### MentionProtectionFormatter
`TextInputFormatter` que protege a estrutura das menções.

**Funcionalidades:**
- Detecta quando o usuário tenta editar dentro de `@[Nome](id)`
- Redireciona o texto digitado para depois da menção
- Previne corrupção do formato de armazenamento

### MentionHoverCard
Widget que exibe informações do usuário ao passar o mouse sobre uma menção.

**Funcionalidades:**
- Carrega dados do usuário do Supabase em tempo real
- Exibe avatar (48x48, circular)
- Mostra nome completo e cargo
- Design dark theme (280px width, elevation 8)
- Posicionamento dinâmico próximo à menção

### MentionOverlay
Gerencia o overlay de autocomplete de usuários.

**Funcionalidades:**
- Detecta quando o usuário digita `@`
- Carrega lista de usuários do Supabase
- Filtra usuários conforme a query
- Posiciona o dropdown próximo ao cursor
- Insere a menção formatada ao selecionar

## 🚀 Próximos Passos

### Implementações Futuras

1. **Notificações**
   - Notificar usuários quando são mencionados
   - Badge de notificações não lidas
   - Centro de notificações

2. **Expansão para Outros Campos** 🎯
   - ⬜ Títulos de tarefas (TasksPage)
   - ⬜ Descrições de tarefas
   - ✅ Briefing editor (já implementado via GenericBlockEditor)
   - ⬜ Títulos e descrições de projetos

3. **Melhorias de UX**
   - ✅ Hover para preview do perfil (implementado)
   - ⬜ Clique em menção para ver perfil completo do usuário
   - ⬜ Histórico de menções
   - ⬜ Filtro de tarefas/comentários por menções

4. **Performance** 🎯
   - ⬜ Cache de usuários (evitar múltiplas requisições)
   - ⬜ Debounce na busca (aguardar 300ms antes de buscar)
   - ⬜ Paginação de resultados (carregar 20 usuários por vez)
   - ⬜ Lazy loading do hover card (carregar dados apenas ao hover)

## 🎨 Personalização

### Estilo das Menções

Você pode personalizar o estilo das menções:

```dart
MentionText(
  text: 'Olá @[João Silva](user-123)!',
  style: TextStyle(fontSize: 14, color: Colors.white),
  mentionStyle: TextStyle(
    fontSize: 14,
    color: Colors.blue,
    fontWeight: FontWeight.bold,
  ),
)
```

### Cores do Tema

As menções usam a cor primária do tema por padrão:

```dart
mentionStyle: TextStyle(
  color: Theme.of(context).colorScheme.primary, // Branco no tema dark
  fontWeight: FontWeight.w600,
)
```

## 🔍 Exemplos de Uso

### Exemplo 1: Campo de Comentário Simples

```dart
class CommentForm extends StatefulWidget {
  @override
  State<CommentForm> createState() => _CommentFormState();
}

class _CommentFormState extends State<CommentForm> {
  final _controller = TextEditingController();
  List<String> _mentionedUsers = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MentionTextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Escreva um comentário...',
          ),
          onMentionsChanged: (userIds) {
            setState(() => _mentionedUsers = userIds);
          },
        ),
        if (_mentionedUsers.isNotEmpty)
          Text('Mencionando ${_mentionedUsers.length} usuário(s)'),
      ],
    );
  }
}
```

### Exemplo 2: Exibir Comentário com Menções

```dart
class CommentCard extends StatelessWidget {
  final String content;

  const CommentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: MentionText(
          text: content,
          onMentionTap: (userId, userName) {
            // Navegar para perfil do usuário
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfilePage(userId: userId),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

### Exemplo 3: Salvar Menções de Tarefa

```dart
Future<void> saveTask() async {
  final taskId = await createTask(
    title: _titleController.text,
    description: _descriptionController.text,
  );

  // Salvar menções do título
  await mentionsService.saveTaskMentions(
    taskId: taskId,
    fieldName: 'title',
    content: _titleController.text,
  );

  // Salvar menções da descrição
  await mentionsService.saveTaskMentions(
    taskId: taskId,
    fieldName: 'description',
    content: _descriptionController.text,
  );
}
```

## 📚 Referências

- [Supabase RLS Policies](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter TextField](https://api.flutter.dev/flutter/material/TextField-class.html)
- [Flutter Overlay](https://api.flutter.dev/flutter/widgets/Overlay-class.html)

