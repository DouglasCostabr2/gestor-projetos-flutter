# Regras de Desenvolvimento para IA - Gestor de Projetos Flutter

## 🎯 Princípios Fundamentais

### 1. **SEMPRE Executar o App Após Alterações**
- ✅ Após concluir qualquer modificação, SEMPRE executar: `flutter run -d windows`
- ✅ Verificar se o hot reload funcionou corretamente
- ✅ Confirmar que não há erros em runtime

### 2. **Buscar Informação ANTES de Implementar**
- ✅ Usar `codebase-retrieval` para entender o contexto
- ✅ Usar `view` para ver arquivos relacionados
- ✅ Usar `grep-search` para encontrar padrões existentes
- ✅ NUNCA assumir estruturas sem verificar

### 3. **Seguir Padrões Existentes**
- ✅ Verificar como funcionalidades similares foram implementadas
- ✅ Manter consistência de nomenclatura
- ✅ Usar as mesmas cores e dimensões do tema
- ✅ Seguir a estrutura de pastas estabelecida

---

## 🗄️ Regras de Banco de Dados

### Ordem de Deleção (CRÍTICO)
```
1. package_items, task_products (mais profundo)
2. task_files, task_comments, task_history
3. tasks, project_members, project_additional_costs, payments
4. projects, companies
5. clients
6. categories, products, packages (independentes)
```

### Ao Criar Scripts de Deleção
- ✅ SEMPRE seguir a ordem acima
- ✅ Usar CASCADE DELETE quando apropriado
- ✅ Testar em ambiente de desenvolvimento primeiro
- ✅ Documentar o que será deletado

### Ao Criar Novas Tabelas
- ✅ Definir foreign keys corretamente
- ✅ Adicionar à hierarquia de dependências
- ✅ Atualizar `PROJECT_ARCHITECTURE.md`

---

## 🎨 Regras de UI/UX

### Cores (SEMPRE usar constantes do tema)
```dart
// ❌ NUNCA fazer isso:
color: Color(0xFF123456)

// ✅ SEMPRE fazer isso:
color: Theme.of(context).colorScheme.surface
color: const Color(0xFF151515) // Se for constante do projeto
```

### Cores Aprovadas
- Background: `0xFF151515`
- Card/Surface: `0xFF151515`
- Borda: `0xFF2A2A2A`
- Texto principal: `0xFFEAEAEA`
- Texto secundário: `0xFF9AA0A6`
- Accent: `0xFF7AB6FF`
- Erro: `0xFFFF4D4D`
- Sucesso: `0xFF4CAF50`

### Dimensões Padrão
- Side menu expandido: `260px`
- Side menu colapsado: `72px`
- Tab bar altura: `40px`
- Tab largura: `120px - 260px` (dinâmica)
- Border radius botões: `12px`
- Border radius abas: `8px` (apenas topo)
- Padding botões: `16px horizontal, 12px vertical`

### Widgets
- ✅ Sempre usar `const` quando possível
- ✅ Preferir `StatelessWidget` quando não há estado
- ✅ Usar `AnimatedBuilder` para reatividade
- ✅ Extrair widgets complexos em classes separadas

---

## 📁 Regras de Nomenclatura

### Arquivos
```dart
// ✅ Correto
lib/src/features/clients/clients_page.dart
lib/widgets/side_menu/side_menu.dart

// ❌ Errado
lib/src/features/clients/ClientsPage.dart
lib/widgets/SideMenu.dart
```

### Classes
```dart
// ✅ Correto
class ClientsPage extends StatelessWidget {}
class _ClientsPageState extends State<ClientsPage> {}

// ❌ Errado
class clientsPage extends StatelessWidget {}
class ClientsPageState extends State<ClientsPage> {}
```

### Variáveis
```dart
// ✅ Correto
final userName = 'Douglas';
const maxTabWidth = 260.0;

// ❌ Errado
final UserName = 'Douglas';
const MAX_TAB_WIDTH = 260.0;
```

### Imagens no Supabase Storage
```dart
// ✅ Correto
'avatar-douglas-costa.jpg'
'thumb-logo-design.jpg'

// ❌ Errado
'Avatar_Douglas_Costa.jpg'
'THUMB-logo-design.jpg'
```

---

## 🔐 Regras de Permissões

### Verificar Role ANTES de Mostrar UI
```dart
// ✅ Correto
if (userRole != UserRole.cliente) {
  // Mostrar opção de Clientes
}

// ❌ Errado
// Mostrar para todos e bloquear depois
```

### Matriz de Acesso (Consultar Sempre)
- Admin: Acesso total
- Gestor: Sem Admin
- Financeiro: Apenas Financeiro + básico
- Designer/Usuario: Sem Admin, Financeiro, Monitoramento
- Cliente: Sem Clientes, Catálogo, Admin, Financeiro, Monitoramento

---

## 🔄 Regras do Sistema de Abas

### Comportamento
- ✅ Home: Permite múltiplas abas (IDs únicos)
- ✅ Outras páginas: Apenas uma aba (reutiliza se existe)
- ✅ Side menu: Atualiza aba atual (NÃO cria nova)
- ✅ Botão "+": Cria nova aba da Home

### Ao Modificar Sistema de Abas
- ✅ Testar com 1, 5, 10, 20 abas
- ✅ Verificar largura dinâmica
- ✅ Testar fechar abas (X e clique do meio)
- ✅ Verificar se aba selecionada está visível

---

## 📦 Regras de Gerenciamento de Pacotes

### SEMPRE Usar Package Managers
```bash
# ✅ Correto
flutter pub add package_name
flutter pub remove package_name

# ❌ NUNCA fazer isso:
# Editar pubspec.yaml manualmente
```

### Ao Adicionar Dependência
1. Verificar se já existe no projeto
2. Usar versão estável
3. Atualizar `pubspec.yaml` via comando
4. Executar `flutter pub get`
5. Testar se não quebrou nada

---

## 🧪 Regras de Testes

### Antes de Considerar Concluído
- ✅ Executar o app e testar manualmente
- ✅ Testar com diferentes roles de usuário
- ✅ Testar edge cases (lista vazia, muitos itens, etc.)
- ✅ Verificar responsividade (side menu expandido/colapsado)
- ✅ Confirmar que não há erros no console

### Ao Modificar Funcionalidade Existente
- ✅ Testar que funcionalidade antiga ainda funciona
- ✅ Testar integração com outras features
- ✅ Verificar se não quebrou navegação

---

## 📝 Regras de Documentação

### Ao Criar Nova Feature
1. Atualizar `PROJECT_ARCHITECTURE.md`
2. Adicionar comentários no código
3. Documentar padrões específicos
4. Atualizar memória se necessário

### Comentários no Código
```dart
// ✅ Correto - Explica o "porquê"
// Calcula largura dinâmica para evitar overflow quando há muitas abas
double tabWidth = (availableWidth / tabCount).clamp(120.0, 260.0);

// ❌ Errado - Explica o "o quê" (óbvio)
// Calcula a largura da aba
double tabWidth = (availableWidth / tabCount).clamp(120.0, 260.0);
```

---

## 🚨 Regras de Segurança

### NUNCA Fazer
- ❌ Commitar sem permissão explícita
- ❌ Fazer push para remote sem autorização
- ❌ Deletar dados de produção
- ❌ Expor credenciais no código
- ❌ Fazer rebase sem permissão

### SEMPRE Fazer
- ✅ Pedir confirmação antes de ações destrutivas
- ✅ Usar variáveis de ambiente para secrets
- ✅ Validar inputs do usuário
- ✅ Tratar erros adequadamente

---

## 🔧 Regras de Refatoração

### Quando Refatorar
- ✅ Código duplicado em 3+ lugares
- ✅ Função com mais de 50 linhas
- ✅ Arquivo com mais de 500 linhas
- ✅ Quando solicitado explicitamente

### Como Refatorar
1. Entender o código atual completamente
2. Criar testes (se não existirem)
3. Refatorar em pequenos passos
4. Testar após cada passo
5. Confirmar que tudo funciona

---

## 📊 Regras de Performance

### Otimizações
- ✅ Usar `const` construtores sempre que possível
- ✅ Evitar rebuilds desnecessários
- ✅ Usar `ListView.builder` para listas longas
- ✅ Lazy load quando apropriado

### Evitar
- ❌ Operações pesadas no build()
- ❌ Criar objetos desnecessários
- ❌ Múltiplas queries ao banco quando uma basta

---

## 🎓 Regras de Aprendizado

### Quando Não Souber
1. Buscar no código existente
2. Consultar `PROJECT_ARCHITECTURE.md`
3. Perguntar ao usuário
4. NUNCA assumir ou adivinhar

### Quando Errar
1. Reconhecer o erro
2. Explicar o que aconteceu
3. Propor solução
4. Aprender para não repetir

---

## ✅ Checklist Antes de Finalizar Tarefa

- [ ] Código implementado e testado
- [ ] App executado sem erros
- [ ] Hot reload funcionando
- [ ] Padrões do projeto seguidos
- [ ] Cores e dimensões corretas
- [ ] Permissões verificadas
- [ ] Documentação atualizada (se necessário)
- [ ] Nenhum warning no console
- [ ] Funcionalidade testada manualmente
- [ ] Usuário confirmou que está correto

---

## 🎯 Lema do Projeto

> **"Buscar, Entender, Implementar, Testar, Documentar"**

Sempre nessa ordem. Nunca pular etapas.

