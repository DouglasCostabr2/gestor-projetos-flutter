-- Migration: Fix Design Materials to use companies instead of clients
-- Created: 2025-11-08
-- Description: Changes design_folders and design_files to reference companies table instead of clients

-- Step 1: Drop existing foreign key constraints
ALTER TABLE public.design_folders 
  DROP CONSTRAINT IF EXISTS design_folders_client_id_fkey;

ALTER TABLE public.design_files 
  DROP CONSTRAINT IF EXISTS design_files_client_id_fkey;

-- Step 2: Rename columns from client_id to company_id
ALTER TABLE public.design_folders 
  RENAME COLUMN client_id TO company_id;

ALTER TABLE public.design_files 
  RENAME COLUMN client_id TO company_id;

-- Step 3: Add new foreign key constraints referencing companies table
ALTER TABLE public.design_folders 
  ADD CONSTRAINT design_folders_company_id_fkey 
  FOREIGN KEY (company_id) 
  REFERENCES public.companies(id) 
  ON DELETE CASCADE;

ALTER TABLE public.design_files 
  ADD CONSTRAINT design_files_company_id_fkey 
  FOREIGN KEY (company_id) 
  REFERENCES public.companies(id) 
  ON DELETE CASCADE;

-- Step 4: Update RLS policies to use company_id instead of client_id
-- Drop old policies
DROP POLICY IF EXISTS "Users can view design folders in their organization" ON public.design_folders;
DROP POLICY IF EXISTS "Users can create design folders in their organization" ON public.design_folders;
DROP POLICY IF EXISTS "Users can update design folders in their organization" ON public.design_folders;
DROP POLICY IF EXISTS "Users can delete design folders in their organization" ON public.design_folders;

DROP POLICY IF EXISTS "Users can view design files in their organization" ON public.design_files;
DROP POLICY IF EXISTS "Users can create design files in their organization" ON public.design_files;
DROP POLICY IF EXISTS "Users can update design files in their organization" ON public.design_files;
DROP POLICY IF EXISTS "Users can delete design files in their organization" ON public.design_files;

-- Create new policies with company_id
CREATE POLICY "Users can view design folders in their organization"
  ON public.design_folders
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create design folders in their organization"
  ON public.design_folders
  FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update design folders in their organization"
  ON public.design_folders
  FOR UPDATE
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete design folders in their organization"
  ON public.design_folders
  FOR DELETE
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view design files in their organization"
  ON public.design_files
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create design files in their organization"
  ON public.design_files
  FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update design files in their organization"
  ON public.design_files
  FOR UPDATE
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete design files in their organization"
  ON public.design_files
  FOR DELETE
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

-- Step 5: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_design_folders_company_id 
  ON public.design_folders(company_id);

CREATE INDEX IF NOT EXISTS idx_design_files_company_id 
  ON public.design_files(company_id);

