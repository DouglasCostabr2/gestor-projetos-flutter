-- ============================================================================
-- Migration: Add total_additional_costs_cents to get_company_projects_with_stats
-- Created: 2025-11-09
-- Description: Updates the RPC function to include additional costs in the aggregation
-- ============================================================================

-- Drop the existing function
DROP FUNCTION IF EXISTS public.get_company_projects_with_stats(UUID);

-- Recreate the function with total_additional_costs_cents
CREATE OR REPLACE FUNCTION public.get_company_projects_with_stats(company_id_param UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  status TEXT,
  start_date DATE,
  due_date DATE,
  priority TEXT,
  client_id UUID,
  company_id UUID,
  owner_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  client_name TEXT,
  client_company TEXT,
  client_avatar_url TEXT,
  owner_full_name TEXT,
  owner_avatar_url TEXT,
  updated_by_full_name TEXT,
  updated_by_avatar_url TEXT,
  pending_tasks_count BIGINT,
  total_catalog_value_cents BIGINT,
  total_additional_costs_cents BIGINT,
  total_received_cents BIGINT,
  task_assignees JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.name::TEXT,
    p.description::TEXT,
    p.status::TEXT,
    p.start_date,
    p.due_date,
    p.priority::TEXT,
    p.client_id,
    p.company_id,
    p.owner_id,
    p.created_at,
    p.updated_at,
    p.created_by,
    p.updated_by,
    -- Dados do cliente
    c.name::TEXT AS client_name,
    c.company::TEXT AS client_company,
    c.avatar_url::TEXT AS client_avatar_url,
    -- Dados do owner
    owner.full_name::TEXT AS owner_full_name,
    owner.avatar_url::TEXT AS owner_avatar_url,
    -- Dados do updated_by
    updater.full_name::TEXT AS updated_by_full_name,
    updater.avatar_url::TEXT AS updated_by_avatar_url,
    -- Estatisticas agregadas
    (
      SELECT COUNT(*)::BIGINT
      FROM tasks t
      WHERE t.project_id = p.id
        AND t.status != 'completed'
    ) AS pending_tasks_count,
    (
      SELECT COALESCE(SUM(pci.unit_price_cents * pci.quantity), 0)::BIGINT
      FROM project_catalog_items pci
      WHERE pci.project_id = p.id
    ) AS total_catalog_value_cents,
    (
      SELECT COALESCE(SUM(pac.amount_cents), 0)::BIGINT
      FROM project_additional_costs pac
      WHERE pac.project_id = p.id
    ) AS total_additional_costs_cents,
    (
      SELECT COALESCE(SUM(pay.amount_cents), 0)::BIGINT
      FROM payments pay
      WHERE pay.project_id = p.id
    ) AS total_received_cents,
    (
      SELECT COALESCE(
        jsonb_agg(
          DISTINCT jsonb_build_object(
            'id', prof.id,
            'full_name', prof.full_name,
            'avatar_url', prof.avatar_url
          )
        ),
        '[]'::jsonb
      )
      FROM tasks t
      INNER JOIN profiles prof ON prof.id = t.assigned_to
      WHERE t.project_id = p.id
        AND t.assigned_to IS NOT NULL
    ) AS task_assignees
  FROM projects p
  LEFT JOIN clients c ON c.id = p.client_id
  LEFT JOIN profiles owner ON owner.id = p.owner_id
  LEFT JOIN profiles updater ON updater.id = p.updated_by
  WHERE p.company_id = company_id_param
  ORDER BY p.created_at DESC;
END;
$$;

-- Add comment to document the function
COMMENT ON FUNCTION public.get_company_projects_with_stats IS 
'Returns projects for a company with aggregated statistics including catalog items, additional costs, and payments';

