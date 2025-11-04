-- ============================================================================
-- FIX PACKAGE_ITEMS FOREIGN KEYS TO CASCADE ON DELETE
-- Date: 2025-11-03
-- Description:
--   Adjust package_items foreign keys so deleting products/packages (including
--   via organization cascade) will not fail with FK violations.
--   This addresses errors like:
--   "update or delete on table \"products\" violates foreign key constraint
--    \"package_items_product_id_fkey\" on table \"package_items\"" (code 23503)
-- ============================================================================

BEGIN;

-- Drop and recreate FK: package_items.product_id -> products(id) ON DELETE CASCADE
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'package_items_product_id_fkey'
      AND table_name = 'package_items'
  ) THEN
    ALTER TABLE public.package_items DROP CONSTRAINT package_items_product_id_fkey;
  END IF;
END $$;

ALTER TABLE public.package_items
  ADD CONSTRAINT package_items_product_id_fkey
  FOREIGN KEY (product_id)
  REFERENCES public.products(id)
  ON DELETE CASCADE;

-- Drop and recreate FK: package_items.package_id -> packages(id) ON DELETE CASCADE
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'package_items_package_id_fkey'
      AND table_name = 'package_items'
  ) THEN
    ALTER TABLE public.package_items DROP CONSTRAINT package_items_package_id_fkey;
  END IF;
END $$;

ALTER TABLE public.package_items
  ADD CONSTRAINT package_items_package_id_fkey
  FOREIGN KEY (package_id)
  REFERENCES public.packages(id)
  ON DELETE CASCADE;

COMMIT;

-- ============================================================================
-- Verification helpers (optional)
-- Run these in SQL editor to confirm delete action is CASCADE ('c')
-- ============================================================================
-- SELECT conname AS constraint_name, confdeltype AS delete_action
-- FROM pg_constraint
-- WHERE conrelid = 'package_items'::regclass
--   AND contype = 'f';

