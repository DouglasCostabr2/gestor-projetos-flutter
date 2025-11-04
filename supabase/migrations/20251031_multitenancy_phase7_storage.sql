-- ============================================================================
-- MULTI-TENANCY IMPLEMENTATION - PHASE 7: STORAGE
-- ============================================================================
-- Date: 2025-10-31
-- Description: Implement organization-based file isolation in Supabase Storage
-- Author: System
-- ============================================================================

-- ============================================================================
-- ESTRATÉGIA DE ISOLAMENTO
-- ============================================================================
-- 
-- Em vez de criar buckets separados por organização (complexo e limitado),
-- vamos usar uma estrutura de pastas dentro dos buckets existentes:
--
-- ANTES:
-- - avatars/avatar-username.jpg
-- - client-avatars/avatar-clientname.jpg
-- - product-thumbnails/thumb-productname.jpg
--
-- DEPOIS:
-- - avatars/{organization_id}/avatar-username.jpg
-- - client-avatars/{organization_id}/avatar-clientname.jpg
-- - product-thumbnails/{organization_id}/thumb-productname.jpg
--
-- Políticas RLS garantem que usuários só acessem arquivos de suas organizações.
--
-- ============================================================================

-- ============================================================================
-- 1. CRIAR POLÍTICAS RLS PARA BUCKET 'avatars'
-- ============================================================================

-- Remover políticas antigas
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
DROP POLICY IF EXISTS "avatars_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_policy" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_policy" ON storage.objects;

-- Política: Usuários podem ver avatars de suas organizações
CREATE POLICY "Users can view avatars in their organizations"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      -- Extrair organization_id do path (formato: {org_id}/avatar-username.jpg)
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      -- Permitir acesso a avatars sem organization_id (legado)
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem fazer upload de avatars em suas organizações
CREATE POLICY "Users can upload avatars in their organizations"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      -- Verificar se o organization_id no path pertence ao usuário
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      -- Permitir upload sem organization_id (legado)
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem atualizar avatars em suas organizações
CREATE POLICY "Users can update avatars in their organizations"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem deletar avatars em suas organizações
CREATE POLICY "Users can delete avatars in their organizations"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- ============================================================================
-- 2. CRIAR POLÍTICAS RLS PARA BUCKET 'client-avatars'
-- ============================================================================

DROP POLICY IF EXISTS "client_avatars_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "client_avatars_insert_policy" ON storage.objects;
DROP POLICY IF EXISTS "client_avatars_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "client_avatars_delete_policy" ON storage.objects;

-- Política: Usuários podem ver avatars de clientes de suas organizações
CREATE POLICY "Users can view client avatars in their organizations"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'client-avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem fazer upload de avatars de clientes em suas organizações
CREATE POLICY "Users can upload client avatars in their organizations"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'client-avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem atualizar avatars de clientes em suas organizações
CREATE POLICY "Users can update client avatars in their organizations"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'client-avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  )
  WITH CHECK (
    bucket_id = 'client-avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem deletar avatars de clientes em suas organizações
CREATE POLICY "Users can delete client avatars in their organizations"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'client-avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- ============================================================================
-- 3. CRIAR POLÍTICAS RLS PARA BUCKET 'product-thumbnails'
-- ============================================================================

DROP POLICY IF EXISTS "product_thumbnails_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "product_thumbnails_insert_policy" ON storage.objects;
DROP POLICY IF EXISTS "product_thumbnails_update_policy" ON storage.objects;
DROP POLICY IF EXISTS "product_thumbnails_delete_policy" ON storage.objects;

-- Política: Usuários podem ver miniaturas de produtos de suas organizações
CREATE POLICY "Users can view product thumbnails in their organizations"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'product-thumbnails'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- Política: Usuários podem fazer upload de miniaturas de produtos em suas organizações
CREATE POLICY "Users can upload product thumbnails in their organizations"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'product-thumbnails'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid()
          AND status = 'active'
      )
      OR
      array_length(storage.foldername(name), 1) IS NULL
    )
  );

-- ============================================================================
-- PHASE 7 COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'PHASE 7 - STORAGE COMPLETED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Created RLS policies for 3 storage buckets';
  RAISE NOTICE 'Buckets: avatars, client-avatars, product-thumbnails';
  RAISE NOTICE 'Path structure: {bucket}/{organization_id}/{filename}';
  RAISE NOTICE 'Legacy files (without org_id) still accessible';
  RAISE NOTICE '========================================';
END $$;

