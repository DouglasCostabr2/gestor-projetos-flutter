-- Fix RLS policies for companies table to use organization-based access
-- This migration adds organization_id column and updates RLS policies for multi-tenancy

-- Step 1: Add organization_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'companies'
    AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE public.companies
    ADD COLUMN organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

    -- Create index for better performance
    CREATE INDEX IF NOT EXISTS idx_companies_organization_id ON public.companies(organization_id);

    RAISE NOTICE 'Column organization_id added to companies table';
  ELSE
    RAISE NOTICE 'Column organization_id already exists in companies table';
  END IF;
END $$;

-- Step 2: Drop existing policies
DROP POLICY IF EXISTS "Users can view their own companies" ON public.companies;
DROP POLICY IF EXISTS "Users can create companies" ON public.companies;
DROP POLICY IF EXISTS "Users can update their own companies" ON public.companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON public.companies;

-- Step 3: Create new policies with organization filtering
CREATE POLICY "Users can view companies in their organizations"
  ON public.companies
  FOR SELECT
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can insert companies in their organizations"
  ON public.companies
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can update companies in their organizations"
  ON public.companies
  FOR UPDATE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  )
  WITH CHECK (
    public.is_organization_member(organization_id)
  );

CREATE POLICY "Users can delete companies in their organizations"
  ON public.companies
  FOR DELETE
  TO authenticated
  USING (
    public.is_organization_member(organization_id)
  );

