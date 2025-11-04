-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 2: UPDATE RLS POLICIES FOR EXISTING TABLES
-- ============================================================================
-- Date: 2025-10-31
-- Description: Update RLS policies to include organization_id filtering
-- Author: System
-- ============================================================================

-- ============================================================================
-- STRATEGY:
-- 1. Drop existing policies
-- 2. Create new policies with organization_id filtering
-- 3. Maintain same permission levels but add organization context
-- ============================================================================

-- ============================================================================
-- 1. CLIENTS TABLE
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view clients" ON public.clients;
DROP POLICY IF EXISTS "Users can insert clients" ON public.clients;
DROP POLICY IF EXISTS "clients_update_all" ON public.clients;
DROP POLICY IF EXISTS "clients_delete_all" ON public.clients;
DROP POLICY IF EXISTS "clients_policy" ON public.clients;

-- Create new policies with organization filtering
CREATE POLICY "Users can view clients in their organizations"
  ON public.clients
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert clients in their organizations"
  ON public.clients
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update clients in their organizations"
  ON public.clients
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete clients in their organizations"
  ON public.clients
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 2. PROJECTS TABLE
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "projects_all" ON public.projects;
DROP POLICY IF EXISTS "projects_select_task_assignees" ON public.projects;

-- Create new policies with organization filtering
CREATE POLICY "Users can view projects in their organizations"
  ON public.projects
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert projects in their organizations"
  ON public.projects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update projects in their organizations"
  ON public.projects
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete projects in their organizations"
  ON public.projects
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 3. TASKS TABLE
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "tasks_all" ON public.tasks;
DROP POLICY IF EXISTS "Users can view tasks assigned to them (multiple)" ON public.tasks;

-- Create new policies with organization filtering
CREATE POLICY "Users can view tasks in their organizations"
  ON public.tasks
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert tasks in their organizations"
  ON public.tasks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update tasks in their organizations"
  ON public.tasks
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete tasks in their organizations"
  ON public.tasks
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 4. PRODUCTS TABLE
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "products_all" ON public.products;
DROP POLICY IF EXISTS "products select auth" ON public.products;

-- Create new policies with organization filtering
CREATE POLICY "Users can view products in their organizations"
  ON public.products
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert products in their organizations"
  ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update products in their organizations"
  ON public.products
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete products in their organizations"
  ON public.products
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 5. PACKAGES TABLE
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "packages_all" ON public.packages;
DROP POLICY IF EXISTS "packages select auth" ON public.packages;

-- Create new policies with organization filtering
CREATE POLICY "Users can view packages in their organizations"
  ON public.packages
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert packages in their organizations"
  ON public.packages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update packages in their organizations"
  ON public.packages
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete packages in their organizations"
  ON public.packages
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 6. CATALOG_CATEGORIES TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.catalog_categories ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering
CREATE POLICY "Users can view catalog categories in their organizations"
  ON public.catalog_categories
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert catalog categories in their organizations"
  ON public.catalog_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update catalog categories in their organizations"
  ON public.catalog_categories
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete catalog categories in their organizations"
  ON public.catalog_categories
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 7. CLIENT_CATEGORIES TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.client_categories ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering
CREATE POLICY "Users can view client categories in their organizations"
  ON public.client_categories
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert client categories in their organizations"
  ON public.client_categories
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update client categories in their organizations"
  ON public.client_categories
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete client categories in their organizations"
  ON public.client_categories
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 8. PAYMENTS TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering
CREATE POLICY "Users can view payments in their organizations"
  ON public.payments
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert payments in their organizations"
  ON public.payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update payments in their organizations"
  ON public.payments
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete payments in their organizations"
  ON public.payments
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 9. EMPLOYEE_PAYMENTS TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.employee_payments ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering
CREATE POLICY "Users can view employee payments in their organizations"
  ON public.employee_payments
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert employee payments in their organizations"
  ON public.employee_payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update employee payments in their organizations"
  ON public.employee_payments
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete employee payments in their organizations"
  ON public.employee_payments
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 10. NOTIFICATIONS TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering + user filtering
CREATE POLICY "Users can view their notifications in their organizations"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
    AND user_id = auth.uid()
  );

CREATE POLICY "System can insert notifications"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update their notifications"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.is_organization_member(organization_id)
  )
  WITH CHECK (
    user_id = auth.uid()
    AND public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete their notifications"
  ON public.notifications
  FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 11. USER_FAVORITES TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering + user filtering
CREATE POLICY "Users can view their favorites in their organizations"
  ON public.user_favorites
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
    AND user_id = auth.uid()
  );

CREATE POLICY "Users can insert their favorites"
  ON public.user_favorites
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
    AND user_id = auth.uid()
  );

CREATE POLICY "Users can delete their favorites"
  ON public.user_favorites
  FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.is_organization_member(organization_id)
  );

-- ============================================================================
-- 12. SHARED_OAUTH_TOKENS TABLE
-- ============================================================================

-- Enable RLS if not already enabled
ALTER TABLE public.shared_oauth_tokens ENABLE ROW LEVEL SECURITY;

-- Create policies with organization filtering
CREATE POLICY "Users can view shared tokens in their organizations"
  ON public.shared_oauth_tokens
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert shared tokens in their organizations"
  ON public.shared_oauth_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update shared tokens in their organizations"
  ON public.shared_oauth_tokens
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete shared tokens in their organizations"
  ON public.shared_oauth_tokens
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

-- ============================================================================
-- PHASE 2 - COMPLETE (ALL TABLES)
-- ============================================================================
-- Total: 59 RLS policies created/updated across 15 tables
-- - 3 new tables (organizations, organization_members, organization_invites): 12 policies
-- - 12 existing tables: 47 policies
-- All tables now have complete data isolation by organization_id
-- ============================================================================

