-- Adicionar colunas de status e timestamps para produtos e pacotes
-- Migração: add_status_timestamps_to_catalog.sql
-- Data: 2025-10-12

-- ============================================================================
-- PRODUTOS
-- ============================================================================

-- Adicionar coluna de status (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'status'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'coming_soon'));
        
        COMMENT ON COLUMN public.products.status IS 'Status do produto: active, inactive, discontinued, coming_soon';
    END IF;
END $$;

-- Adicionar coluna created_at (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN created_at timestamptz DEFAULT now();
        
        COMMENT ON COLUMN public.products.created_at IS 'Data de criação do produto';
    END IF;
END $$;

-- Adicionar coluna updated_at (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.products 
        ADD COLUMN updated_at timestamptz DEFAULT now();
        
        COMMENT ON COLUMN public.products.updated_at IS 'Data da última atualização do produto';
    END IF;
END $$;

-- Adicionar coluna created_by (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE public.products
        ADD COLUMN created_by uuid REFERENCES public.profiles(id);

        COMMENT ON COLUMN public.products.created_by IS 'Usuário que criou o produto';
    END IF;
END $$;

-- Adicionar coluna updated_by (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'products' AND column_name = 'updated_by'
    ) THEN
        ALTER TABLE public.products
        ADD COLUMN updated_by uuid REFERENCES public.profiles(id);

        COMMENT ON COLUMN public.products.updated_by IS 'Usuário que atualizou o produto pela última vez';
    END IF;
END $$;

-- ============================================================================
-- PACOTES
-- ============================================================================

-- Adicionar coluna de status (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'packages' AND column_name = 'status'
    ) THEN
        ALTER TABLE public.packages 
        ADD COLUMN status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'coming_soon'));
        
        COMMENT ON COLUMN public.packages.status IS 'Status do pacote: active, inactive, discontinued, coming_soon';
    END IF;
END $$;

-- Adicionar coluna created_at (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'packages' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.packages 
        ADD COLUMN created_at timestamptz DEFAULT now();
        
        COMMENT ON COLUMN public.packages.created_at IS 'Data de criação do pacote';
    END IF;
END $$;

-- Adicionar coluna updated_at (se não existir)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'packages' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.packages 
        ADD COLUMN updated_at timestamptz DEFAULT now();
        
        COMMENT ON COLUMN public.packages.updated_at IS 'Data da última atualização do pacote';
    END IF;
END $$;

-- Adicionar coluna created_by (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE public.packages
        ADD COLUMN created_by uuid REFERENCES public.profiles(id);

        COMMENT ON COLUMN public.packages.created_by IS 'Usuário que criou o pacote';
    END IF;
END $$;

-- Adicionar coluna updated_by (se não existir)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'packages' AND column_name = 'updated_by'
    ) THEN
        ALTER TABLE public.packages
        ADD COLUMN updated_by uuid REFERENCES public.profiles(id);

        COMMENT ON COLUMN public.packages.updated_by IS 'Usuário que atualizou o pacote pela última vez';
    END IF;
END $$;

-- ============================================================================
-- TRIGGERS PARA ATUALIZAR updated_at AUTOMATICAMENTE
-- ============================================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para produtos
DROP TRIGGER IF EXISTS update_products_updated_at ON public.products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger para pacotes
DROP TRIGGER IF EXISTS update_packages_updated_at ON public.packages;
CREATE TRIGGER update_packages_updated_at
    BEFORE UPDATE ON public.packages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- ÍNDICES PARA MELHOR PERFORMANCE
-- ============================================================================

-- Índice para status de produtos
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);

-- Índice para status de pacotes
CREATE INDEX IF NOT EXISTS idx_packages_status ON public.packages(status);

-- Índice para created_at de produtos
CREATE INDEX IF NOT EXISTS idx_products_created_at ON public.products(created_at DESC);

-- Índice para created_at de pacotes
CREATE INDEX IF NOT EXISTS idx_packages_created_at ON public.packages(created_at DESC);

-- ============================================================================
-- COMENTÁRIOS FINAIS
-- ============================================================================

COMMENT ON TABLE public.products IS 'Tabela de produtos do catálogo com status e timestamps';
COMMENT ON TABLE public.packages IS 'Tabela de pacotes do catálogo com status e timestamps';

