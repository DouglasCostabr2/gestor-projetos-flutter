-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 1: FOUNDATION
-- ============================================================================
-- Date: 2025-10-31
-- Description: Create base tables for multi-tenancy support
-- Author: System
-- ============================================================================

-- ============================================================================
-- 1. CREATE ORGANIZATIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Basic Information
  name TEXT NOT NULL,
  slug VARCHAR(50) UNIQUE NOT NULL,
  
  -- Legal/Fiscal Data (migrated from organization_settings)
  legal_name TEXT,
  trade_name TEXT,
  tax_id_type VARCHAR(20),
  tax_id VARCHAR(50),
  state_registration VARCHAR(50),
  municipal_registration VARCHAR(50),
  
  -- Address
  address TEXT,
  address_number VARCHAR(20),
  address_complement TEXT,
  neighborhood TEXT,
  city TEXT,
  state_province TEXT,
  postal_code VARCHAR(20),
  country VARCHAR(100) DEFAULT 'Brasil',
  
  -- Contact
  email VARCHAR(255),
  phone VARCHAR(50),
  mobile VARCHAR(50),
  website TEXT,
  
  -- Branding
  logo_url TEXT,
  primary_color VARCHAR(7),
  
  -- Invoice Settings
  invoice_prefix VARCHAR(10),
  next_invoice_number INTEGER DEFAULT 1,
  invoice_notes TEXT,
  invoice_terms TEXT,
  
  -- Bank Information
  bank_name TEXT,
  bank_code VARCHAR(10),
  bank_agency VARCHAR(20),
  bank_account VARCHAR(30),
  bank_account_type VARCHAR(20),
  pix_key TEXT,
  pix_key_type VARCHAR(20),
  
  -- Ownership & Status
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT organizations_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
  CONSTRAINT organizations_slug_format CHECK (slug ~ '^[a-z0-9-]+$')
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_organizations_owner_id ON public.organizations(owner_id);
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON public.organizations(slug);
CREATE INDEX IF NOT EXISTS idx_organizations_status ON public.organizations(status);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_organizations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_organizations_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_organizations_updated_at();

COMMENT ON TABLE public.organizations IS 'Stores organization/company information for multi-tenancy';

-- ============================================================================
-- 2. CREATE ORGANIZATION_MEMBERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Role & Permissions
  role VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'admin', 'gestor', 'financeiro', 'designer', 'usuario')),
  
  -- Status
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  
  -- Metadata
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT organization_members_unique_user_org UNIQUE (organization_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_org_members_organization_id ON public.organization_members(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON public.organization_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_role ON public.organization_members(role);
CREATE INDEX IF NOT EXISTS idx_org_members_status ON public.organization_members(status);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_organization_members_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_organization_members_updated_at
  BEFORE UPDATE ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION public.update_organization_members_updated_at();

COMMENT ON TABLE public.organization_members IS 'Links users to organizations with specific roles';

-- ============================================================================
-- 3. CREATE ORGANIZATION_INVITES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organization_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  
  -- Invite Information
  email VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'gestor', 'financeiro', 'designer', 'usuario')),
  
  -- Token for security
  token VARCHAR(100) UNIQUE NOT NULL,
  
  -- Status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  
  -- Metadata
  invited_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  accepted_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT organization_invites_unique_pending UNIQUE (organization_id, email, status)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_org_invites_organization_id ON public.organization_invites(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_invites_email ON public.organization_invites(email);
CREATE INDEX IF NOT EXISTS idx_org_invites_token ON public.organization_invites(token);
CREATE INDEX IF NOT EXISTS idx_org_invites_status ON public.organization_invites(status);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_organization_invites_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_organization_invites_updated_at
  BEFORE UPDATE ON public.organization_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.update_organization_invites_updated_at();

COMMENT ON TABLE public.organization_invites IS 'Manages pending invitations to join organizations';

-- ============================================================================
-- 4. MIGRATE EXISTING DATA TO DEFAULT ORGANIZATION
-- ============================================================================

-- Create default organization from organization_settings (if exists)
DO $$
DECLARE
  v_default_org_id UUID;
  v_owner_id UUID;
  v_org_settings RECORD;
BEGIN
  -- Get first admin user as owner
  SELECT id INTO v_owner_id
  FROM auth.users
  WHERE id IN (SELECT id FROM public.profiles WHERE role = 'admin')
  LIMIT 1;
  
  -- If no admin found, get first user
  IF v_owner_id IS NULL THEN
    SELECT id INTO v_owner_id FROM auth.users LIMIT 1;
  END IF;
  
  -- Get existing organization_settings
  SELECT * INTO v_org_settings FROM public.organization_settings LIMIT 1;
  
  -- Create default organization
  IF v_org_settings IS NOT NULL THEN
    -- Use data from organization_settings
    INSERT INTO public.organizations (
      id, name, slug, legal_name, trade_name,
      tax_id_type, tax_id, state_registration, municipal_registration,
      address, address_number, address_complement, neighborhood,
      city, state_province, postal_code, country,
      email, phone, mobile, website,
      logo_url, primary_color,
      invoice_prefix, next_invoice_number, invoice_notes, invoice_terms,
      bank_name, bank_code, bank_agency, bank_account, bank_account_type,
      pix_key, pix_key_type,
      owner_id, status
    ) VALUES (
      gen_random_uuid(),
      COALESCE(v_org_settings.company_name, 'Organização Padrão'),
      'organizacao-padrao',
      v_org_settings.legal_name,
      v_org_settings.trade_name,
      v_org_settings.tax_id_type,
      v_org_settings.tax_id,
      v_org_settings.state_registration,
      v_org_settings.municipal_registration,
      v_org_settings.address,
      v_org_settings.address_number,
      v_org_settings.address_complement,
      v_org_settings.neighborhood,
      v_org_settings.city,
      v_org_settings.state_province,
      v_org_settings.postal_code,
      v_org_settings.country,
      v_org_settings.email,
      v_org_settings.phone,
      v_org_settings.mobile,
      v_org_settings.website,
      v_org_settings.logo_url,
      v_org_settings.primary_color,
      v_org_settings.invoice_prefix,
      v_org_settings.next_invoice_number,
      v_org_settings.invoice_notes,
      v_org_settings.invoice_terms,
      v_org_settings.bank_name,
      v_org_settings.bank_code,
      v_org_settings.bank_agency,
      v_org_settings.bank_account,
      v_org_settings.bank_account_type,
      v_org_settings.pix_key,
      v_org_settings.pix_key_type,
      v_owner_id,
      'active'
    )
    RETURNING id INTO v_default_org_id;
  ELSE
    -- Create minimal default organization
    INSERT INTO public.organizations (name, slug, owner_id, status)
    VALUES ('Organização Padrão', 'organizacao-padrao', v_owner_id, 'active')
    RETURNING id INTO v_default_org_id;
  END IF;
  
  -- Add all existing users as members of default organization
  INSERT INTO public.organization_members (organization_id, user_id, role, status, invited_by)
  SELECT 
    v_default_org_id,
    p.id,
    p.role,
    'active',
    v_owner_id
  FROM public.profiles p
  WHERE p.role != 'convidado'
  ON CONFLICT (organization_id, user_id) DO NOTHING;
  
  RAISE NOTICE 'Default organization created with ID: %', v_default_org_id;
END $$;

-- ============================================================================
-- PHASE 1 COMPLETE
-- ============================================================================

