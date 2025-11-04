-- ============================================================================
-- Migration: Create audit log for companies fiscal and bank data changes
-- Created: 2025-11-03
-- Description: Creates audit log table to track all changes to fiscal_data 
--              and bank_data in companies table
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
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Tabela de auditoria criada: companies_fiscal_bank_audit_log';
  RAISE NOTICE '🔒 RLS habilitado com políticas de acesso';
  RAISE NOTICE '📊 Índices criados para melhor performance';
  RAISE NOTICE '';
  RAISE NOTICE '🔍 Campos de auditoria:';
  RAISE NOTICE '   - company_id: ID da empresa modificada';
  RAISE NOTICE '   - user_id, user_name, user_email: Quem fez a alteração';
  RAISE NOTICE '   - action_type: create, update, delete';
  RAISE NOTICE '   - country_code: Código do país (BR, US, GB, etc.)';
  RAISE NOTICE '   - person_type: individual ou business';
  RAISE NOTICE '   - changed_fields: Lista de campos alterados';
  RAISE NOTICE '   - previous_values: Valores anteriores';
  RAISE NOTICE '   - new_values: Valores novos';
  RAISE NOTICE '   - created_at: Data/hora da alteração';
END $$;

