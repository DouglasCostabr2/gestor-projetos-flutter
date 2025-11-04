-- Fix RLS policies for organizations table
-- This migration ensures users can create organizations

-- Drop existing INSERT policy if it exists
DROP POLICY IF EXISTS "Users can create organizations" ON public.organizations;

-- Recreate INSERT policy with proper checks
CREATE POLICY "Users can create organizations"
  ON public.organizations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User must be authenticated and setting themselves as owner
    auth.uid() IS NOT NULL AND
    auth.uid() = owner_id
  );

-- Verify the policy is working by checking if authenticated users can insert
-- The policy should allow any authenticated user to create an organization
-- where they are the owner

