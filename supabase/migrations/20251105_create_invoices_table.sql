-- ============================================================================
-- Migration: Create invoices table for tracking invoice numbers
-- Date: 2025-11-05
-- Description: Create table to store invoice metadata and track sequential numbering per organization per year
-- ============================================================================

-- Create invoices table
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  
  -- Invoice Number Components
  invoice_year INTEGER NOT NULL,
  invoice_sequence INTEGER NOT NULL,
  invoice_number TEXT NOT NULL, -- Format: YYYY-NNNN (e.g., 2025-0001)
  
  -- PDF Storage
  pdf_url TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Constraints
  CONSTRAINT invoices_unique_org_year_seq UNIQUE (organization_id, invoice_year, invoice_sequence),
  CONSTRAINT invoices_unique_org_number UNIQUE (organization_id, invoice_number)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_invoices_organization_id ON public.invoices(organization_id);
CREATE INDEX IF NOT EXISTS idx_invoices_project_id ON public.invoices(project_id);
CREATE INDEX IF NOT EXISTS idx_invoices_year ON public.invoices(invoice_year);
CREATE INDEX IF NOT EXISTS idx_invoices_org_year ON public.invoices(organization_id, invoice_year);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON public.invoices(created_at DESC);

-- Add comments
COMMENT ON TABLE public.invoices IS 'Stores invoice metadata and tracks sequential numbering per organization per year';
COMMENT ON COLUMN public.invoices.invoice_year IS 'Year of the invoice (e.g., 2025)';
COMMENT ON COLUMN public.invoices.invoice_sequence IS 'Sequential number within the year (e.g., 1, 2, 3...)';
COMMENT ON COLUMN public.invoices.invoice_number IS 'Full invoice number in format YYYY-NNNN (e.g., 2025-0001)';
COMMENT ON COLUMN public.invoices.pdf_url IS 'URL to the generated PDF in Supabase Storage (optional)';

-- Enable RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view invoices from their organizations
CREATE POLICY "invoices_select_own_org"
  ON public.invoices
  FOR SELECT
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
    )
  );

-- Users can insert invoices for their organizations (if they have permission)
CREATE POLICY "invoices_insert_own_org"
  ON public.invoices
  FOR INSERT
  TO authenticated
  WITH CHECK (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'gestor', 'financeiro')
    )
  );

-- Users can update invoices for their organizations (if they have permission)
CREATE POLICY "invoices_update_own_org"
  ON public.invoices
  FOR UPDATE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'gestor', 'financeiro')
    )
  );

-- Users can delete invoices for their organizations (if they have permission)
CREATE POLICY "invoices_delete_own_org"
  ON public.invoices
  FOR DELETE
  TO authenticated
  USING (
    organization_id IN (
      SELECT organization_id 
      FROM public.organization_members 
      WHERE user_id = auth.uid()
      AND role IN ('admin', 'gestor')
    )
  );

-- Function to get next invoice number for an organization in a given year
CREATE OR REPLACE FUNCTION public.get_next_invoice_number(
  p_organization_id UUID,
  p_year INTEGER DEFAULT EXTRACT(YEAR FROM NOW())::INTEGER
)
RETURNS TABLE (
  invoice_year INTEGER,
  invoice_sequence INTEGER,
  invoice_number TEXT
) AS $$
DECLARE
  v_next_sequence INTEGER;
BEGIN
  -- Get the maximum sequence number for this organization and year
  SELECT COALESCE(MAX(invoice_sequence), 0) + 1
  INTO v_next_sequence
  FROM public.invoices
  WHERE organization_id = p_organization_id
    AND invoice_year = p_year;
  
  -- Return the next invoice number
  RETURN QUERY
  SELECT 
    p_year AS invoice_year,
    v_next_sequence AS invoice_sequence,
    p_year::TEXT || '-' || LPAD(v_next_sequence::TEXT, 4, '0') AS invoice_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_next_invoice_number IS 'Returns the next available invoice number for an organization in a given year';

