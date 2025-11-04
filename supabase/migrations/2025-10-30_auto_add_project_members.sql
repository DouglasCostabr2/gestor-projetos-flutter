-- ============================================================================
-- Migration: Auto-adicionar membros ao projeto quando atribuídos a tasks
-- Data: 2025-10-30
-- Descrição: Quando um usuário é atribuído a uma task (assigned_to ou assignee_user_ids),
--            ele é automaticamente adicionado como membro do projeto (se ainda não for)
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR FUNÇÃO PARA AUTO-ADICIONAR MEMBROS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_add_project_members()
RETURNS TRIGGER AS $$
DECLARE
  user_id_to_add uuid;
  project_id_value uuid;
BEGIN
  -- Pegar o project_id da task
  project_id_value := NEW.project_id;
  
  -- Se project_id é NULL, não fazer nada
  IF project_id_value IS NULL THEN
    RETURN NEW;
  END IF;

  -- Adicionar assigned_to como membro (se não for NULL)
  IF NEW.assigned_to IS NOT NULL THEN
    -- Tentar inserir, ignorar se já existir (ON CONFLICT DO NOTHING)
    INSERT INTO public.project_members (project_id, user_id, role)
    VALUES (project_id_value, NEW.assigned_to, 'member')
    ON CONFLICT (project_id, user_id) DO NOTHING;
  END IF;

  -- Adicionar todos os usuários de assignee_user_ids como membros
  IF NEW.assignee_user_ids IS NOT NULL AND array_length(NEW.assignee_user_ids, 1) > 0 THEN
    -- Loop através de cada user_id no array
    FOREACH user_id_to_add IN ARRAY NEW.assignee_user_ids
    LOOP
      -- Tentar inserir, ignorar se já existir
      INSERT INTO public.project_members (project_id, user_id, role)
      VALUES (project_id_value, user_id_to_add, 'member')
      ON CONFLICT (project_id, user_id) DO NOTHING;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.auto_add_project_members() IS 
'Adiciona automaticamente usuários como membros do projeto quando são atribuídos a tasks';

-- ============================================================================
-- PARTE 2: CRIAR TRIGGER
-- ============================================================================

-- Trigger para INSERT (quando task é criada)
DROP TRIGGER IF EXISTS auto_add_project_members_on_insert ON public.tasks;
CREATE TRIGGER auto_add_project_members_on_insert
  AFTER INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_add_project_members();

-- Trigger para UPDATE (quando assigned_to ou assignee_user_ids mudam)
DROP TRIGGER IF EXISTS auto_add_project_members_on_update ON public.tasks;
CREATE TRIGGER auto_add_project_members_on_update
  AFTER UPDATE OF assigned_to, assignee_user_ids ON public.tasks
  FOR EACH ROW
  WHEN (
    -- Só executar se assigned_to ou assignee_user_ids mudaram
    OLD.assigned_to IS DISTINCT FROM NEW.assigned_to OR
    OLD.assignee_user_ids IS DISTINCT FROM NEW.assignee_user_ids
  )
  EXECUTE FUNCTION public.auto_add_project_members();

COMMENT ON TRIGGER auto_add_project_members_on_insert ON public.tasks IS 
'Auto-adiciona membros ao projeto quando task é criada com responsáveis';

COMMENT ON TRIGGER auto_add_project_members_on_update ON public.tasks IS 
'Auto-adiciona membros ao projeto quando responsáveis da task são alterados';

-- ============================================================================
-- PARTE 3: MIGRAR DADOS EXISTENTES
-- ============================================================================

-- Adicionar todos os usuários que já têm tasks atribuídas como membros dos projetos
-- (se ainda não forem membros)

-- Adicionar usuários de assigned_to
INSERT INTO public.project_members (project_id, user_id, role)
SELECT DISTINCT 
  t.project_id,
  t.assigned_to,
  'member'
FROM public.tasks t
WHERE t.assigned_to IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.project_members pm
    WHERE pm.project_id = t.project_id
      AND pm.user_id = t.assigned_to
  )
ON CONFLICT (project_id, user_id) DO NOTHING;

-- Adicionar usuários de assignee_user_ids (array)
INSERT INTO public.project_members (project_id, user_id, role)
SELECT DISTINCT 
  t.project_id,
  unnest(t.assignee_user_ids) as user_id,
  'member'
FROM public.tasks t
WHERE t.assignee_user_ids IS NOT NULL 
  AND array_length(t.assignee_user_ids, 1) > 0
  AND NOT EXISTS (
    SELECT 1 FROM public.project_members pm
    WHERE pm.project_id = t.project_id
      AND pm.user_id = ANY(t.assignee_user_ids)
  )
ON CONFLICT (project_id, user_id) DO NOTHING;

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================

-- Para verificar se funcionou, execute:
-- SELECT 
--   p.name as project_name,
--   COUNT(DISTINCT pm.user_id) as total_members,
--   COUNT(DISTINCT t.assigned_to) as total_assignees
-- FROM projects p
-- LEFT JOIN project_members pm ON pm.project_id = p.id
-- LEFT JOIN tasks t ON t.project_id = p.id
-- GROUP BY p.id, p.name
-- ORDER BY p.name;

