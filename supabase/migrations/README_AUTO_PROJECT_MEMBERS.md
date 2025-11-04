# Auto-adicionar Membros ao Projeto

## 📋 Visão Geral

Esta migration implementa a **adição automática de membros ao projeto** quando usuários são atribuídos a tasks.

## 🎯 Problema Resolvido

**Antes:**
- Membros do projeto (`project_members`) eram adicionados **apenas manualmente** via `ProjectMembersDialog`
- Quando um usuário era atribuído a uma task, ele **NÃO** era automaticamente adicionado como membro do projeto
- Isso causava inconsistência: usuários trabalhando em tasks mas não sendo membros oficiais

**Depois:**
- Quando um usuário é atribuído a uma task (via `assigned_to` ou `assignee_user_ids`), ele é **automaticamente adicionado** como membro do projeto
- Mantém consistência entre quem trabalha no projeto e quem é membro oficial
- Simplifica a gestão de equipes

## 🔧 Como Funciona

### 1. **Triggers de Banco de Dados**

Dois triggers foram criados na tabela `tasks`:

#### a) `auto_add_project_members_on_insert`
- Executado quando uma **nova task é criada**
- Se a task tem `assigned_to` ou `assignee_user_ids`, adiciona esses usuários como membros do projeto

#### b) `auto_add_project_members_on_update`
- Executado quando `assigned_to` ou `assignee_user_ids` são **atualizados**
- Adiciona os novos responsáveis como membros do projeto

### 2. **Função `auto_add_project_members()`**

```sql
CREATE OR REPLACE FUNCTION public.auto_add_project_members()
RETURNS TRIGGER AS $$
BEGIN
  -- Adicionar assigned_to como membro
  IF NEW.assigned_to IS NOT NULL THEN
    INSERT INTO public.project_members (project_id, user_id, role)
    VALUES (NEW.project_id, NEW.assigned_to, 'member')
    ON CONFLICT (project_id, user_id) DO NOTHING;
  END IF;

  -- Adicionar todos de assignee_user_ids como membros
  IF NEW.assignee_user_ids IS NOT NULL THEN
    FOREACH user_id_to_add IN ARRAY NEW.assignee_user_ids
    LOOP
      INSERT INTO public.project_members (project_id, user_id, role)
      VALUES (NEW.project_id, user_id_to_add, 'member')
      ON CONFLICT (project_id, user_id) DO NOTHING;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 3. **Migração de Dados Existentes**

A migration também adiciona retroativamente todos os usuários que já têm tasks atribuídas como membros dos projetos:

```sql
-- Adicionar usuários de assigned_to
INSERT INTO public.project_members (project_id, user_id, role)
SELECT DISTINCT t.project_id, t.assigned_to, 'member'
FROM public.tasks t
WHERE t.assigned_to IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.project_members pm
    WHERE pm.project_id = t.project_id AND pm.user_id = t.assigned_to
  )
ON CONFLICT DO NOTHING;

-- Adicionar usuários de assignee_user_ids
INSERT INTO public.project_members (project_id, user_id, role)
SELECT DISTINCT t.project_id, unnest(t.assignee_user_ids), 'member'
FROM public.tasks t
WHERE t.assignee_user_ids IS NOT NULL
ON CONFLICT DO NOTHING;
```

## 📊 Impacto

### **Antes da Migration**
```
Projeto "Website Redesign"
├── Membros oficiais: 2 (adicionados manualmente)
└── Pessoas com tasks: 5 (mas só 2 são membros)
```

### **Depois da Migration**
```
Projeto "Website Redesign"
├── Membros oficiais: 5 (adicionados automaticamente)
└── Pessoas com tasks: 5 (todos são membros)
```

## ✅ Benefícios

1. **Consistência**: Quem trabalha no projeto é automaticamente membro
2. **Menos trabalho manual**: Não precisa adicionar membros manualmente
3. **Melhor controle de acesso**: RLS policies funcionam corretamente
4. **Coluna "Pessoas" mais precisa**: Mostra todos que trabalham no projeto

## 🔍 Verificação

Para verificar se a migration funcionou:

```sql
SELECT 
  p.name as project_name,
  COUNT(DISTINCT pm.user_id) as total_members,
  COUNT(DISTINCT t.assigned_to) as total_assignees
FROM projects p
LEFT JOIN project_members pm ON pm.project_id = p.id
LEFT JOIN tasks t ON t.project_id = p.id
GROUP BY p.id, p.name
ORDER BY p.name;
```

**Resultado esperado:** `total_members` >= `total_assignees`

## 🚀 Como Aplicar

```bash
# Conectar ao Supabase
supabase db push

# Ou aplicar manualmente via SQL Editor no Supabase Dashboard
```

## ⚠️ Observações

1. **Não remove membros**: Se um usuário é removido de todas as tasks, ele **NÃO** é removido automaticamente como membro
2. **Role padrão**: Membros adicionados automaticamente recebem role `'member'`
3. **Sem duplicatas**: `ON CONFLICT DO NOTHING` garante que não haverá duplicatas
4. **Performance**: Triggers são executados apenas quando `assigned_to` ou `assignee_user_ids` mudam

## 🔄 Rollback

Se precisar reverter:

```sql
-- Remover triggers
DROP TRIGGER IF EXISTS auto_add_project_members_on_insert ON public.tasks;
DROP TRIGGER IF EXISTS auto_add_project_members_on_update ON public.tasks;

-- Remover função
DROP FUNCTION IF EXISTS public.auto_add_project_members();

-- OPCIONAL: Remover membros adicionados automaticamente
-- (cuidado: isso pode remover membros legítimos)
-- DELETE FROM project_members WHERE role = 'member';
```

## 📝 Notas Técnicas

- **SECURITY DEFINER**: A função roda com privilégios do owner, não do usuário que executou a query
- **AFTER TRIGGER**: Executado após INSERT/UPDATE, garantindo que a task já existe
- **WHEN clause**: Otimização para executar apenas quando necessário
- **unnest()**: Função PostgreSQL para expandir arrays em linhas

