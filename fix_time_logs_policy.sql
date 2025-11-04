-- Script para corrigir a política RLS de time_logs
-- Execute este script no Supabase Dashboard > SQL Editor

-- Remove a política antiga
DROP POLICY IF EXISTS "Users can view time logs of accessible tasks" ON public.time_logs;

-- Cria a nova política (permite visualização de todos os time_logs)
CREATE POLICY "Users can view time logs of accessible tasks"
  ON public.time_logs
  FOR SELECT
  USING (true);

-- Mensagem de confirmação
SELECT 'Política de time_logs corrigida com sucesso!' as status;

