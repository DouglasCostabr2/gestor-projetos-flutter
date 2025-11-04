# Problema: Cursor Aparecendo Atrás das Imagens no QuillEditor

## 📋 Descrição do Problema

Quando o usuário digita texto próximo de uma imagem no QuillEditor (sistema de comentários), o cursor de texto aparece **atrás da imagem** em vez de aparecer na frente.

- ✅ O texto é digitado corretamente
- ✅ A posição do cursor está correta logicamente
- ❌ Visualmente, o cursor aparece atrás da imagem

## 🔍 Investigação Realizada

### Tentativas de Solução (Todas Falharam)

1. **`paintCursorAboveText: true` no QuillEditorConfig**
   - Resultado: Não resolveu o problema

2. **Theme com `textSelectionTheme` customizado**
   - Tentativa: Sobrescrever cores e propriedades do cursor
   - Resultado: Cursor mudou de cor mas ainda aparece atrás

3. **`RepaintBoundary` com `ValueKey` única**
   - Tentativa: Isolar renderização da imagem
   - Resultado: Imagem ainda é reconstruída múltiplas vezes

4. **Remover `ClipRRect` e usar `Container` com `clipBehavior`**
   - Tentativa: Evitar camadas de composição extras
   - Resultado: Problema persiste

5. **`IgnorePointer` na imagem**
   - Tentativa: Fazer imagem não capturar eventos
   - Resultado: Não afeta renderização do cursor

6. **`Stack.clipBehavior: Clip.none`**
   - Tentativa: Permitir cursor overflow
   - Resultado: Não resolve o problema de z-index

7. **`DecoratedBox` em vez de `Container`**
   - Tentativa: Widget mais leve sem camadas extras
   - Resultado: Problema persiste

### Descobertas dos Logs de Debug

Ao adicionar logs detalhados, descobrimos que:

```
🖼️ [IMAGE BUILD] Renderizando imagem: ...
   📐 Dimensões: screenW=1536.0, maxBubbleW=400.0
   ✅ Retornando widget de imagem
```

**A imagem é reconstruída MÚLTIPLAS VEZES a cada interação do usuário**, mesmo com `RepaintBoundary` e `ValueKey`.

Isso indica que o `flutter_quill` está forçando o rebuild do `EmbedBuilder` a cada frame, criando novas camadas de renderização que sobrepõem o cursor.

## 🎯 Causa Raiz

**Limitação Fundamental do flutter_quill (versão 11.4.2)**

O problema ocorre porque:

1. O `QuillEditor` renderiza o cursor usando um `CustomPainter` no `EditableText`
2. Os `BlockEmbed` (imagens) são renderizados como widgets separados na árvore
3. O Flutter renderiza widgets na ordem da árvore, e os embeds são renderizados **depois** do cursor
4. O `flutter_quill` reconstrói os `EmbedBuilder` a cada mudança de seleção/cursor
5. Cada rebuild cria uma nova camada de composição que sobrepõe o cursor

## 💡 Soluções Possíveis

### Opção 1: Atualizar flutter_quill (Recomendado)

Verificar se versões mais recentes do `flutter_quill` corrigiram este problema:

```yaml
dependencies:
  flutter_quill: ^12.0.0  # ou versão mais recente
```

**Atenção**: Pode haver breaking changes que exigem refatoração.

### Opção 2: Aceitar a Limitação

Documentar para os usuários que:
- O cursor pode aparecer atrás das imagens ao digitar próximo delas
- Isso é uma limitação visual que não afeta a funcionalidade
- O texto é digitado corretamente mesmo quando o cursor não é visível

### Opção 3: Usar Editor Alternativo

Considerar migrar para outro editor de rich text:

- **quill_html_editor**: Baseado em WebView, pode ter melhor controle de z-index
- **html_editor_enhanced**: Editor HTML com melhor suporte a embeds
- **super_editor**: Editor nativo do Flutter com melhor controle de renderização

### Opção 4: Implementar Cursor Customizado (Complexo)

Criar um cursor customizado usando `Overlay` que renderiza acima de todos os widgets:

```dart
// Pseudocódigo - implementação complexa
class CustomCursorOverlay extends StatefulWidget {
  // Rastrear posição do cursor
  // Renderizar cursor usando Overlay
  // Sincronizar com QuillEditor
}
```

**Desvantagens**:
- Implementação muito complexa
- Pode ter problemas de sincronização
- Difícil manutenção

## 📝 Código Atual

### ChatImageEmbedBuilder (lib/ui/organisms/editors/chat_briefing.dart)

```dart
// NOTA: O cursor aparecendo atrás das imagens é uma limitação conhecida do flutter_quill
// onde BlockEmbeds são renderizados em uma camada que sempre sobrepõe o cursor.
// Tentativas de solução (todas falharam):
// - paintCursorAboveText: true
// - Theme com textSelectionTheme customizado  
// - RepaintBoundary com ValueKey
// - Remover ClipRRect e usar Container
// - IgnorePointer na imagem
// O problema persiste porque o flutter_quill reconstrói o EmbedBuilder a cada frame.
```

### QuillEditorConfig (lib/ui/organisms/sections/comments_section.dart)

```dart
Theme(
  data: Theme.of(context).copyWith(
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Theme.of(context).colorScheme.primary,
      selectionColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      selectionHandleColor: Theme.of(context).colorScheme.primary,
    ),
  ),
  child: quill.QuillEditor(
    // ... configuração
    config: quill.QuillEditorConfig(
      paintCursorAboveText: true,  // Não resolve o problema
      // ...
    ),
  ),
)
```

## 🔗 Referências

- [flutter_quill GitHub Issues](https://github.com/singerdmx/flutter-quill/issues)
- [Flutter Rendering Pipeline](https://docs.flutter.dev/resources/architectural-overview#rendering-and-layout)
- [CustomPainter and Layers](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)

## ✅ Recomendação Final

**Aceitar a limitação temporariamente** e:

1. Documentar o comportamento para os usuários
2. Monitorar atualizações do `flutter_quill`
3. Considerar migração para versão mais recente quando estável
4. Se o problema persistir em versões futuras, considerar editor alternativo

O impacto na UX é mínimo pois:
- O texto é digitado corretamente
- O cursor reaparece quando não está próximo de imagens
- Usuários podem clicar para reposicionar o cursor se necessário

