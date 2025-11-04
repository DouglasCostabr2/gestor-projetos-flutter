-- ============================================================================
-- Migration: Add tax/fiscal and address fields to companies table
-- Date: 2025-10-31
-- Description: Add complete fiscal and address information to companies table
--              to support invoicing for legal entities worldwide
-- ============================================================================

-- Add tax/fiscal fields
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS tax_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS tax_id_type VARCHAR(20),
ADD COLUMN IF NOT EXISTS legal_name TEXT,
ADD COLUMN IF NOT EXISTS state_registration VARCHAR(50),
ADD COLUMN IF NOT EXISTS municipal_registration VARCHAR(50);

-- Add address fields (for complete invoicing information)
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS state VARCHAR(50),
ADD COLUMN IF NOT EXISTS zip_code VARCHAR(20),
ADD COLUMN IF NOT EXISTS country VARCHAR(100);

-- Add contact fields
ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS email VARCHAR(255),
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS website VARCHAR(255);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_companies_tax_id ON public.companies(tax_id);
CREATE INDEX IF NOT EXISTS idx_companies_country ON public.companies(country);
CREATE INDEX IF NOT EXISTS idx_companies_state ON public.companies(state);

-- Add comments to document the columns
COMMENT ON COLUMN public.companies.tax_id IS 'Tax identification number (CNPJ, VAT, EIN, etc.) - supports international formats';
COMMENT ON COLUMN public.companies.tax_id_type IS 'Type of tax ID: cnpj, vat, ein, tin, abn, nif, etc.';
COMMENT ON COLUMN public.companies.legal_name IS 'Legal/registered company name (Razão Social)';
COMMENT ON COLUMN public.companies.state_registration IS 'State tax registration (Inscrição Estadual for Brazil)';
COMMENT ON COLUMN public.companies.municipal_registration IS 'Municipal tax registration (Inscrição Municipal for Brazil)';
COMMENT ON COLUMN public.companies.address IS 'Complete street address';
COMMENT ON COLUMN public.companies.city IS 'City name';
COMMENT ON COLUMN public.companies.state IS 'State/Province/Region';
COMMENT ON COLUMN public.companies.zip_code IS 'Postal/ZIP code';
COMMENT ON COLUMN public.companies.country IS 'Country name';
COMMENT ON COLUMN public.companies.email IS 'Company email address';
COMMENT ON COLUMN public.companies.phone IS 'Company phone number';
COMMENT ON COLUMN public.companies.website IS 'Company website URL';

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Campos fiscais adicionados à tabela companies:';
  RAISE NOTICE '   - tax_id, tax_id_type, legal_name';
  RAISE NOTICE '   - state_registration, municipal_registration';
  RAISE NOTICE '📍 Campos de endereço adicionados:';
  RAISE NOTICE '   - address, city, state, zip_code, country';
  RAISE NOTICE '📞 Campos de contato adicionados:';
  RAISE NOTICE '   - email, phone, website';
  RAISE NOTICE '🌍 Suporte completo para invoicing de empresas internacionais!';
END $$;

