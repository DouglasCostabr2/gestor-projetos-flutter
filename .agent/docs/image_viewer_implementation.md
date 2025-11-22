# Visualizador de Imagens com Zoom e Pan

## Descrição

Implementação de um visualizador de imagens com funcionalidades de zoom in/out e pan (arrastar) para o aplicativo de gestão de projetos.

## Funcionalidades

- **Qualidade Original**: As imagens são exibidas na resolução e qualidade originais, sem redimensionamento
- **Zoom In/Out**: Use gestos de pinça (pinch) ou scroll do mouse para dar zoom (até 4x)
- **Pan (Arrastar)**: Clique e arraste para mover a imagem
- **Duplo Toque**: Dê um duplo toque para dar zoom rápido
- **Tela Cheia**: As imagens abrem em tela cheia com fundo preto
- **Botão de Download**: Botão flutuante no canto superior direito para baixar a imagem
- **Botão de Fechar**: Botão flutuante no canto superior direito para fechar o visualizador
- **Suporte a Múltiplos Tipos**: Funciona com imagens de rede (HTTP/HTTPS) e locais (File)
- **Filtro de Alta Qualidade**: Usa `FilterQuality.high` para renderização de máxima qualidade

## Biblioteca Utilizada

**photo_view** (v0.15.0) - Biblioteca oficial do Flutter para visualização de imagens com zoom e pan.

## Arquivos Modificados/Criados

### 1. `pubspec.yaml`
- Adicionada dependência `photo_view: ^0.15.0`

### 2. `lib/ui/atoms/image_viewer/image_viewer.dart` (NOVO)
Widget reutilizável para visualização de imagens:
```dart
// Uso básico
ImageViewer.show(
  context,
  imageUrl: 'https://example.com/image.jpg',
);

// Com Hero animation (opcional)
ImageViewer.show(
  context,
  imageUrl: 'https://example.com/image.jpg',
  heroTag: 'image_hero_tag',
);
```

**Design System**: Utiliza `IconOnlyButton` do design system do projeto para os botões de ação (download e fechar).

### 3. `lib/ui/organisms/editors/generic_block_editor.dart`
- Adicionado import do `ImageViewer`
- Modificada função `_buildImageBlock()` para tornar imagens clicáveis
- Adicionado `GestureDetector` e `MouseRegion` para detectar cliques
- Cursor muda para "pointer" quando sobre a imagem (apenas em modo de visualização)

## Como Usar

### Para o Usuário Final

1. **Visualizar Imagem**: Clique em qualquer imagem nos comentários ou outros locais do app
2. **Zoom In**: 
   - Use dois dedos e afaste-os (pinch out)
   - Use scroll do mouse para cima
   - Dê duplo toque na imagem
3. **Zoom Out**: 
   - Use dois dedos e aproxime-os (pinch in)
   - Use scroll do mouse para baixo
4. **Mover Imagem**: Clique e arraste a imagem
5. **Baixar Imagem**: Clique no botão de download (ícone de seta para baixo) no canto superior direito
   - Escolha onde salvar a imagem
   - A imagem será baixada na qualidade original
6. **Fechar**: Clique no botão X no canto superior direito ou pressione ESC

### Para Desenvolvedores

Para adicionar o visualizador em outros locais do app:

```dart
import 'package:my_business/ui/atoms/image_viewer/image_viewer.dart';

// Em qualquer widget
GestureDetector(
  onTap: () => ImageViewer.show(
    context,
    imageUrl: suaUrlDaImagem,
  ),
  child: Image.network(suaUrlDaImagem),
)
```

## Comportamento

- **Modo de Edição**: Imagens NÃO são clicáveis (para não interferir com a edição)
- **Modo de Visualização**: Imagens SÃO clicáveis e abrem o visualizador
- **Indicador Visual**: O cursor muda para "pointer" quando sobre uma imagem clicável
- **Carregamento**: Mostra um indicador de progresso enquanto a imagem carrega
- **Erro**: Mostra mensagem de erro se a imagem falhar ao carregar

## Compatibilidade

- ✅ Windows Desktop
- ✅ Web
- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Linux

## Notas Técnicas

- A biblioteca `photo_view` é amplamente utilizada na comunidade Flutter
- **Qualidade Original**: As imagens são carregadas e exibidas na resolução original
  - Usa `FilterQuality.high` para renderização de máxima qualidade
  - Não há redimensionamento ou compressão adicional
  - Zoom de até 4x permite ver todos os detalhes da imagem
- Suporta imagens de qualquer tamanho
- Performance otimizada com cache de imagens (sem perda de qualidade)
- Não interfere com o funcionamento existente do editor de blocos
- O `NetworkImage` e `FileImage` carregam as imagens na resolução completa
- **Design System**: Utiliza componentes do design system do projeto
  - `IconOnlyButton` para os botões de ação
  - Mantém consistência visual com o resto do aplicativo
  - Respeita as cores, fontes e espaçamentos do design system
