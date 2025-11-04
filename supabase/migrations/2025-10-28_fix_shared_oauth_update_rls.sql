-- Migration: Fix shared_oauth_tokens INSERT and UPDATE policies
-- Date: 2025-10-28
-- Description: Allow all authenticated users to insert/update shared OAuth tokens (for token refresh via UPSERT)

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "shared_oauth_tokens_insert" ON public.shared_oauth_tokens;

-- Drop existing UPDATE policy
DROP POLICY IF EXISTS "shared_oauth_tokens_update" ON public.shared_oauth_tokens;

-- Create new INSERT policy allowing all authenticated users
CREATE POLICY "shared_oauth_tokens_insert"
  ON public.shared_oauth_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create new UPDATE policy allowing all authenticated users
CREATE POLICY "shared_oauth_tokens_update"
  ON public.shared_oauth_tokens
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'RLS policies for shared_oauth_tokens INSERT and UPDATE updated successfully!';
END $$;

