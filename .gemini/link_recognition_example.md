# Reconhecimento de Links - Exemplo de Uso

## Funcionalidade Implementada

O widget `MentionText` agora detecta automaticamente URLs no texto e as renderiza como links clicáveis.

## Como Funciona

### 1. Detecção Automática de URLs
O sistema detecta automaticamente URLs que começam com `http://` ou `https://`:

```dart
// Exemplo de texto com URLs
final texto = """
Confira nosso site: https://exemplo.com
Documentação: https://docs.exemplo.com/guia
API: http://api.exemplo.com/v1
""";
```

### 2. Renderização de Links
URLs detectadas são renderizadas como **badges sutis** com:
- **Ícone de link** (🔗) do lado esquerdo
- **Fundo escuro** (#2A2A2A) com borda (#3A3A3A)
- **Cor do texto branca** (mesma cor do texto normal)
- **Bordas arredondadas** (4px)
- **Padding interno** para destaque visual
- **Cursor de ponteiro** ao passar o mouse
- **Clique** para abrir no navegador externo
- **Sem sublinhado** - design limpo e moderno

### 3. Exemplo de Uso no Código

```dart
MentionText(
  text: 'Visite nosso site https://exemplo.com para mais informações',
  style: TextStyle(fontSize: 14, color: Colors.white),
)
```

### 4. Compatibilidade com Menções
O sistema funciona em conjunto com menções de usuários:

```dart
final texto = """
Olá @[João Silva](user-123), 
confira o link: https://exemplo.com/projeto
e me avise o que achou!
""";
```

Neste exemplo:
- `@João Silva` será renderizado como uma menção (azul, com hover card)
- `https://exemplo.com/projeto` será renderizado como um badge clicável (fundo escuro, texto branco)

### Exemplo Visual:

```
Antes: Confira o link https://exemplo.com para mais detalhes
                        ^^^^^^^^^^^^^^^^^^^^
                        (azul, sublinhado)

Depois: Confira o link [🔗 https://exemplo.com] para mais detalhes
                       ^^^^^^^^^^^^^^^^^^^^^^^
                       (badge com ícone, fundo escuro, texto branco)
```
## Onde é Usado

Esta funcionalidade está disponível em:

1. **Seção de Briefing** (task_detail_page.dart)
   - Textos de briefing podem conter links clicáveis

2. **Comentários** (comments_section.dart)
   - Comentários podem incluir links para recursos externos

3. **Descrições de Projetos** (project_form_dialog.dart)
   - Descrições podem referenciar links externos

4. **Qualquer lugar que use `MentionText`**
   - O widget é reutilizável em todo o projeto

## Comportamento

### Ao Clicar em um Link:
1. O sistema tenta abrir a URL no navegador externo padrão
2. Se houver erro, falha silenciosamente (não mostra erro ao usuário)
3. O link abre em uma nova janela/aba do navegador

### Tipos de URLs Suportadas:
- ✅ `https://exemplo.com`
- ✅ `http://exemplo.com`
- ✅ `https://www.exemplo.com/caminho/para/recurso`
- ✅ `https://exemplo.com/caminho?param=valor&outro=123`
- ✅ `https://exemplo.com:8080/api`
- ❌ `exemplo.com` (sem protocolo)
- ❌ `www.exemplo.com` (sem protocolo)

## Regex Utilizada

```dart
final urlRegex = RegExp(
  r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  caseSensitive: false,
);
```

Esta regex detecta:
- Protocolo obrigatório: `http://` ou `https://`
- Domínio válido
- Caminho, query strings e fragmentos opcionais

## Prioridade de Detecção

O sistema processa o texto na seguinte ordem:

1. **Menções com ID**: `@[Nome](uuid)` - maior prioridade
2. **Menções simples**: `@Nome`
3. **URLs**: `https://...`
4. **Texto normal**: tudo que não for menção ou URL

Isso garante que URLs dentro de menções não sejam detectadas separadamente.

## Exemplo Completo

```dart
final texto = """
Olá @[Maria Santos](user-456),

Segue o link do projeto: https://github.com/empresa/projeto

Documentação disponível em:
- API: https://api.exemplo.com/docs
- Guia: https://exemplo.com/guia/inicio

Qualquer dúvida, me avise!
""";

MentionText(
  text: texto,
  style: TextStyle(fontSize: 14, color: Colors.white),
  onMentionTap: (userId, userName) {
    print('Clicou em: $userName');
  },
)
```

Resultado:
- `@Maria Santos` → menção clicável (azul, hover card)
- `https://github.com/empresa/projeto` → badge clicável (fundo escuro, texto branco)
- `https://api.exemplo.com/docs` → badge clicável
- `https://exemplo.com/guia/inicio` → badge clicável
- Texto normal → renderizado normalmente

## Seleção de Texto

Como o `MentionText` está dentro de um `SelectionArea`, os usuários podem:
- ✅ Selecionar texto normal
- ✅ Selecionar menções
- ✅ Copiar texto selecionado
- ✅ Selecionar múltiplos elementos de uma vez
- ❌ **Links não são selecionáveis** - isso garante que clicar no link sempre abre a URL, sem interferência da seleção de texto
