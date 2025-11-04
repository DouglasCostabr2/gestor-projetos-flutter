-- ============================================================================
-- FIX ORGANIZATION_INVITES RLS POLICIES
-- ============================================================================
-- Date: 2025-11-01
-- Description: Fix RLS policies that try to access auth.users table directly
--              Replace with auth.email() function which is accessible
-- Author: System
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view relevant invites" ON public.organization_invites;
DROP POLICY IF EXISTS "Users can update relevant invites" ON public.organization_invites;

-- ============================================================================
-- SELECT POLICY: Users can view invites of organizations they are owners/admins of
-- OR invites sent to their email
-- ============================================================================

CREATE POLICY "Users can view relevant invites"
  ON public.organization_invites
  FOR SELECT
  TO authenticated
  USING (
    -- Invites for organizations where user is owner/admin
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
    OR
    -- Invites sent to user's email (using auth.email() instead of SELECT from auth.users)
    email = (SELECT auth.email())
  );

-- ============================================================================
-- UPDATE POLICY: Owners/admins can update invites OR invited user can accept/reject
-- ============================================================================

CREATE POLICY "Users can update relevant invites"
  ON public.organization_invites
  FOR UPDATE
  TO authenticated
  USING (
    -- Owners/admins of the organization
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
    OR
    -- User who received the invite (using auth.email() instead of SELECT from auth.users)
    email = (SELECT auth.email())
  )
  WITH CHECK (
    -- Same conditions
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
    OR
    -- User who received the invite (using auth.email() instead of SELECT from auth.users)
    email = (SELECT auth.email())
  );

