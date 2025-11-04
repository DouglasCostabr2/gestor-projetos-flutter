-- Migration: Add status field to clients table
-- Date: 2025-10-29
-- Description: Add status field to track client prospecting stage

-- Create ENUM type for client status
CREATE TYPE client_status AS ENUM (
  'nao_prospectado',
  'em_prospeccao',
  'prospeccao_negada',
  'ativo',
  'desativado'
);

-- Add status column to clients table
ALTER TABLE clients
ADD COLUMN status client_status NOT NULL DEFAULT 'nao_prospectado';

-- Add index for better query performance when filtering by status
CREATE INDEX idx_clients_status ON clients(status);

-- Add comment to document the column
COMMENT ON COLUMN clients.status IS 'Status de prospecção do cliente: nao_prospectado (aguardando contato), em_prospeccao (sendo prospectado), prospeccao_negada (recusou proposta), ativo (cliente ativo), desativado (cliente desativado)';

