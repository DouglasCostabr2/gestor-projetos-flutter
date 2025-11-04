-- ============================================================================
-- CONFIGURAÇÃO DE CRON JOBS PARA NOTIFICAÇÕES
-- ============================================================================
-- Este arquivo configura jobs periódicos usando pg_cron para:
-- 1. Verificar tarefas que vencem em breve (1 dia antes)
-- 2. Verificar tarefas vencidas
-- 3. Limpar notificações antigas
--
-- IMPORTANTE: pg_cron precisa estar habilitado no Supabase
-- Para habilitar: Dashboard > Database > Extensions > pg_cron
-- ============================================================================

-- Habilitar a extensão pg_cron (se ainda não estiver habilitada)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================================
-- 1. JOB: Verificar tarefas que vencem em breve
-- ============================================================================
-- Executa todos os dias às 9h da manhã (horário UTC)
-- Notifica usuários sobre tarefas que vencem nas próximas 24 horas

SELECT cron.schedule(
  'notify-tasks-due-soon',           -- Nome do job
  '0 9 * * *',                       -- Cron expression: 9h UTC todos os dias
  $$SELECT notify_tasks_due_soon();$$
);

-- ============================================================================
-- 2. JOB: Verificar tarefas vencidas
-- ============================================================================
-- Executa todos os dias às 10h da manhã (horário UTC)
-- Notifica usuários sobre tarefas que já venceram

SELECT cron.schedule(
  'notify-tasks-overdue',            -- Nome do job
  '0 10 * * *',                      -- Cron expression: 10h UTC todos os dias
  $$SELECT notify_tasks_overdue();$$
);

-- ============================================================================
-- 3. JOB: Limpar notificações antigas
-- ============================================================================
-- Executa todos os domingos às 3h da manhã (horário UTC)
-- Remove notificações lidas com mais de 30 dias

SELECT cron.schedule(
  'cleanup-old-notifications',       -- Nome do job
  '0 3 * * 0',                       -- Cron expression: 3h UTC aos domingos
  $$SELECT cleanup_old_notifications();$$
);

-- ============================================================================
-- COMANDOS ÚTEIS PARA GERENCIAR CRON JOBS
-- ============================================================================

-- Ver todos os jobs agendados:
-- SELECT * FROM cron.job;

-- Ver histórico de execuções:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Desabilitar um job:
-- SELECT cron.unschedule('notify-tasks-due-soon');

-- Executar um job manualmente (para teste):
-- SELECT notify_tasks_due_soon();
-- SELECT notify_tasks_overdue();
-- SELECT cleanup_old_notifications();

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================
-- 1. Os horários estão em UTC. Ajuste conforme necessário para seu timezone.
-- 2. Para alterar o horário de um job, primeiro desabilite-o com cron.unschedule()
--    e depois crie novamente com o novo horário.
-- 3. Os jobs só funcionam se as funções notify_tasks_due_soon(), 
--    notify_tasks_overdue() e cleanup_old_notifications() existirem.
-- 4. Verifique os logs em cron.job_run_details para monitorar execuções.
-- ============================================================================

