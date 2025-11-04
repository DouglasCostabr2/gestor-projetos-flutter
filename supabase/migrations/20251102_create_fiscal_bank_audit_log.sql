-- =====================================================
-- Migration: Create Fiscal & Bank Audit Log System
-- Description: Creates audit log table to track all changes
--              to fiscal and banking data with full traceability
-- Date: 2025-11-02
-- =====================================================

-- Create fiscal_bank_audit_log table
CREATE TABLE IF NOT EXISTS public.fiscal_bank_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
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
CREATE INDEX IF NOT EXISTS idx_fiscal_bank_audit_log_org_id 
    ON public.fiscal_bank_audit_log(organization_id);

CREATE INDEX IF NOT EXISTS idx_fiscal_bank_audit_log_user_id 
    ON public.fiscal_bank_audit_log(user_id);

CREATE INDEX IF NOT EXISTS idx_fiscal_bank_audit_log_created_at 
    ON public.fiscal_bank_audit_log(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fiscal_bank_audit_log_country_code 
    ON public.fiscal_bank_audit_log(country_code);

-- Create composite index for common queries
CREATE INDEX IF NOT EXISTS idx_fiscal_bank_audit_log_org_created 
    ON public.fiscal_bank_audit_log(organization_id, created_at DESC);

-- Add comments for documentation
COMMENT ON TABLE public.fiscal_bank_audit_log IS 
    'Audit log for tracking all changes to fiscal and banking data';

COMMENT ON COLUMN public.fiscal_bank_audit_log.organization_id IS 
    'Organization that owns the fiscal/bank data';

COMMENT ON COLUMN public.fiscal_bank_audit_log.user_id IS 
    'User who made the change';

COMMENT ON COLUMN public.fiscal_bank_audit_log.user_name IS 
    'Name of the user at the time of change (for quick reference)';

COMMENT ON COLUMN public.fiscal_bank_audit_log.user_email IS 
    'Email of the user at the time of change (for quick reference)';

COMMENT ON COLUMN public.fiscal_bank_audit_log.action_type IS 
    'Type of action: create, update, or delete';

COMMENT ON COLUMN public.fiscal_bank_audit_log.country_code IS 
    'ISO 3166-1 alpha-2 country code that was modified';

COMMENT ON COLUMN public.fiscal_bank_audit_log.person_type IS 
    'Type of person: individual (Pessoa Física) or business (Pessoa Jurídica)';

COMMENT ON COLUMN public.fiscal_bank_audit_log.changed_fields IS 
    'List of field names that were changed';

COMMENT ON COLUMN public.fiscal_bank_audit_log.previous_values IS 
    'Previous values of the changed fields (before update)';

COMMENT ON COLUMN public.fiscal_bank_audit_log.new_values IS 
    'New values of the changed fields (after update)';

COMMENT ON COLUMN public.fiscal_bank_audit_log.created_at IS 
    'Timestamp when the change was made';

-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS
ALTER TABLE public.fiscal_bank_audit_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view audit logs for their organizations
CREATE POLICY "Users can view audit logs for their organizations"
    ON public.fiscal_bank_audit_log
    FOR SELECT
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM public.organization_members 
            WHERE user_id = auth.uid()
        )
    );

-- Policy: Only system can insert audit logs (via service role)
-- This prevents users from manually creating fake audit entries
CREATE POLICY "Only authenticated users can insert audit logs"
    ON public.fiscal_bank_audit_log
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id
        AND organization_id IN (
            SELECT organization_id 
            FROM public.organization_members 
            WHERE user_id = auth.uid()
        )
    );

-- Policy: Audit logs cannot be updated (immutable)
-- No UPDATE policy = no one can update audit logs

-- Policy: Audit logs cannot be deleted by users
-- Only admins via service role can delete if needed
CREATE POLICY "Only organization owners can delete audit logs"
    ON public.fiscal_bank_audit_log
    FOR DELETE
    USING (
        organization_id IN (
            SELECT id 
            FROM public.organizations 
            WHERE owner_id = auth.uid()
        )
    );

-- =====================================================
-- Helper Function: Get Latest Audit Entry
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_latest_fiscal_bank_audit(
    p_organization_id UUID
)
RETURNS TABLE (
    user_name TEXT,
    user_email TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    country_code VARCHAR(2),
    person_type VARCHAR(20)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.user_name,
        a.user_email,
        a.created_at,
        a.country_code,
        a.person_type
    FROM public.fiscal_bank_audit_log a
    WHERE a.organization_id = p_organization_id
    ORDER BY a.created_at DESC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_latest_fiscal_bank_audit IS 
    'Returns the most recent audit entry for an organization';

-- =====================================================
-- Helper Function: Get Audit History
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_fiscal_bank_audit_history(
    p_organization_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    user_name TEXT,
    user_email TEXT,
    action_type TEXT,
    country_code VARCHAR(2),
    person_type VARCHAR(20),
    changed_fields JSONB,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.user_name,
        a.user_email,
        a.action_type,
        a.country_code,
        a.person_type,
        a.changed_fields,
        a.created_at
    FROM public.fiscal_bank_audit_log a
    WHERE a.organization_id = p_organization_id
    ORDER BY a.created_at DESC
    LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_fiscal_bank_audit_history IS 
    'Returns audit history for an organization (default: last 50 entries)';

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.get_latest_fiscal_bank_audit TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_fiscal_bank_audit_history TO authenticated;

