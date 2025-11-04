# Roadmap - Atomic Design

Plano de evolução da estrutura Atomic Design do projeto.

---

## 🎯 Visão Geral

Este roadmap define as próximas etapas para completar a migração Atomic Design e melhorar a arquitetura de componentes do projeto.

---

## ✅ Fase 1: Fundação (COMPLETO)

**Status:** ✅ Concluído em 2025-10-13

### Objetivos
- [x] Criar estrutura de pastas Atomic Design
- [x] Migrar Atoms (buttons, inputs, avatars)
- [x] Migrar Molecules (dropdowns, table_cells)
- [x] Criar barrel files
- [x] Atualizar imports em lib/src/features/
- [x] Criar documentação completa
- [x] Validar compilação e execução

### Resultados
- ✅ 14 Atoms migrados
- ✅ 10 Molecules migrados
- ✅ ~50 arquivos atualizados
- ✅ Documentação completa (7 arquivos)
- ✅ Sistema estável e funcionando

---

## 🔄 Fase 2: Organisms (PENDENTE)

**Status:** ⏳ Planejado  
**Prioridade:** Alta  
**Estimativa:** 2-3 semanas

### Objetivos

#### 2.1 Preparação
- [ ] Refatorar services para dependency injection
- [ ] Criar interfaces para services
- [ ] Modularizar navigation classes
- [ ] Criar providers/controllers para state management

#### 2.2 Migração de Dialogs (Mais Simples)
- [ ] Migrar `StandardDialog` → `lib/ui/organisms/dialogs/`
- [ ] Migrar `DriveConnectDialog` → `lib/ui/organisms/dialogs/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.3 Migração de Lists
- [ ] Migrar `ReorderableDragList` → `lib/ui/organisms/lists/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.4 Migração de Tabs
- [ ] Migrar `GenericTabView` → `lib/ui/organisms/tabs/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.5 Migração de Tables
- [ ] Migrar `ReusableDataTable` → `lib/ui/organisms/tables/`
- [ ] Migrar `DynamicPaginatedTable` → `lib/ui/organisms/tables/`
- [ ] Migrar `TableSearchFilterBar` → `lib/ui/organisms/tables/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.6 Migração de Editors
- [ ] Migrar `CustomBriefingEditor` → `lib/ui/organisms/editors/`
- [ ] Migrar `ChatBriefing` → `lib/ui/organisms/editors/`
- [ ] Migrar `AppFlowyTextField` → `lib/ui/organisms/editors/`
- [ ] Migrar `TextFieldWithToolbar` → `lib/ui/organisms/editors/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.7 Migração de Sections
- [ ] Migrar `CommentsSection` → `lib/ui/organisms/sections/`
- [ ] Migrar `TaskFilesSection` → `lib/ui/organisms/sections/`
- [ ] Migrar `FinalProjectSection` → `lib/ui/organisms/sections/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

#### 2.8 Migração de Navigation
- [ ] Migrar `SideMenu` → `lib/ui/organisms/navigation/`
- [ ] Migrar `TabBarWidget` → `lib/ui/organisms/navigation/`
- [ ] Atualizar imports
- [ ] Testar funcionalidade

### Critérios de Sucesso
- [ ] Todos os organisms migrados para lib/ui/organisms/
- [ ] Nenhum erro de compilação
- [ ] Todas as funcionalidades testadas
- [ ] Documentação atualizada

---

## 📐 Fase 3: Templates (FUTURO)

**Status:** 📋 Planejado  
**Prioridade:** Média  
**Estimativa:** 1-2 semanas

### Objetivos
- [ ] Identificar layouts comuns nas páginas
- [ ] Criar templates reutilizáveis
- [ ] Migrar páginas para usar templates

### Templates Propostos
- [ ] `PageTemplate` - Layout base com header/footer
- [ ] `FormTemplate` - Layout para formulários
- [ ] `ListTemplate` - Layout para listas/tabelas
- [ ] `DetailTemplate` - Layout para páginas de detalhes
- [ ] `DashboardTemplate` - Layout para dashboards

### Critérios de Sucesso
- [ ] 5+ templates criados
- [ ] 50%+ das páginas usando templates
- [ ] Redução de código duplicado
- [ ] Documentação atualizada

---

## 🎨 Fase 4: Design System (FUTURO)

**Status:** 💡 Ideia  
**Prioridade:** Baixa  
**Estimativa:** 2-3 semanas

### Objetivos
- [ ] Criar design tokens (cores, espaçamentos, tipografia)
- [ ] Padronizar estilos em todos os componentes
- [ ] Criar guia de estilo visual
- [ ] Implementar tema claro/escuro completo

### Design Tokens
- [ ] Cores (primary, secondary, error, etc.)
- [ ] Espaçamentos (xs, sm, md, lg, xl)
- [ ] Tipografia (headings, body, captions)
- [ ] Bordas (radius, width)
- [ ] Sombras (elevations)
- [ ] Animações (durations, curves)

### Critérios de Sucesso
- [ ] Design tokens documentados
- [ ] Todos os componentes usando tokens
- [ ] Tema claro/escuro funcionando
- [ ] Guia de estilo publicado

---

## 🧪 Fase 5: Testes (FUTURO)

**Status:** 💡 Ideia  
**Prioridade:** Alta  
**Estimativa:** 3-4 semanas

### Objetivos
- [ ] Criar testes unitários para atoms
- [ ] Criar testes unitários para molecules
- [ ] Criar testes de widget para organisms
- [ ] Criar testes de integração para templates
- [ ] Configurar CI/CD para rodar testes

### Cobertura Alvo
- [ ] Atoms: 90%+
- [ ] Molecules: 80%+
- [ ] Organisms: 70%+
- [ ] Templates: 60%+

### Critérios de Sucesso
- [ ] Cobertura de testes > 75%
- [ ] CI/CD configurado
- [ ] Testes rodando automaticamente
- [ ] Documentação de testes

---

## 📚 Fase 6: Documentação Avançada (FUTURO)

**Status:** 💡 Ideia  
**Prioridade:** Baixa  
**Estimativa:** 1 semana

### Objetivos
- [ ] Criar Storybook/Widgetbook para componentes
- [ ] Adicionar exemplos interativos
- [ ] Criar vídeos tutoriais
- [ ] Publicar documentação online

### Ferramentas
- [ ] Widgetbook para Flutter
- [ ] GitHub Pages para docs
- [ ] Mermaid para diagramas
- [ ] Screenshots automatizados

### Critérios de Sucesso
- [ ] Storybook publicado
- [ ] Todos os componentes documentados
- [ ] 5+ vídeos tutoriais
- [ ] Docs acessíveis online

---

## 🚀 Fase 7: Performance (FUTURO)

**Status:** 💡 Ideia  
**Prioridade:** Média  
**Estimativa:** 2 semanas

### Objetivos
- [ ] Otimizar rebuilds desnecessários
- [ ] Implementar lazy loading
- [ ] Otimizar imagens e assets
- [ ] Melhorar tempo de compilação

### Métricas Alvo
- [ ] Reduzir rebuilds em 30%
- [ ] Reduzir tempo de compilação em 20%
- [ ] Melhorar FPS em 15%
- [ ] Reduzir uso de memória em 10%

### Critérios de Sucesso
- [ ] Métricas atingidas
- [ ] Performance monitorada
- [ ] Documentação de otimizações

---

## 🔧 Fase 8: Ferramentas (FUTURO)

**Status:** 💡 Ideia  
**Prioridade:** Baixa  
**Estimativa:** 1 semana

### Objetivos
- [ ] Criar CLI para gerar componentes
- [ ] Criar snippets para IDEs
- [ ] Criar linters customizados
- [ ] Automatizar validações

### Ferramentas Propostas
- [ ] `flutter_atomic_cli` - CLI para gerar componentes
- [ ] VS Code snippets
- [ ] IntelliJ snippets
- [ ] Custom lint rules

### Critérios de Sucesso
- [ ] CLI funcionando
- [ ] Snippets instalados
- [ ] Linters configurados
- [ ] Documentação de ferramentas

---

## 📊 Métricas de Sucesso

### Quantitativas
- **Componentes migrados:** 24/~44 (55%) → Meta: 100%
- **Cobertura de testes:** 0% → Meta: 75%+
- **Tempo de compilação:** ~20s → Meta: <15s
- **Código duplicado:** ? → Meta: <5%

### Qualitativas
- **Manutenibilidade:** Boa → Meta: Excelente
- **Documentação:** Completa → Meta: Exemplar
- **Consistência:** Alta → Meta: Total
- **Developer Experience:** Boa → Meta: Excelente

---

## 🗓️ Timeline Estimado

```
2025 Q4: Fase 2 (Organisms)
2026 Q1: Fase 3 (Templates) + Fase 5 (Testes)
2026 Q2: Fase 4 (Design System) + Fase 7 (Performance)
2026 Q3: Fase 6 (Docs Avançada) + Fase 8 (Ferramentas)
```

---

## 🤝 Contribuindo

Para contribuir com o roadmap:

1. Revise as fases planejadas
2. Sugira melhorias ou novas fases
3. Priorize itens importantes
4. Implemente e teste
5. Atualize documentação
6. Marque como completo

---

## 📝 Notas

- Este roadmap é flexível e pode ser ajustado
- Prioridades podem mudar conforme necessidades
- Estimativas são aproximadas
- Fases podem ser executadas em paralelo
- Feedback é sempre bem-vindo

---

**Última atualização:** 2025-10-13  
**Versão:** 1.0.0  
**Status Geral:** 🟢 Em andamento (Fase 1 completa)

