-- ============================================================================
-- Migration: Sistema de Rastreamento de Tempo para Tarefas
-- Data: 2025-10-13
-- Descrição: Adiciona tabela time_logs e campo total_time_spent em tasks
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR TABELA time_logs
-- ============================================================================

-- Tabela para armazenar registros de tempo (sessões de trabalho)
CREATE TABLE IF NOT EXISTS public.time_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration_seconds integer,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Comentários explicativos
COMMENT ON TABLE public.time_logs IS 'Registros de tempo gasto em tarefas (sessões de trabalho)';
COMMENT ON COLUMN public.time_logs.id IS 'ID único do registro de tempo';
COMMENT ON COLUMN public.time_logs.task_id IS 'ID da tarefa relacionada';
COMMENT ON COLUMN public.time_logs.user_id IS 'ID do usuário que registrou o tempo';
COMMENT ON COLUMN public.time_logs.start_time IS 'Data/hora de início da sessão';
COMMENT ON COLUMN public.time_logs.end_time IS 'Data/hora de fim da sessão (NULL se ainda em andamento)';
COMMENT ON COLUMN public.time_logs.duration_seconds IS 'Duração da sessão em segundos (calculado quando end_time é definido)';
COMMENT ON COLUMN public.time_logs.created_at IS 'Data/hora de criação do registro';
COMMENT ON COLUMN public.time_logs.updated_at IS 'Data/hora da última atualização';

-- ============================================================================
-- PARTE 2: ADICIONAR CAMPO total_time_spent NA TABELA tasks
-- ============================================================================

-- Adicionar coluna para armazenar tempo total acumulado
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS total_time_spent integer DEFAULT 0;

COMMENT ON COLUMN public.tasks.total_time_spent IS 'Tempo total gasto na tarefa em segundos (soma de todas as sessões)';

-- ============================================================================
-- PARTE 3: CRIAR ÍNDICES PARA PERFORMANCE
-- ============================================================================

-- Índice para buscar time_logs por tarefa (query mais comum)
CREATE INDEX IF NOT EXISTS idx_time_logs_task_id 
ON public.time_logs(task_id);

-- Índice para buscar time_logs por usuário
CREATE INDEX IF NOT EXISTS idx_time_logs_user_id 
ON public.time_logs(user_id);

-- Índice para ordenar por data de início
CREATE INDEX IF NOT EXISTS idx_time_logs_start_time 
ON public.time_logs(start_time DESC);

-- Índice composto para buscar sessões ativas (end_time NULL)
CREATE INDEX IF NOT EXISTS idx_time_logs_active 
ON public.time_logs(task_id, user_id) 
WHERE end_time IS NULL;

-- ============================================================================
-- PARTE 4: FUNÇÃO PARA ATUALIZAR total_time_spent
-- ============================================================================

-- Função que recalcula o tempo total de uma tarefa
CREATE OR REPLACE FUNCTION public.update_task_total_time()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalcular o tempo total da tarefa somando todas as sessões finalizadas
  UPDATE public.tasks
  SET total_time_spent = COALESCE(
    (
      SELECT SUM(duration_seconds)
      FROM public.time_logs
      WHERE task_id = COALESCE(NEW.task_id, OLD.task_id)
        AND duration_seconds IS NOT NULL
    ),
    0
  )
  WHERE id = COALESCE(NEW.task_id, OLD.task_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.update_task_total_time() IS 'Atualiza automaticamente o campo total_time_spent da tarefa quando um time_log é inserido, atualizado ou deletado';

-- ============================================================================
-- PARTE 5: CRIAR TRIGGERS
-- ============================================================================

-- Trigger para atualizar total_time_spent quando um time_log é inserido
DROP TRIGGER IF EXISTS time_log_insert_trigger ON public.time_logs;
CREATE TRIGGER time_log_insert_trigger
  AFTER INSERT ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_task_total_time();

-- Trigger para atualizar total_time_spent quando um time_log é atualizado
DROP TRIGGER IF EXISTS time_log_update_trigger ON public.time_logs;
CREATE TRIGGER time_log_update_trigger
  AFTER UPDATE ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_task_total_time();

-- Trigger para atualizar total_time_spent quando um time_log é deletado
DROP TRIGGER IF EXISTS time_log_delete_trigger ON public.time_logs;
CREATE TRIGGER time_log_delete_trigger
  AFTER DELETE ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_task_total_time();

-- ============================================================================
-- PARTE 6: CONFIGURAR RLS (Row Level Security)
-- ============================================================================

-- Habilitar RLS na tabela time_logs
ALTER TABLE public.time_logs ENABLE ROW LEVEL SECURITY;

-- Política: Usuários podem ver time_logs de tarefas que eles têm acesso
-- (tarefas atribuídas a eles ou tarefas de projetos que eles participam)
DROP POLICY IF EXISTS "Users can view time logs of accessible tasks" ON public.time_logs;
CREATE POLICY "Users can view time logs of accessible tasks"
  ON public.time_logs
  FOR SELECT
  USING (
    -- Ver seus próprios time_logs
    auth.uid() = user_id
    OR
    -- Ver time_logs de tarefas atribuídas a eles
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = time_logs.task_id
        AND tasks.assigned_to = auth.uid()
    )
    OR
    -- Ver time_logs de tarefas de projetos que eles participam
    EXISTS (
      SELECT 1 FROM public.tasks t
      INNER JOIN public.project_members pm ON pm.project_id = t.project_id
      WHERE t.id = time_logs.task_id
        AND pm.user_id = auth.uid()
    )
  );

-- Política: Usuários podem inserir time_logs apenas para si mesmos
-- e apenas para tarefas atribuídas a eles
DROP POLICY IF EXISTS "Users can insert time logs for assigned tasks" ON public.time_logs;
CREATE POLICY "Users can insert time logs for assigned tasks"
  ON public.time_logs
  FOR INSERT
  WITH CHECK (
    -- Só pode criar time_log para si mesmo
    auth.uid() = user_id
    AND
    -- E apenas para tarefas atribuídas a ele
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_id
        AND tasks.assigned_to = auth.uid()
    )
  );

-- Política: Usuários podem atualizar apenas seus próprios time_logs
-- e apenas se ainda estiverem atribuídos à tarefa
DROP POLICY IF EXISTS "Users can update own time logs" ON public.time_logs;
CREATE POLICY "Users can update own time logs"
  ON public.time_logs
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND
    EXISTS (
      SELECT 1 FROM public.tasks
      WHERE tasks.id = task_id
        AND tasks.assigned_to = auth.uid()
    )
  );

-- Política: Usuários podem deletar apenas seus próprios time_logs
DROP POLICY IF EXISTS "Users can delete own time logs" ON public.time_logs;
CREATE POLICY "Users can delete own time logs"
  ON public.time_logs
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- PARTE 7: CONSTRAINTS DE VALIDAÇÃO
-- ============================================================================

-- Garantir que end_time seja maior que start_time (quando ambos existem)
ALTER TABLE public.time_logs
  ADD CONSTRAINT check_end_time_after_start_time
  CHECK (
    end_time IS NULL OR end_time > start_time
  );

-- Garantir que duration_seconds seja positivo (quando existe)
ALTER TABLE public.time_logs
  ADD CONSTRAINT check_duration_positive
  CHECK (
    duration_seconds IS NULL OR duration_seconds > 0
  );

-- Garantir que notes não seja apenas espaços em branco
ALTER TABLE public.time_logs
  ADD CONSTRAINT check_notes_not_empty
  CHECK (
    notes IS NULL OR trim(notes) != ''
  );

-- ============================================================================
-- PARTE 8: ÍNDICES PARA PERFORMANCE
-- ============================================================================

-- Índice para buscar time_logs por usuário (comum em dashboards)
CREATE INDEX IF NOT EXISTS idx_time_logs_user_id
  ON public.time_logs(user_id);

-- Índice para buscar time_logs por tarefa (comum em detalhes de tarefa)
CREATE INDEX IF NOT EXISTS idx_time_logs_task_id
  ON public.time_logs(task_id);

-- Índice composto para buscar time_logs de um usuário em uma tarefa específica
CREATE INDEX IF NOT EXISTS idx_time_logs_user_task
  ON public.time_logs(user_id, task_id);

-- Índice para buscar time_logs por data (útil para relatórios)
CREATE INDEX IF NOT EXISTS idx_time_logs_start_time
  ON public.time_logs(start_time DESC);

-- Índice para buscar time_logs ativos (sem end_time)
CREATE INDEX IF NOT EXISTS idx_time_logs_active
  ON public.time_logs(user_id, task_id)
  WHERE end_time IS NULL;

-- ============================================================================
-- PARTE 9: FUNÇÃO AUXILIAR PARA CALCULAR DURAÇÃO
-- ============================================================================

-- Função para calcular e atualizar a duração quando end_time é definido
CREATE OR REPLACE FUNCTION public.calculate_time_log_duration()
RETURNS TRIGGER AS $$
BEGIN
  -- Se end_time foi definido e duration_seconds ainda não foi calculado
  IF NEW.end_time IS NOT NULL AND (NEW.duration_seconds IS NULL OR OLD.end_time IS NULL) THEN
    NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))::integer;
    NEW.updated_at = now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.calculate_time_log_duration() IS 'Calcula automaticamente a duração em segundos quando end_time é definido';

-- Trigger para calcular duração antes de inserir ou atualizar
DROP TRIGGER IF EXISTS calculate_duration_trigger ON public.time_logs;
CREATE TRIGGER calculate_duration_trigger
  BEFORE INSERT OR UPDATE ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_time_log_duration();

-- ============================================================================
-- PARTE 10: FUNÇÃO PARA PREVENIR MÚLTIPLOS TIMERS ATIVOS
-- ============================================================================

-- Função para garantir que um usuário tenha apenas um timer ativo por vez
CREATE OR REPLACE FUNCTION public.prevent_multiple_active_timers()
RETURNS TRIGGER AS $$
BEGIN
  -- Se está iniciando um novo timer (end_time é NULL)
  IF NEW.end_time IS NULL THEN
    -- Verificar se já existe outro timer ativo para este usuário
    IF EXISTS (
      SELECT 1 FROM public.time_logs
      WHERE user_id = NEW.user_id
        AND end_time IS NULL
        AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) THEN
      RAISE EXCEPTION 'Usuário já possui um timer ativo. Finalize o timer atual antes de iniciar um novo.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.prevent_multiple_active_timers() IS 'Previne que um usuário tenha múltiplos timers ativos simultaneamente';

-- Trigger para prevenir múltiplos timers ativos
DROP TRIGGER IF EXISTS prevent_multiple_timers_trigger ON public.time_logs;
CREATE TRIGGER prevent_multiple_timers_trigger
  BEFORE INSERT OR UPDATE ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_multiple_active_timers();

-- ============================================================================
-- PARTE 11: COMENTÁRIOS DE DOCUMENTAÇÃO
-- ============================================================================

COMMENT ON TABLE public.time_logs IS 'Registros de tempo trabalhado em tarefas pelos usuários';

COMMENT ON COLUMN public.time_logs.id IS 'Identificador único do registro de tempo';
COMMENT ON COLUMN public.time_logs.task_id IS 'ID da tarefa sendo trabalhada';
COMMENT ON COLUMN public.time_logs.user_id IS 'ID do usuário que trabalhou na tarefa';
COMMENT ON COLUMN public.time_logs.start_time IS 'Data/hora de início do trabalho';
COMMENT ON COLUMN public.time_logs.end_time IS 'Data/hora de término do trabalho (NULL = timer ativo)';
COMMENT ON COLUMN public.time_logs.duration_seconds IS 'Duração total em segundos (calculado automaticamente)';
COMMENT ON COLUMN public.time_logs.notes IS 'Notas ou descrição do trabalho realizado';
COMMENT ON COLUMN public.time_logs.created_at IS 'Data/hora de criação do registro';
COMMENT ON COLUMN public.time_logs.updated_at IS 'Data/hora da última atualização';

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================
--
-- Esta migration cria a estrutura completa de time tracking com:
-- ✅ Tabela time_logs com todas as colunas necessárias
-- ✅ Foreign keys para tasks e auth.users
-- ✅ Políticas RLS para segurança
-- ✅ Constraints de validação de dados
-- ✅ Índices para performance
-- ✅ Triggers para cálculo automático de duração
-- ✅ Prevenção de múltiplos timers ativos
-- ✅ Documentação completa
-- ============================================================================

-- Verificar se tudo foi criado corretamente
DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📊 Tabela time_logs criada';
  RAISE NOTICE '⏱️  Campo total_time_spent adicionado à tabela tasks';
  RAISE NOTICE '🔍 Índices criados para performance';
  RAISE NOTICE '🔒 RLS configurado';
  RAISE NOTICE '⚙️  Triggers e funções criados';
END $$;

