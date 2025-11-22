-- ============================================================================
-- Migration: Create Design Materials System
-- Date: 2025-11-08
-- Description: Create tables for managing client design materials (logos, 
--              brand assets, etc.) with folder organization, tagging, and 
--              Google Drive integration
-- ============================================================================

-- ============================================================================
-- 1. DESIGN_TAGS TABLE
-- ============================================================================
-- Tags that can be applied to both folders and files
CREATE TABLE IF NOT EXISTS public.design_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  color VARCHAR(7), -- Hex color code (e.g., #FF5733)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Prevent duplicate tag names within an organization
  CONSTRAINT unique_tag_name_per_org UNIQUE (organization_id, name)
);

-- Index for faster tag lookups
CREATE INDEX idx_design_tags_org ON public.design_tags(organization_id);

COMMENT ON TABLE public.design_tags IS 'Tags for organizing design materials (folders and files)';

-- ============================================================================
-- 2. DESIGN_FOLDERS TABLE
-- ============================================================================
-- Folders for organizing design materials (supports nested structure)
CREATE TABLE IF NOT EXISTS public.design_folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  parent_folder_id UUID REFERENCES public.design_folders(id) ON DELETE CASCADE,
  
  -- Folder details
  name VARCHAR(255) NOT NULL,
  description TEXT,
  
  -- Google Drive integration
  drive_folder_id VARCHAR(255), -- Google Drive folder ID
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX idx_design_folders_client ON public.design_folders(client_id);
CREATE INDEX idx_design_folders_parent ON public.design_folders(parent_folder_id);
CREATE INDEX idx_design_folders_org ON public.design_folders(organization_id);
CREATE INDEX idx_design_folders_drive ON public.design_folders(drive_folder_id);

COMMENT ON TABLE public.design_folders IS 'Folders for organizing client design materials with Google Drive sync';
COMMENT ON COLUMN public.design_folders.drive_folder_id IS 'Google Drive folder ID for sync';

-- ============================================================================
-- 3. DESIGN_FILES TABLE
-- ============================================================================
-- Files stored in design folders
CREATE TABLE IF NOT EXISTS public.design_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  folder_id UUID REFERENCES public.design_folders(id) ON DELETE CASCADE,
  
  -- File details
  filename VARCHAR(255) NOT NULL,
  file_size_bytes BIGINT,
  mime_type VARCHAR(100),
  description TEXT,
  
  -- Google Drive integration
  drive_file_id VARCHAR(255) NOT NULL, -- Google Drive file ID
  drive_file_url TEXT, -- Public view URL
  drive_thumbnail_url TEXT, -- Thumbnail URL
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX idx_design_files_client ON public.design_files(client_id);
CREATE INDEX idx_design_files_folder ON public.design_files(folder_id);
CREATE INDEX idx_design_files_org ON public.design_files(organization_id);
CREATE INDEX idx_design_files_drive ON public.design_files(drive_file_id);

COMMENT ON TABLE public.design_files IS 'Design material files with Google Drive sync';
COMMENT ON COLUMN public.design_files.drive_file_id IS 'Google Drive file ID for sync';

-- ============================================================================
-- 4. DESIGN_FOLDER_TAGS TABLE (Many-to-Many)
-- ============================================================================
-- Junction table for folder-tag relationships
CREATE TABLE IF NOT EXISTS public.design_folder_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id UUID NOT NULL REFERENCES public.design_folders(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES public.design_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate tags on same folder
  CONSTRAINT unique_folder_tag UNIQUE (folder_id, tag_id)
);

-- Indexes for performance
CREATE INDEX idx_design_folder_tags_folder ON public.design_folder_tags(folder_id);
CREATE INDEX idx_design_folder_tags_tag ON public.design_folder_tags(tag_id);

COMMENT ON TABLE public.design_folder_tags IS 'Tags applied to design folders';

-- ============================================================================
-- 5. DESIGN_FILE_TAGS TABLE (Many-to-Many)
-- ============================================================================
-- Junction table for file-tag relationships
CREATE TABLE IF NOT EXISTS public.design_file_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id UUID NOT NULL REFERENCES public.design_files(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES public.design_tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate tags on same file
  CONSTRAINT unique_file_tag UNIQUE (file_id, tag_id)
);

-- Indexes for performance
CREATE INDEX idx_design_file_tags_file ON public.design_file_tags(file_id);
CREATE INDEX idx_design_file_tags_tag ON public.design_file_tags(tag_id);

COMMENT ON TABLE public.design_file_tags IS 'Tags applied to design files';

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.design_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_folder_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_file_tags ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: design_tags
-- ============================================================================

CREATE POLICY "Users can view tags in their organizations"
  ON public.design_tags
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

CREATE POLICY "Users can create tags in their organizations"
  ON public.design_tags
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can update tags in their organizations"
  ON public.design_tags
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can delete tags in their organizations"
  ON public.design_tags
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

-- ============================================================================
-- RLS POLICIES: design_folders
-- ============================================================================

CREATE POLICY "Users can view folders in their organizations"
  ON public.design_folders
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

CREATE POLICY "Users can create folders in their organizations"
  ON public.design_folders
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can update folders in their organizations"
  ON public.design_folders
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can delete folders in their organizations"
  ON public.design_folders
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

-- ============================================================================
-- RLS POLICIES: design_files
-- ============================================================================

CREATE POLICY "Users can view files in their organizations"
  ON public.design_files
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

CREATE POLICY "Users can create files in their organizations"
  ON public.design_files
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can update files in their organizations"
  ON public.design_files
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

CREATE POLICY "Users can delete files in their organizations"
  ON public.design_files
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id
      FROM public.organization_members
      WHERE user_id = auth.uid()
        AND status = 'active'
    )
  );

-- ============================================================================
-- RLS POLICIES: design_folder_tags & design_file_tags
-- ============================================================================

-- Folder tags
CREATE POLICY "Users can view folder tags in their organizations"
  ON public.design_folder_tags
  FOR SELECT
  TO authenticated
  USING (
    folder_id IN (
      SELECT id FROM public.design_folders
      WHERE organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
    )
  );

CREATE POLICY "Users can manage folder tags in their organizations"
  ON public.design_folder_tags
  FOR ALL
  TO authenticated
  USING (
    folder_id IN (
      SELECT id FROM public.design_folders
      WHERE organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
    )
  );

-- File tags
CREATE POLICY "Users can view file tags in their organizations"
  ON public.design_file_tags
  FOR SELECT
  TO authenticated
  USING (
    file_id IN (
      SELECT id FROM public.design_files
      WHERE organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
    )
  );

CREATE POLICY "Users can manage file tags in their organizations"
  ON public.design_file_tags
  FOR ALL
  TO authenticated
  USING (
    file_id IN (
      SELECT id FROM public.design_files
      WHERE organization_id IN (
        SELECT organization_id
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
    )
  );

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DESIGN MATERIALS SYSTEM CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Created tables:';
  RAISE NOTICE '  - design_tags';
  RAISE NOTICE '  - design_folders';
  RAISE NOTICE '  - design_files';
  RAISE NOTICE '  - design_folder_tags';
  RAISE NOTICE '  - design_file_tags';
  RAISE NOTICE 'Features:';
  RAISE NOTICE '  - Nested folder structure';
  RAISE NOTICE '  - Tag system for folders and files';
  RAISE NOTICE '  - Google Drive integration';
  RAISE NOTICE '  - RLS policies for multi-tenancy';
  RAISE NOTICE '========================================';
END $$;

