-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 2: RLS POLICIES FOR NEW TABLES
-- ============================================================================
-- Date: 2025-10-31
-- Description: Create RLS policies for organizations, organization_members, and organization_invites
-- Author: System
-- ============================================================================

-- ============================================================================
-- 1. ENABLE RLS ON NEW TABLES
-- ============================================================================

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_invites ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. RLS POLICIES FOR ORGANIZATIONS
-- ============================================================================

-- SELECT: Users can view organizations they are members of
CREATE POLICY "Users can view their organizations"
  ON public.organizations
  FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND status = 'active'
    )
  );

-- INSERT: Authenticated users can create organizations (they become owner)
CREATE POLICY "Users can create organizations"
  ON public.organizations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = owner_id
  );

-- UPDATE: Only owners and admins can update organization
CREATE POLICY "Owners and admins can update organizations"
  ON public.organizations
  FOR UPDATE
  TO authenticated
  USING (
    id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  )
  WITH CHECK (
    id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  );

-- DELETE: Only owners can delete organizations
CREATE POLICY "Only owners can delete organizations"
  ON public.organizations
  FOR DELETE
  TO authenticated
  USING (
    owner_id = auth.uid()
  );

-- ============================================================================
-- 3. RLS POLICIES FOR ORGANIZATION_MEMBERS
-- ============================================================================

-- SELECT: Users can view members of organizations they belong to
CREATE POLICY "Users can view members of their organizations"
  ON public.organization_members
  FOR SELECT
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND status = 'active'
    )
  );

-- INSERT: Only owners and admins can add members
CREATE POLICY "Owners and admins can add members"
  ON public.organization_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  );

-- UPDATE: Only owners and admins can update members
CREATE POLICY "Owners and admins can update members"
  ON public.organization_members
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  );

-- DELETE: Only owners and admins can remove members (but not the owner)
CREATE POLICY "Owners and admins can remove members"
  ON public.organization_members
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
    AND role != 'owner' -- Cannot remove owner
  );

-- ============================================================================
-- 4. RLS POLICIES FOR ORGANIZATION_INVITES
-- ============================================================================

-- SELECT: Users can view invites of organizations they are owners/admins of
-- OR invites sent to their email
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
    -- Invites sent to user's email
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

-- INSERT: Only owners and admins can create invites
CREATE POLICY "Owners and admins can create invites"
  ON public.organization_invites
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
    AND invited_by = auth.uid()
  );

-- UPDATE: Owners/admins can update invites OR invited user can accept/reject
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
    -- User who received the invite
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
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
    email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

-- DELETE: Only owners and admins can delete invites
CREATE POLICY "Owners and admins can delete invites"
  ON public.organization_invites
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid() 
        AND role IN ('owner', 'admin')
        AND status = 'active'
    )
  );

-- ============================================================================
-- 5. CREATE HELPER FUNCTION FOR ORGANIZATION MEMBERSHIP CHECK
-- ============================================================================

-- Function to check if user is member of an organization
CREATE OR REPLACE FUNCTION public.is_organization_member(org_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.organization_members 
    WHERE organization_id = org_id 
      AND user_id = auth.uid() 
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has specific role in organization
CREATE OR REPLACE FUNCTION public.has_organization_role(org_id UUID, required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.organization_members 
    WHERE organization_id = org_id 
      AND user_id = auth.uid() 
      AND role = required_role
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has any of the specified roles in organization
CREATE OR REPLACE FUNCTION public.has_any_organization_role(org_id UUID, required_roles TEXT[])
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.organization_members 
    WHERE organization_id = org_id 
      AND user_id = auth.uid() 
      AND role = ANY(required_roles)
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PHASE 2 - PART 1 COMPLETE
-- ============================================================================

COMMENT ON POLICY "Users can view their organizations" ON public.organizations IS 
  'Users can view organizations they are active members of';

COMMENT ON POLICY "Users can create organizations" ON public.organizations IS 
  'Any authenticated user can create an organization and becomes the owner';

COMMENT ON POLICY "Owners and admins can update organizations" ON public.organizations IS 
  'Only owners and admins can update organization details';

COMMENT ON POLICY "Only owners can delete organizations" ON public.organizations IS 
  'Only the organization owner can delete the organization';

