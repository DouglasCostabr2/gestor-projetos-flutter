-- Migration: Add JSONB fields for dynamic fiscal and bank data
-- Created: 2025-11-01
-- Description: Adds fiscal_data and bank_data JSONB columns to store country-specific information

-- Add fiscal_data column to store country-specific fiscal information
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS fiscal_data JSONB DEFAULT '{}'::jsonb;

-- Add bank_data column to store country-specific banking information
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS bank_data JSONB DEFAULT '{}'::jsonb;

-- Add fiscal_country column to store the selected country for fiscal/bank data
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS fiscal_country VARCHAR(2);

-- Add comments
COMMENT ON COLUMN public.organizations.fiscal_data IS 'Country-specific fiscal/tax data stored as JSON';
COMMENT ON COLUMN public.organizations.bank_data IS 'Country-specific banking data stored as JSON';
COMMENT ON COLUMN public.organizations.fiscal_country IS 'ISO 3166-1 alpha-2 country code for fiscal/bank configuration';

-- Create indexes for JSONB columns for better query performance
CREATE INDEX IF NOT EXISTS idx_organizations_fiscal_data ON public.organizations USING GIN (fiscal_data);
CREATE INDEX IF NOT EXISTS idx_organizations_bank_data ON public.organizations USING GIN (bank_data);
CREATE INDEX IF NOT EXISTS idx_organizations_fiscal_country ON public.organizations (fiscal_country);

