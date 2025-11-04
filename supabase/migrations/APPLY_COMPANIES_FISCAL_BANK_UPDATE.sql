-- ============================================================================
-- SCRIPT COMPLETO: Atualização de Dados Fiscais e Bancários para Empresas
-- Data: 2025-11-03
-- Descrição: Aplica todas as mudanças necessárias para adicionar suporte
--            JSONB multi-país à tabela companies (igual às organizations)
-- ============================================================================

-- ============================================================================
-- PARTE 1: Adicionar Campos JSONB à Tabela Companies
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
-- PARTE 2: Criar Tabela de Auditoria
-- ============================================================================

-- Create companies_fiscal_bank_audit_log table
CREATE TABLE IF NOT EXISTS public.companies_fiscal_bank_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
    user_name TEXT NOT NULL,
    user_email TEXT,
    action_type TEXT NOT NULL CHECK (action_type IN ('create', 'update', 'delete')),
    country_code VARCHAR(2),
    person_type VARCHAR(20) CHECK (person_type IN ('individual', 'business')),
    changed_fields JSONB DEFAULT '{}'::jsonb,
    previous_values JSONB DEFAULT '{}'::jsonb,
    new_values JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_bank_audit_company_id 
    ON public.companies_fiscal_bank_audit_log(company_id);
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_bank_audit_user_id 
    ON public.companies_fiscal_bank_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_bank_audit_created_at 
    ON public.companies_fiscal_bank_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_bank_audit_action_type 
    ON public.companies_fiscal_bank_audit_log(action_type);
CREATE INDEX IF NOT EXISTS idx_companies_fiscal_bank_audit_country 
    ON public.companies_fiscal_bank_audit_log(country_code);

-- Add comments
COMMENT ON TABLE public.companies_fiscal_bank_audit_log IS 'Audit log for all changes to fiscal_data and bank_data in companies table';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.company_id IS 'ID of the company that was modified';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.user_id IS 'ID of the user who made the change';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.user_name IS 'Name of the user who made the change';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.user_email IS 'Email of the user who made the change';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.action_type IS 'Type of action: create, update, or delete';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.country_code IS 'ISO 3166-1 alpha-2 country code (BR, US, GB, etc.)';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.person_type IS 'Type of person: individual or business';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.changed_fields IS 'List of fields that were changed';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.previous_values IS 'Previous values before the change';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.new_values IS 'New values after the change';
COMMENT ON COLUMN public.companies_fiscal_bank_audit_log.created_at IS 'Timestamp when the change was made';

-- ============================================================================
-- PARTE 3: Configurar RLS (Row Level Security)
-- ============================================================================

-- Enable RLS
ALTER TABLE public.companies_fiscal_bank_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view audit logs for companies in their organization
CREATE POLICY "Users can view audit logs for companies in their organization"
ON public.companies_fiscal_bank_audit_log
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.companies c
    INNER JOIN public.organization_members om ON om.organization_id = c.organization_id
    WHERE c.id = companies_fiscal_bank_audit_log.company_id
    AND om.user_id = auth.uid()
    AND om.status = 'active'
  )
);

-- RLS Policy: Only admins and gestors can insert audit logs
CREATE POLICY "Only admins and gestors can insert audit logs"
ON public.companies_fiscal_bank_audit_log
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.companies c
    INNER JOIN public.organization_members om ON om.organization_id = c.organization_id
    WHERE c.id = companies_fiscal_bank_audit_log.company_id
    AND om.user_id = auth.uid()
    AND om.role IN ('admin', 'gestor', 'owner')
    AND om.status = 'active'
  )
);

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════════════════════════╗';
  RAISE NOTICE '║  ✅ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!                         ║';
  RAISE NOTICE '╚════════════════════════════════════════════════════════════════╝';
  RAISE NOTICE '';
  RAISE NOTICE '📊 RESUMO DAS MUDANÇAS:';
  RAISE NOTICE '';
  RAISE NOTICE '1️⃣  CAMPOS ADICIONADOS À TABELA companies:';
  RAISE NOTICE '   ✅ fiscal_data (JSONB) - Dados fiscais por país';
  RAISE NOTICE '   ✅ bank_data (JSONB) - Dados bancários por país';
  RAISE NOTICE '   ✅ fiscal_country (VARCHAR 2) - Código ISO do país ativo';
  RAISE NOTICE '';
  RAISE NOTICE '2️⃣  ÍNDICES CRIADOS:';
  RAISE NOTICE '   ✅ idx_companies_fiscal_data (GIN)';
  RAISE NOTICE '   ✅ idx_companies_bank_data (GIN)';
  RAISE NOTICE '   ✅ idx_companies_fiscal_country';
  RAISE NOTICE '';
  RAISE NOTICE '3️⃣  TABELA DE AUDITORIA CRIADA:';
  RAISE NOTICE '   ✅ companies_fiscal_bank_audit_log';
  RAISE NOTICE '   ✅ 5 índices para performance';
  RAISE NOTICE '   ✅ RLS habilitado com 2 políticas';
  RAISE NOTICE '';
  RAISE NOTICE '🌍 SUPORTE MULTI-PAÍS HABILITADO!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 ESTRUTURA fiscal_data:';
  RAISE NOTICE '   {';
  RAISE NOTICE '     "current_country": "BR",';
  RAISE NOTICE '     "current_person_type": "business",';
  RAISE NOTICE '     "BR": {';
  RAISE NOTICE '       "individual": { "cpf": "...", "full_name": "..." },';
  RAISE NOTICE '       "business": { "cnpj": "...", "legal_name": "...", ... }';
  RAISE NOTICE '     },';
  RAISE NOTICE '     "US": { ... }';
  RAISE NOTICE '   }';
  RAISE NOTICE '';
  RAISE NOTICE '📋 ESTRUTURA bank_data:';
  RAISE NOTICE '   {';
  RAISE NOTICE '     "BR": { "bank_name": "...", "agency": "...", "pix_key": "..." },';
  RAISE NOTICE '     "US": { "bank_name": "...", "routing_number": "...", ... },';
  RAISE NOTICE '     "payment_platforms": {';
  RAISE NOTICE '       "paypal": { "enabled": true, "value": "..." }';
  RAISE NOTICE '     }';
  RAISE NOTICE '   }';
  RAISE NOTICE '';
  RAISE NOTICE '✅ A tabela companies agora tem PARIDADE COMPLETA com organizations!';
  RAISE NOTICE '';
  RAISE NOTICE '📚 Documentação: docs/COMPANIES_FISCAL_BANK_UPDATE.md';
  RAISE NOTICE '📝 Resumo: docs/RESUMO_ATUALIZACAO_EMPRESAS.md';
  RAISE NOTICE '';
END $$;

