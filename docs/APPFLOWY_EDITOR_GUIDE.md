# 📝 Guia do AppFlowy Editor

## 🎯 Visão Geral

O projeto agora usa o **AppFlowy Editor**, um editor de rich text moderno e poderoso, similar ao Asana e Notion, com suporte completo a drag and drop, formatação de texto, checklists, listas, e muito mais.

## ✨ Recursos Disponíveis

### 📋 Formatação de Texto

| Recurso | Atalho | Botão | Descrição |
|---------|--------|-------|-----------|
| **Negrito** | `Ctrl+B` | **B** | Deixa o texto em negrito |
| **Itálico** | `Ctrl+I` | *I* | Deixa o texto em itálico |
| **Sublinhado** | `Ctrl+U` | U | Sublinha o texto |
| **Tachado** | `Ctrl+Shift+S` | ~~S~~ | Risca o texto |

### 📝 Blocos de Conteúdo

Clique no botão **➕** para adicionar:

- **Checklist** - Lista de tarefas com checkboxes interativos
- **Lista com Marcadores** - Bullet points
- **Lista Numerada** - Lista ordenada (1, 2, 3...)
- **Citação** - Bloco de citação
- **Quebra de Seção** - Linha horizontal divisória

### 📐 Cabeçalhos

Clique no botão **📝** para adicionar:

- **Cabeçalho 1** - Título grande
- **Cabeçalho 2** - Título médio
- **Cabeçalho 3** - Título pequeno

### 🎨 Drag and Drop

**Como usar:**

1. **Digite algum conteúdo** no editor (pelo menos 2-3 linhas)
2. **Passe o mouse sobre a linha** que você quer mover
   - O handle (`⋮⋮`) aparece **SOMENTE ao passar o mouse** no **lado ESQUERDO**
3. **Clique e segure** no handle (ícone de 6 pontos)
4. **Arraste** para cima ou para baixo
5. **Solte** na nova posição

**⚠️ IMPORTANTE:** O handle SÓ aparece quando você passa o mouse sobre a linha!

**Recursos:**
- **Auto-scroll** automático ao arrastar para o topo/fundo
- Funciona com todos os tipos de blocos (parágrafos, listas, checklists, etc.)
- Linha azul mostra onde o bloco será solto

## 🗄️ Estrutura de Dados

### Banco de Dados

A tabela `projects` agora tem duas colunas para descrição:

```sql
description       TEXT    -- Texto plano (para busca e compatibilidade)
description_json  TEXT    -- JSON do rich text (formatação completa)
```

### Migração

Execute o script SQL para adicionar a nova coluna:

```bash
# No Supabase SQL Editor, execute:
database/migrations/add_description_json_to_projects.sql
```

Ou manualmente:

```sql
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS description_json TEXT;
```

## 💻 Uso no Código

### Widget Básico

```dart
AppFlowyTextFieldWithToolbar(
  hintText: 'Digite aqui...',
  enabled: true,
  onChanged: (text) {
    // Texto plano
    print('Texto: $text');
  },
  onJsonChanged: (json) {
    // JSON do rich text
    print('JSON: $json');
  },
)
```

### Carregar de Texto Plano

```dart
AppFlowyTextFieldWithToolbar(
  initialText: 'Texto inicial simples',
  onChanged: (text) => setState(() => _text = text),
)
```

### Carregar de JSON (Rich Text)

```dart
AppFlowyTextFieldWithToolbar(
  initialJson: _savedJson, // JSON do banco de dados
  onJsonChanged: (json) => setState(() => _json = json),
)
```

### Salvar no Banco de Dados

```dart
// No método de salvamento
final payload = {
  'description': _descriptionText,      // Texto plano
  'description_json': _descriptionJson, // Rich text JSON
};

await supabase.from('projects').insert(payload);
```

## 🎨 Customização

### Tema

O editor já está configurado com:
- **Texto branco** para combinar com o tema dark
- **Cor de seleção** usando a cor primária do tema
- **Cursor** na cor primária do tema
- **Toolbar** com fundo semi-transparente

### Adicionar Mais Botões

Edite `lib/widgets/appflowy_text_field_with_toolbar.dart`:

```dart
// Adicionar novo botão na toolbar
_buildToolbarButton(
  icon: Icons.format_color_text,
  tooltip: 'Cor do Texto',
  onPressed: _changeTextColor,
  theme: theme,
),
```

## 🔧 Métodos Úteis

### Converter para JSON

```dart
final json = widget.toJson(); // Retorna String JSON
```

### Obter Texto Plano

```dart
// Automático via callback onChanged
onChanged: (plainText) {
  print(plainText); // Texto sem formatação
}
```

## 📚 Exemplos

### Exemplo 1: Editor Simples

```dart
class MyForm extends StatefulWidget {
  @override
  State<MyForm> createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  String _text = '';
  String _json = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AppFlowyTextFieldWithToolbar(
            hintText: 'Digite aqui...',
            onChanged: (text) => setState(() => _text = text),
            onJsonChanged: (json) => setState(() => _json = json),
          ),
        ),
        ElevatedButton(
          onPressed: () => _save(),
          child: Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    await supabase.from('my_table').insert({
      'content': _text,
      'content_json': _json,
    });
  }
}
```

### Exemplo 2: Carregar Dados Existentes

```dart
class EditForm extends StatefulWidget {
  final Map<String, dynamic> data;
  
  const EditForm({required this.data});

  @override
  State<EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<EditForm> {
  late String _json;

  @override
  void initState() {
    super.initState();
    _json = widget.data['content_json'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AppFlowyTextFieldWithToolbar(
      initialJson: _json,
      onJsonChanged: (json) => setState(() => _json = json),
    );
  }
}
```

## 🐛 Troubleshooting

### Problema: Texto não aparece branco

**Solução**: Verifique se o tema está configurado corretamente. O editor usa `Colors.white` hardcoded.

### Problema: JSON não está salvando

**Solução**: Verifique se:
1. A coluna `description_json` existe no banco
2. O callback `onJsonChanged` está configurado
3. A variável está sendo atualizada no `setState`

### Problema: Drag and drop não funciona

**Solução**: O drag and drop é nativo do AppFlowy Editor e deve funcionar automaticamente. Certifique-se de que o editor está habilitado (`enabled: true`).

## 📖 Documentação Oficial

- [AppFlowy Editor GitHub](https://github.com/AppFlowy-IO/appflowy-editor)
- [AppFlowy Editor Pub.dev](https://pub.dev/packages/appflowy_editor)
- [Documentação AppFlowy](https://docs.appflowy.io/)

## 🎯 Próximos Passos

Recursos que podem ser adicionados:

- [ ] Inserção de imagens
- [ ] Tabelas
- [ ] Cores de texto e fundo
- [ ] Links
- [ ] Menções (@usuário)
- [ ] Emojis
- [ ] Exportar para Markdown/PDF
- [ ] Histórico de versões (undo/redo)

## 📝 Notas

- O editor salva automaticamente em JSON para preservar toda a formatação
- O texto plano é mantido para compatibilidade e busca
- Todos os atalhos de teclado são padrão do AppFlowy Editor
- O drag and drop funciona em todos os blocos de conteúdo

