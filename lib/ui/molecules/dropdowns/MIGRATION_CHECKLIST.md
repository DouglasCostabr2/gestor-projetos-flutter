# 📋 Checklist de Migração - Componentes Dropdown

Este checklist ajuda a organizar a migração do código existente para usar os novos componentes dropdown genéricos.

---

## 🎯 Fase 1: Componentes Específicos (Alta Prioridade)

Estes são componentes que já existem e podem ser simplificados usando os novos dropdowns genéricos.

### TaskStatusField
- [ ] **Arquivo:** `lib/src/features/tasks/widgets/task_status_field.dart`
- [ ] **Tipo:** Migrar para `GenericDropdownField<String>`
- [ ] **Benefício:** Redução de ~110 para ~35 linhas (-68%)
- [ ] **Features a preservar:**
  - Validação assíncrona (onBeforeChanged)
  - Mensagem de erro customizada
  - 5 status: todo, in_progress, review, waiting, completed
- [ ] **Testar em:**
  - TasksPage._TaskForm
  - QuickTaskForm
- [ ] **Status:** ⬜ Não iniciado

### TaskPriorityField
- [ ] **Arquivo:** `lib/src/features/tasks/widgets/task_priority_field.dart`
- [ ] **Tipo:** Migrar para `GenericDropdownField<String>`
- [ ] **Benefício:** Redução de ~52 para ~30 linhas (-42%)
- [ ] **Features a preservar:**
  - 4 prioridades: low, medium, high, urgent
  - Fallback para 'medium'
- [ ] **Testar em:**
  - TasksPage._TaskForm
  - QuickTaskForm
- [ ] **Status:** ⬜ Não iniciado

### ProjectStatusField
- [ ] **Arquivo:** `lib/src/features/projects/widgets/project_status_field.dart`
- [ ] **Tipo:** Migrar para `GenericDropdownField<String>`
- [ ] **Benefício:** Redução de ~65 para ~40 linhas (-38%)
- [ ] **Features a preservar:**
  - Normalização de status antigos (active → in_progress)
  - 6 status: not_started, negotiation, in_progress, paused, completed, cancelled
  - Border outline
- [ ] **Testar em:**
  - ProjectFormDialog
  - QuickProjectForm
- [ ] **Status:** ⬜ Não iniciado

### TaskAssigneeField
- [ ] **Arquivo:** `lib/src/features/tasks/widgets/task_assignee_field.dart`
- [ ] **Tipo:** Migrar para `GenericDropdownField<String?>`
- [ ] **Benefício:** Código mais limpo e consistente
- [ ] **Features a preservar:**
  - Nullable (permite "Não atribuído")
  - Widget customizado (UserDropdownItem com avatar)
  - Validação de assignee válido
- [ ] **Testar em:**
  - TasksPage._TaskForm
  - QuickTaskForm
- [ ] **Status:** ✅ Concluído

---

## 🎯 Fase 2: Formulários Complexos (Média Prioridade)

### ClientForm - Categoria
- [ ] **Arquivo:** `lib/src/features/clients/widgets/client_form.dart`
- [ ] **Linhas:** ~365-393
- [ ] **Tipo:** Migrar para `SearchableDropdownField<String>`
- [ ] **Benefício:** Redução de ~25 para ~8 linhas (-68%)
- [ ] **Features a preservar:**
  - Busca e filtro
  - Loading state
  - Controller (_categoryController)
- [ ] **Remover:**
  - LayoutBuilder manual
  - Gerenciamento de width manual
- [ ] **Status:** ⬜ Não iniciado

### ProjectFormDialog - Cliente
- [ ] **Arquivo:** `lib/src/features/projects/project_form_dialog.dart`
- [ ] **Linhas:** ~554-567
- [ ] **Tipo:** Migrar para `AsyncDropdownField<String>`
- [ ] **Benefício:** Carregamento automático, menos state management
- [ ] **Features a preservar:**
  - Carregamento de clientes
  - Callback ao mudar (limpar empresa)
  - Condicional (fixedClientId)
- [ ] **Remover:**
  - _loadClients() no initState
  - _clients como state
- [ ] **Status:** ⬜ Não iniciado

### ProjectFormDialog - Empresa
- [ ] **Arquivo:** `lib/src/features/projects/project_form_dialog.dart`
- [ ] **Linhas:** ~569-576
- [ ] **Tipo:** Migrar para `AsyncDropdownField<String>`
- [ ] **Benefício:** Recarregamento automático quando cliente muda
- [ ] **Features a preservar:**
  - Dependência do cliente
  - Carregamento condicional
  - Condicional (fixedCompanyId)
- [ ] **Remover:**
  - _loadCompanies() manual
  - _companies como state
  - Lógica de reset manual
- [ ] **Usar:** `dependencies: [_clientId]`
- [ ] **Status:** ⬜ Não iniciado

### CountryStateCitySelector
- [ ] **Arquivo:** `lib/src/features/clients/widgets/country_state_city_selector.dart`
- [ ] **Linhas:** ~138-243
- [ ] **Tipo:** Migrar para 3x `SearchableDropdownField`
- [ ] **Benefício:** Código mais limpo, menos LayoutBuilder
- [ ] **Features a preservar:**
  - Cascata (país → estado → cidade)
  - Loading states independentes
  - Busca e filtro
- [ ] **Considerar:** Criar componente específico `CascadingLocationSelector`
- [ ] **Status:** ⬜ Não iniciado

### _SelectProductsDialog - Filtro de Categoria
- [ ] **Arquivo:** `lib/src/features/catalog/_select_products_dialog.dart`
- [ ] **Linhas:** ~83-96
- [ ] **Tipo:** Migrar para `GenericDropdownField<String?>`
- [ ] **Benefício:** Código mais limpo
- [ ] **Features a preservar:**
  - Opção "Todas" (null)
  - Geração dinâmica de categorias
- [ ] **Status:** ⬜ Não iniciado

### ProjectMembersDialog - Seleção de Usuário
- [ ] **Arquivo:** `lib/src/features/projects/project_members_dialog.dart`
- [ ] **Linhas:** ~258-270
- [ ] **Tipo:** Migrar para `GenericDropdownField<String>` ou `SearchableDropdownField<String>`
- [ ] **Benefício:** Código mais limpo
- [ ] **Features a preservar:**
  - Widget customizado (UserDropdownItem)
  - Loading state
  - Filtro de candidatos
- [ ] **Status:** ⬜ Não iniciado

---

## 🎯 Fase 3: Outros Dropdowns (Baixa Prioridade)

### Buscar outros usos de DropdownButtonFormField
- [ ] Executar busca no projeto: `DropdownButtonFormField`
- [ ] Listar todos os usos encontrados
- [ ] Avaliar quais podem ser migrados
- [ ] Criar issues/tasks para cada um
- [ ] **Status:** ⬜ Não iniciado

### Buscar outros usos de DropdownMenu
- [ ] Executar busca no projeto: `DropdownMenu<`
- [ ] Listar todos os usos encontrados
- [ ] Avaliar quais podem ser migrados
- [ ] Criar issues/tasks para cada um
- [ ] **Status:** ⬜ Não iniciado

### Buscar outros usos de DropdownButton
- [ ] Executar busca no projeto: `DropdownButton<`
- [ ] Listar todos os usos encontrados
- [ ] Avaliar quais podem ser migrados
- [ ] Criar issues/tasks para cada um
- [ ] **Status:** ⬜ Não iniciado

---

## 🎯 Fase 4: Testes e Validação

### Testes Manuais
- [ ] Testar TaskStatusField em TasksPage
- [ ] Testar TaskStatusField em QuickTaskForm
- [ ] Testar TaskPriorityField em TasksPage
- [ ] Testar TaskPriorityField em QuickTaskForm
- [ ] Testar ProjectStatusField em ProjectFormDialog
- [ ] Testar TaskAssigneeField em TasksPage
- [ ] Testar categoria em ClientForm
- [ ] Testar cliente/empresa em ProjectFormDialog
- [ ] Testar validações assíncronas
- [ ] Testar loading states
- [ ] Testar error states
- [ ] Testar recarregamento por dependências
- [ ] **Status:** ⬜ Não iniciado

### Testes Automatizados (Opcional)
- [ ] Criar testes para GenericDropdownField
- [ ] Criar testes para SearchableDropdownField
- [ ] Criar testes para AsyncDropdownField
- [ ] Criar testes de integração
- [ ] **Status:** ⬜ Não iniciado

---

## 🎯 Fase 5: Limpeza e Documentação

### Remover Código Antigo
- [ ] Remover implementações antigas após confirmar que migrações funcionam
- [ ] Remover imports não utilizados
- [ ] Remover state variables não utilizados
- [ ] Remover métodos de carregamento não utilizados
- [ ] **Status:** ⬜ Não iniciado

### Atualizar Documentação
- [ ] Atualizar COMPONENTES_ADICIONAIS_EXTRAIDOS.md
- [ ] Documentar novos padrões de uso
- [ ] Criar guia de estilo para dropdowns
- [ ] Atualizar README do projeto
- [ ] **Status:** ⬜ Não iniciado

---

## 📊 Progresso Geral

### Resumo
- **Total de tarefas:** 40+
- **Concluídas:** 0
- **Em progresso:** 0
- **Não iniciadas:** 40+
- **Progresso:** 0%

### Por Fase
- **Fase 1 (Alta):** ⬜⬜⬜⬜ (0/4)
- **Fase 2 (Média):** ⬜⬜⬜⬜⬜⬜ (0/6)
- **Fase 3 (Baixa):** ⬜⬜⬜ (0/3)
- **Fase 4 (Testes):** ⬜⬜ (0/2)
- **Fase 5 (Limpeza):** ⬜⬜ (0/2)

---

## 💡 Dicas para Migração

1. **Comece pelos mais simples:** TaskPriorityField é o mais fácil
2. **Teste cada migração:** Não migre tudo de uma vez
3. **Mantenha o código antigo:** Comente ao invés de deletar até confirmar
4. **Use git branches:** Crie uma branch para cada migração
5. **Documente problemas:** Anote qualquer issue encontrado
6. **Peça ajuda:** Consulte README.md e MIGRATION_EXAMPLES.md

---

## 🎯 Ordem Sugerida de Migração

1. ✅ **TaskPriorityField** - Mais simples, sem validação complexa
2. ✅ **ProjectStatusField** - Simples, com normalização
3. ✅ **TaskAssigneeField** - Médio, com widget customizado
4. ✅ **TaskStatusField** - Complexo, com validação assíncrona
5. ✅ **ClientForm (categoria)** - Migração de DropdownMenu
6. ✅ **_SelectProductsDialog** - Dropdown simples
7. ✅ **ProjectFormDialog (cliente)** - AsyncDropdownField básico
8. ✅ **ProjectFormDialog (empresa)** - AsyncDropdownField com dependência
9. ✅ **ProjectMembersDialog** - Dropdown com filtro
10. ✅ **CountryStateCitySelector** - Mais complexo, cascata tripla

---

## 📝 Notas

- Marque ✅ quando completar uma tarefa
- Use 🔄 para tarefas em progresso
- Use ❌ para tarefas bloqueadas
- Adicione comentários sobre problemas encontrados
- Atualize o progresso regularmente

---

**Última atualização:** 2025-10-12  
**Status geral:** 🟡 Pronto para iniciar migração

