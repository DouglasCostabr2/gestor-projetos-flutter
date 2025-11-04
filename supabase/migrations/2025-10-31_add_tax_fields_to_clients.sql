-- ============================================================================
-- Migration: Add tax/fiscal fields to clients table
-- Date: 2025-10-31
-- Description: Add international tax identification fields to support invoicing
--              for clients worldwide (CPF, CNPJ, VAT, EIN, etc.)
-- ============================================================================

-- Add tax identification fields
ALTER TABLE public.clients
ADD COLUMN IF NOT EXISTS tax_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS tax_id_type VARCHAR(20),
ADD COLUMN IF NOT EXISTS legal_name TEXT;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_clients_tax_id ON public.clients(tax_id);
CREATE INDEX IF NOT EXISTS idx_clients_tax_id_type ON public.clients(tax_id_type);

-- Add comments to document the columns
COMMENT ON COLUMN public.clients.tax_id IS 'Tax identification number (CPF, CNPJ, VAT, EIN, etc.) - supports international formats';
COMMENT ON COLUMN public.clients.tax_id_type IS 'Type of tax ID: cpf, cnpj, vat, ein, tin, abn, nif, etc.';
COMMENT ON COLUMN public.clients.legal_name IS 'Legal/registered name for invoicing (Razão Social for Brazilian companies)';

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Campos adicionados à tabela clients:';
  RAISE NOTICE '   - tax_id (VARCHAR 50) - Número de identificação fiscal';
  RAISE NOTICE '   - tax_id_type (VARCHAR 20) - Tipo de ID fiscal (cpf, cnpj, vat, ein, etc.)';
  RAISE NOTICE '   - legal_name (TEXT) - Nome legal/razão social';
  RAISE NOTICE '🌍 Suporte internacional para invoicing habilitado!';
END $$;

