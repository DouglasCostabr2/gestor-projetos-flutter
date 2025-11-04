-- Migration: Add 'neutro' status to clients
-- Date: 2025-10-29
-- Description: Add 'neutro' status for clients with lack of response but not fully discarded

-- Drop existing constraint
ALTER TABLE clients DROP CONSTRAINT IF EXISTS clients_status_check;

-- Add new constraint with 'neutro' status
ALTER TABLE clients 
ADD CONSTRAINT clients_status_check 
CHECK (status IN ('nao_prospectado', 'em_prospeccao', 'prospeccao_negada', 'neutro', 'ativo', 'desativado'));

-- Update comment to document the new status
COMMENT ON COLUMN clients.status IS 'Status de prospecção do cliente: nao_prospectado (aguardando contato), em_prospeccao (sendo prospectado), prospeccao_negada (recusou proposta), neutro (sem resposta/interesse incerto), ativo (cliente ativo), desativado (cliente desativado)';

