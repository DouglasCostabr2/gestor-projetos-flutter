-- ============================================================================
-- Migration: Add JSONB fields for dynamic fiscal and bank data to companies
-- Created: 2025-11-03
-- Description: Adds fiscal_data and bank_data JSONB columns to companies table
--              to store country-specific information (same as organizations)
-- ============================================================================

-- Add fiscal_data column to store country-specific fiscal information
ALTER TABLE public.companies 
ADD COLUMN IF NOT EXISTS fiscal_data JSONB DEFAULT '{}'::jsonb;

-- Add bank_data column to store country-specific banking information
ALTER TABLE public.companies 
ADD COLUMN IF NOT EXISTS bank_data JSONB DEFAULT '{}'::jsonb;

-- Add fiscal_country column to store the selected country for fiscal/bank data
ALTER TABLE public.companies 
ADD COLUMN IF NOT EXISTS fiscal_country VARCHAR(2);

-- Add comments
COMMENT ON COLUMN public.companies.fiscal_data IS 'Country-specific fiscal/tax data stored as JSON (individual/business per country)';
COMMENT ON COLUMN public.companies.bank_data IS 'Country-specific banking data stored as JSON';
COMMENT ON COLUMN public.companies.fiscal_country IS 'ISO 3166-1 alpha-2 country code for fiscal/bank configuration';

-- Create indexes for JSONB columns for better query performance
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_data ON public.companies USING GIN (fiscal_data);
CREATE INDEX IF NOT EXISTS idx_companies_bank_data ON public.companies USING GIN (bank_data);
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_country ON public.companies (fiscal_country);

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Campos JSONB adicionados à tabela companies:';
  RAISE NOTICE '   - fiscal_data (JSONB) - Dados fiscais por país (individual/business)';
  RAISE NOTICE '   - bank_data (JSONB) - Dados bancários por país';
  RAISE NOTICE '   - fiscal_country (VARCHAR 2) - Código ISO do país ativo';
  RAISE NOTICE '🌍 Suporte multi-país habilitado para empresas!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estrutura fiscal_data:';
  RAISE NOTICE '   {';
  RAISE NOTICE '     "currentCountry": "BR",';
  RAISE NOTICE '     "currentPersonType": "business",';
  RAISE NOTICE '     "BR": {';
  RAISE NOTICE '       "individual": { "cpf": "...", "full_name": "..." },';
  RAISE NOTICE '       "business": { "cnpj": "...", "legal_name": "...", ... }';
  RAISE NOTICE '     },';
  RAISE NOTICE '     "US": { ... }';
  RAISE NOTICE '   }';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estrutura bank_data:';
  RAISE NOTICE '   {';
  RAISE NOTICE '     "BR": { "bank_name": "...", "agency": "...", "account": "...", "pix_key": "..." },';
  RAISE NOTICE '     "US": { "bank_name": "...", "routing_number": "...", "account_number": "..." }';
  RAISE NOTICE '   }';
END $$;

