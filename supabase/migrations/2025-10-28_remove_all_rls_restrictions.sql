-- Migration: Remove all RLS restrictions - Allow all authenticated users full access
-- Date: 2025-10-28
-- Description: Remove role-based restrictions and allow all authenticated users to perform all operations
-- ⚠️ WARNING: This removes all security restrictions! Any authenticated user can do anything!

-- ============================================================================
-- CLIENT_CATEGORIES
-- ============================================================================
DROP POLICY IF EXISTS "Allow admin to delete client categories" ON public.client_categories;
DROP POLICY IF EXISTS "Allow admin and gestor to insert client categories" ON public.client_categories;
DROP POLICY IF EXISTS "Allow admin and gestor to update client categories" ON public.client_categories;

CREATE POLICY "client_categories_all" ON public.client_categories FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- CLIENTS
-- ============================================================================
DROP POLICY IF EXISTS "Users can delete clients" ON public.clients;
DROP POLICY IF EXISTS "Users can update clients" ON public.clients;

CREATE POLICY "clients_delete_all" ON public.clients FOR DELETE TO authenticated USING (true);
CREATE POLICY "clients_update_all" ON public.clients FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- EMPLOYEE_PAYMENTS
-- ============================================================================
DROP POLICY IF EXISTS "employee_payments_delete" ON public.employee_payments;
DROP POLICY IF EXISTS "employee_payments_insert" ON public.employee_payments;
DROP POLICY IF EXISTS "employee_payments_select" ON public.employee_payments;
DROP POLICY IF EXISTS "employee_payments_update" ON public.employee_payments;

CREATE POLICY "employee_payments_all" ON public.employee_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PACKAGE_ITEMS
-- ============================================================================
DROP POLICY IF EXISTS "package_items write admin/design" ON public.package_items;

CREATE POLICY "package_items_all" ON public.package_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PACKAGES
-- ============================================================================
DROP POLICY IF EXISTS "packages write admin/design" ON public.packages;

CREATE POLICY "packages_all" ON public.packages FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PAYMENTS
-- ============================================================================
DROP POLICY IF EXISTS "payments write admin/fin" ON public.payments;
DROP POLICY IF EXISTS "payments select members" ON public.payments;

CREATE POLICY "payments_all" ON public.payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PRODUCTS
-- ============================================================================
DROP POLICY IF EXISTS "products write admin/design" ON public.products;

CREATE POLICY "products_all" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PROFILES
-- ============================================================================
DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;

CREATE POLICY "profiles_select_all" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "profiles_update_all" ON public.profiles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PROJECT_ADDITIONAL_COSTS
-- ============================================================================
DROP POLICY IF EXISTS "delete costs (admin/fin)" ON public.project_additional_costs;
DROP POLICY IF EXISTS "insert costs (admin/fin)" ON public.project_additional_costs;
DROP POLICY IF EXISTS "view costs (members/owner/admin/fin)" ON public.project_additional_costs;

CREATE POLICY "project_additional_costs_all" ON public.project_additional_costs FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PROJECT_CATALOG_ITEMS
-- ============================================================================
DROP POLICY IF EXISTS "project_catalog_items write admin/design" ON public.project_catalog_items;
DROP POLICY IF EXISTS "project_catalog_items select members" ON public.project_catalog_items;

CREATE POLICY "project_catalog_items_all" ON public.project_catalog_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PROJECT_MEMBERS
-- ============================================================================
DROP POLICY IF EXISTS "project_members_delete" ON public.project_members;
DROP POLICY IF EXISTS "project_members_insert" ON public.project_members;
DROP POLICY IF EXISTS "project_members_select" ON public.project_members;
DROP POLICY IF EXISTS "project_members_update" ON public.project_members;

CREATE POLICY "project_members_all" ON public.project_members FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- PROJECTS
-- ============================================================================
DROP POLICY IF EXISTS "projects_delete" ON public.projects;
DROP POLICY IF EXISTS "projects_insert" ON public.projects;
DROP POLICY IF EXISTS "projects_select" ON public.projects;
DROP POLICY IF EXISTS "projects_update" ON public.projects;

CREATE POLICY "projects_all" ON public.projects FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- SHARED_OAUTH_TOKENS (já foi corrigido anteriormente, mas garantindo)
-- ============================================================================
DROP POLICY IF EXISTS "shared_oauth_tokens_delete" ON public.shared_oauth_tokens;

CREATE POLICY "shared_oauth_tokens_delete_all" ON public.shared_oauth_tokens FOR DELETE TO authenticated USING (true);

-- ============================================================================
-- TASK_FILES
-- ============================================================================
DROP POLICY IF EXISTS "task_files_delete" ON public.task_files;
DROP POLICY IF EXISTS "task_files_insert" ON public.task_files;
DROP POLICY IF EXISTS "task_files_select" ON public.task_files;
DROP POLICY IF EXISTS "task_files_update" ON public.task_files;

CREATE POLICY "task_files_all" ON public.task_files FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================================
-- TASKS
-- ============================================================================
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;

CREATE POLICY "tasks_all" ON public.tasks FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '⚠️ ALL RLS RESTRICTIONS REMOVED! All authenticated users now have full access to all tables!';
END $$;

