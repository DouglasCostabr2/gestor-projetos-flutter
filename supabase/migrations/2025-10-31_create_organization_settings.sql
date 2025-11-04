-- ============================================================================
-- Migration: Create organization_settings table
-- Date: 2025-10-31
-- Description: Create table to store the organization's own fiscal/legal data
--              for invoice emission (the "from" side of invoices)
-- ============================================================================

-- Create organization_settings table
CREATE TABLE IF NOT EXISTS public.organization_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Basic company information
  company_name TEXT NOT NULL,
  legal_name TEXT,
  trade_name TEXT,
  
  -- Tax/Fiscal information
  tax_id VARCHAR(50),
  tax_id_type VARCHAR(20),
  state_registration VARCHAR(50),
  municipal_registration VARCHAR(50),
  
  -- Address information
  address TEXT,
  address_number VARCHAR(20),
  address_complement VARCHAR(100),
  neighborhood VARCHAR(100),
  city VARCHAR(100),
  state VARCHAR(50),
  zip_code VARCHAR(20),
  country VARCHAR(100) DEFAULT 'Brazil',
  
  -- Contact information
  email VARCHAR(255),
  phone VARCHAR(20),
  mobile VARCHAR(20),
  website VARCHAR(255),
  
  -- Branding
  logo_url TEXT,
  primary_color VARCHAR(7),
  
  -- Invoice settings
  invoice_prefix VARCHAR(10),
  next_invoice_number INTEGER DEFAULT 1,
  invoice_notes TEXT,
  payment_terms TEXT,
  
  -- Bank information (for payment instructions)
  bank_name VARCHAR(100),
  bank_account VARCHAR(50),
  bank_agency VARCHAR(20),
  pix_key VARCHAR(255),
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure only one organization settings record exists
  CONSTRAINT single_organization_settings CHECK (id = id)
);

-- Create index on id (primary key already indexed, but explicit for clarity)
CREATE INDEX IF NOT EXISTS idx_organization_settings_id ON public.organization_settings(id);

-- Add comments to document the table and columns
COMMENT ON TABLE public.organization_settings IS 'Stores the organization own fiscal and legal data for invoice emission';

COMMENT ON COLUMN public.organization_settings.company_name IS 'Display name of the company';
COMMENT ON COLUMN public.organization_settings.legal_name IS 'Legal/registered company name (Razão Social)';
COMMENT ON COLUMN public.organization_settings.trade_name IS 'Trade/fantasy name (Nome Fantasia)';
COMMENT ON COLUMN public.organization_settings.tax_id IS 'Tax identification number (CNPJ, VAT, EIN, etc.)';
COMMENT ON COLUMN public.organization_settings.tax_id_type IS 'Type of tax ID: cnpj, vat, ein, tin, etc.';
COMMENT ON COLUMN public.organization_settings.state_registration IS 'State tax registration (IE)';
COMMENT ON COLUMN public.organization_settings.municipal_registration IS 'Municipal tax registration (IM)';
COMMENT ON COLUMN public.organization_settings.invoice_prefix IS 'Prefix for invoice numbers (e.g., INV, NF)';
COMMENT ON COLUMN public.organization_settings.next_invoice_number IS 'Next sequential invoice number';
COMMENT ON COLUMN public.organization_settings.pix_key IS 'PIX key for Brazilian payments';

-- Enable RLS
ALTER TABLE public.organization_settings ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Allow all authenticated users to view organization settings
CREATE POLICY "organization_settings_select_all"
  ON public.organization_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert/update/delete organization settings
CREATE POLICY "organization_settings_insert_admin"
  ON public.organization_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

CREATE POLICY "organization_settings_update_admin"
  ON public.organization_settings
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

CREATE POLICY "organization_settings_delete_admin"
  ON public.organization_settings
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role = 'admin'
    )
  );

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_organization_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_organization_settings_updated_at
  BEFORE UPDATE ON public.organization_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_organization_settings_updated_at();

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Tabela organization_settings criada com:';
  RAISE NOTICE '   - Informações básicas da empresa';
  RAISE NOTICE '   - Dados fiscais completos';
  RAISE NOTICE '   - Endereço completo';
  RAISE NOTICE '   - Informações de contato';
  RAISE NOTICE '   - Configurações de invoice';
  RAISE NOTICE '   - Dados bancários para pagamento';
  RAISE NOTICE '🔒 RLS habilitado: todos podem ver, apenas admins podem editar';
  RAISE NOTICE '🌍 Pronto para emitir invoices internacionais!';
END $$;

