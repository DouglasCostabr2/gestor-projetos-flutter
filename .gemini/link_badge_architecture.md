# Arquitetura: Componente LinkBadge

## Objetivo

Criar um componente reutilizável e de fácil manutenção para exibir links (URLs) como badges clicáveis em todo o projeto.

## Estrutura

### 1. Componente Base: `LinkBadge`
**Localização**: `lib/ui/atoms/badges/link_badge.dart`

**Responsabilidades**:
- Renderizar URL como badge visual
- Gerenciar clique e abertura de URL
- Controlar cursor do mouse
- Desabilitar seleção de texto
- Exibir ícone de link

**Parâmetros Customizáveis**:
```dart
LinkBadge(
  url: 'https://exemplo.com',        // Obrigatório
  textStyle: TextStyle(...),         // Opcional
  backgroundColor: Color(...),       // Opcional (padrão: #2A2A2A)
  borderColor: Color(...),           // Opcional (padrão: #3A3A3A)
  iconColor: Color(...),             // Opcional (padrão: cor do texto)
  iconSize: 14.0,                    // Opcional (padrão: 95% da fonte)
  padding: EdgeInsets(...),          // Opcional
  borderRadius: BorderRadius(...),   // Opcional (padrão: 4px)
)
```

### 2. Uso no `MentionText`
**Localização**: `lib/ui/molecules/text/mention_text.dart`

**Integração**:
```dart
// Antes (código duplicado - 47 linhas)
spans.add(WidgetSpan(
  child: SelectionContainer.disabled(
    child: GestureDetector(
      onTap: () async { ... },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          // ... 30+ linhas de código
        ),
      ),
    ),
  ),
));

// Depois (componente reutilizável - 4 linhas)
spans.add(WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: LinkBadge(
    url: url,
    textStyle: defaultStyle,
  ),
));
```

## Benefícios da Arquitetura

### 1. **Reutilização**
- ✅ Componente pode ser usado em qualquer lugar do projeto
- ✅ Não precisa duplicar código para cada uso
- ✅ Consistência visual garantida

### 2. **Manutenibilidade**
- ✅ Mudanças no estilo: editar apenas `LinkBadge`
- ✅ Correções de bugs: um único lugar
- ✅ Novos recursos: adicionar uma vez, usar em todos os lugares

### 3. **Testabilidade**
- ✅ Componente isolado pode ser testado independentemente
- ✅ Testes unitários mais simples
- ✅ Menos código para manter

### 4. **Flexibilidade**
- ✅ Parâmetros opcionais permitem customização
- ✅ Valores padrão garantem consistência
- ✅ Fácil adaptar para casos específicos

## Onde Usar

### Uso Atual
1. **`MentionText`** - Detecção automática de URLs em texto

### Usos Futuros Possíveis
2. **Listas de recursos** - Exibir links de documentação
3. **Cards de projeto** - Links para repositórios
4. **Perfis de usuário** - Links para redes sociais
5. **Comentários** - Links compartilhados
6. **Qualquer lugar** que precise exibir URLs clicáveis

## Exemplo de Uso Direto

```dart
// Em qualquer widget
Column(
  children: [
    Text('Confira nossos recursos:'),
    SizedBox(height: 8),
    LinkBadge(url: 'https://docs.exemplo.com'),
    SizedBox(height: 4),
    LinkBadge(url: 'https://api.exemplo.com'),
  ],
)
```

## Comparação: Antes vs Depois

### Antes (Código Duplicado)
```
mention_text.dart: 47 linhas de código para links
outro_widget.dart: 47 linhas de código para links (duplicado)
mais_um.dart: 47 linhas de código para links (duplicado)

Total: 141 linhas
Manutenção: 3 lugares para atualizar
```

### Depois (Componente Reutilizável)
```
link_badge.dart: 100 linhas (componente base)
mention_text.dart: 4 linhas (uso)
outro_widget.dart: 4 linhas (uso)
mais_um.dart: 4 linhas (uso)

Total: 112 linhas
Manutenção: 1 lugar para atualizar
```

**Economia**: 29 linhas de código
**Manutenibilidade**: 3x mais fácil (1 lugar vs 3 lugares)

## Princípios Seguidos

### 1. **DRY (Don't Repeat Yourself)**
- Código não é duplicado
- Uma única fonte de verdade

### 2. **Single Responsibility**
- `LinkBadge`: apenas renderizar e gerenciar links
- `MentionText`: apenas detectar e renderizar menções/links

### 3. **Separation of Concerns**
- Lógica de UI separada da lógica de detecção
- Componentes independentes e testáveis

### 4. **Design System**
- Componente faz parte do design system (atoms/badges)
- Consistência visual em todo o projeto

## Manutenção Futura

### Para mudar o estilo dos links:
1. Editar apenas `lib/ui/atoms/badges/link_badge.dart`
2. Mudança reflete automaticamente em todo o projeto

### Para adicionar nova funcionalidade:
1. Adicionar parâmetro opcional em `LinkBadge`
2. Implementar funcionalidade
3. Usar onde necessário (sem quebrar código existente)

### Para corrigir bugs:
1. Corrigir em `LinkBadge`
2. Bug corrigido em todos os usos automaticamente

## Conclusão

A refatoração para usar `LinkBadge` como componente separado:
- ✅ Reduz duplicação de código
- ✅ Facilita manutenção
- ✅ Melhora testabilidade
- ✅ Segue princípios SOLID
- ✅ Integra-se ao design system
- ✅ Permite reutilização em todo o projeto
