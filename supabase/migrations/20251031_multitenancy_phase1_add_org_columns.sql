-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 1: ADD ORGANIZATION_ID COLUMNS
-- ============================================================================
-- Date: 2025-10-31
-- Description: Add organization_id column to existing tables
-- Author: System
-- ============================================================================

-- ============================================================================
-- 1. ADD ORGANIZATION_ID TO CORE TABLES
-- ============================================================================

-- CLIENTS
ALTER TABLE public.clients 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- PROJECTS
ALTER TABLE public.projects 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- TASKS
ALTER TABLE public.tasks 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- PRODUCTS
ALTER TABLE public.products 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- PACKAGES
ALTER TABLE public.packages 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- CATALOG_CATEGORIES
ALTER TABLE public.catalog_categories 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- CLIENT_CATEGORIES
ALTER TABLE public.client_categories 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- PAYMENTS
ALTER TABLE public.payments 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- EMPLOYEE_PAYMENTS
ALTER TABLE public.employee_payments 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- NOTIFICATIONS
ALTER TABLE public.notifications 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- USER_FAVORITES
ALTER TABLE public.user_favorites 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- SHARED_OAUTH_TOKENS
ALTER TABLE public.shared_oauth_tokens 
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

-- ============================================================================
-- 2. POPULATE ORGANIZATION_ID WITH DEFAULT ORGANIZATION
-- ============================================================================

DO $$
DECLARE
  v_default_org_id UUID;
BEGIN
  -- Get default organization ID
  SELECT id INTO v_default_org_id 
  FROM public.organizations 
  WHERE slug = 'organizacao-padrao' 
  LIMIT 1;
  
  IF v_default_org_id IS NULL THEN
    RAISE EXCEPTION 'Default organization not found. Run phase1_foundation.sql first.';
  END IF;
  
  -- Update all existing records with default organization
  UPDATE public.clients SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.projects SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.tasks SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.products SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.packages SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.catalog_categories SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.client_categories SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.payments SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.employee_payments SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.notifications SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.user_favorites SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  UPDATE public.shared_oauth_tokens SET organization_id = v_default_org_id WHERE organization_id IS NULL;
  
  RAISE NOTICE 'All existing records updated with default organization ID: %', v_default_org_id;
END $$;

-- ============================================================================
-- 3. MAKE ORGANIZATION_ID NOT NULL (After populating)
-- ============================================================================

ALTER TABLE public.clients ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.projects ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.tasks ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.products ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.packages ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.catalog_categories ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.client_categories ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.payments ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.employee_payments ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.notifications ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.user_favorites ALTER COLUMN organization_id SET NOT NULL;
ALTER TABLE public.shared_oauth_tokens ALTER COLUMN organization_id SET NOT NULL;

-- ============================================================================
-- 4. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_clients_organization_id ON public.clients(organization_id);
CREATE INDEX IF NOT EXISTS idx_projects_organization_id ON public.projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_tasks_organization_id ON public.tasks(organization_id);
CREATE INDEX IF NOT EXISTS idx_products_organization_id ON public.products(organization_id);
CREATE INDEX IF NOT EXISTS idx_packages_organization_id ON public.packages(organization_id);
CREATE INDEX IF NOT EXISTS idx_catalog_categories_organization_id ON public.catalog_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_client_categories_organization_id ON public.client_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_payments_organization_id ON public.payments(organization_id);
CREATE INDEX IF NOT EXISTS idx_employee_payments_organization_id ON public.employee_payments(organization_id);
CREATE INDEX IF NOT EXISTS idx_notifications_organization_id ON public.notifications(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_organization_id ON public.user_favorites(organization_id);
CREATE INDEX IF NOT EXISTS idx_shared_oauth_tokens_organization_id ON public.shared_oauth_tokens(organization_id);

-- ============================================================================
-- 5. CREATE COMPOSITE INDEXES FOR COMMON QUERIES
-- ============================================================================

-- Clients: organization + status
CREATE INDEX IF NOT EXISTS idx_clients_org_status ON public.clients(organization_id, status);

-- Projects: organization + status
CREATE INDEX IF NOT EXISTS idx_projects_org_status ON public.projects(organization_id, status);

-- Tasks: organization + status
CREATE INDEX IF NOT EXISTS idx_tasks_org_status ON public.tasks(organization_id, status);

-- Tasks: organization + assigned_to (for user's tasks)
CREATE INDEX IF NOT EXISTS idx_tasks_org_assigned ON public.tasks(organization_id, assigned_to);

-- Products: organization + active
CREATE INDEX IF NOT EXISTS idx_products_org_active ON public.products(organization_id, active);

-- Packages: organization + active
CREATE INDEX IF NOT EXISTS idx_packages_org_active ON public.packages(organization_id, active);

-- Notifications: organization + user_id + read
CREATE INDEX IF NOT EXISTS idx_notifications_org_user_read ON public.notifications(organization_id, user_id, read);

-- ============================================================================
-- PHASE 1 - PART 2 COMPLETE
-- ============================================================================

-- Summary
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PHASE 1 - PART 2 COMPLETED SUCCESSFULLY';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Added organization_id to 12 tables';
  RAISE NOTICE 'Created 12 basic indexes';
  RAISE NOTICE 'Created 7 composite indexes';
  RAISE NOTICE 'All existing data migrated to default organization';
  RAISE NOTICE '========================================';
END $$;

