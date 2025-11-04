-- Corrigir Foreign Keys de created_by e updated_by para apontar para profiles
-- Migração: fix_catalog_foreign_keys.sql
-- Data: 2025-10-12

-- ============================================================================
-- PRODUTOS - Remover e recriar foreign keys
-- ============================================================================

-- Remover constraint antiga de created_by (se existir)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_created_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products DROP CONSTRAINT products_created_by_fkey;
    END IF;
END $$;

-- Remover constraint antiga de updated_by (se existir)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_updated_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products DROP CONSTRAINT products_updated_by_fkey;
    END IF;
END $$;

-- Adicionar nova constraint para created_by apontando para profiles
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_created_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products 
        ADD CONSTRAINT products_created_by_fkey 
        FOREIGN KEY (created_by) REFERENCES public.profiles(id);
    END IF;
END $$;

-- Adicionar nova constraint para updated_by apontando para profiles
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_updated_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products 
        ADD CONSTRAINT products_updated_by_fkey 
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id);
    END IF;
END $$;

-- ============================================================================
-- PACOTES - Remover e recriar foreign keys
-- ============================================================================

-- Remover constraint antiga de created_by (se existir)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_created_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages DROP CONSTRAINT packages_created_by_fkey;
    END IF;
END $$;

-- Remover constraint antiga de updated_by (se existir)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_updated_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages DROP CONSTRAINT packages_updated_by_fkey;
    END IF;
END $$;

-- Adicionar nova constraint para created_by apontando para profiles
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_created_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages 
        ADD CONSTRAINT packages_created_by_fkey 
        FOREIGN KEY (created_by) REFERENCES public.profiles(id);
    END IF;
END $$;

-- Adicionar nova constraint para updated_by apontando para profiles
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_updated_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages 
        ADD CONSTRAINT packages_updated_by_fkey 
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id);
    END IF;
END $$;

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================

-- Verificar foreign keys criadas
SELECT 
    tc.table_name, 
    tc.constraint_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name IN ('products', 'packages')
    AND kcu.column_name IN ('created_by', 'updated_by')
ORDER BY tc.table_name, kcu.column_name;

