-- Migração Completa: Status e Timestamps para Catálogo
-- Data: 2025-10-12
-- Descrição: Adiciona status, created_at, updated_at, created_by, updated_by para products e packages

-- ============================================================================
-- PARTE 1: ADICIONAR COLUNAS (se não existirem)
-- ============================================================================

-- PRODUTOS: Status
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'coming_soon'));

-- PRODUTOS: Timestamps
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- PRODUTOS: User tracking (sem foreign key ainda)
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS updated_by uuid;

-- PACOTES: Status
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued', 'coming_soon'));

-- PACOTES: Timestamps
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- PACOTES: User tracking (sem foreign key ainda)
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE public.packages ADD COLUMN IF NOT EXISTS updated_by uuid;

-- ============================================================================
-- PARTE 2: REMOVER FOREIGN KEYS ANTIGAS (se existirem)
-- ============================================================================

-- PRODUTOS
DO $$ 
BEGIN
    -- Remover constraint de created_by
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_created_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products DROP CONSTRAINT products_created_by_fkey;
    END IF;
    
    -- Remover constraint de updated_by
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'products_updated_by_fkey' 
        AND table_name = 'products'
    ) THEN
        ALTER TABLE public.products DROP CONSTRAINT products_updated_by_fkey;
    END IF;
END $$;

-- PACOTES
DO $$ 
BEGIN
    -- Remover constraint de created_by
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_created_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages DROP CONSTRAINT packages_created_by_fkey;
    END IF;
    
    -- Remover constraint de updated_by
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'packages_updated_by_fkey' 
        AND table_name = 'packages'
    ) THEN
        ALTER TABLE public.packages DROP CONSTRAINT packages_updated_by_fkey;
    END IF;
END $$;

-- ============================================================================
-- PARTE 3: ADICIONAR FOREIGN KEYS CORRETAS (apontando para profiles)
-- ============================================================================

-- PRODUTOS
ALTER TABLE public.products 
ADD CONSTRAINT products_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE public.products 
ADD CONSTRAINT products_updated_by_fkey 
FOREIGN KEY (updated_by) REFERENCES public.profiles(id);

-- PACOTES
ALTER TABLE public.packages 
ADD CONSTRAINT packages_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES public.profiles(id);

ALTER TABLE public.packages 
ADD CONSTRAINT packages_updated_by_fkey 
FOREIGN KEY (updated_by) REFERENCES public.profiles(id);

-- ============================================================================
-- PARTE 4: TRIGGERS PARA ATUALIZAR updated_at AUTOMATICAMENTE
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
-- PARTE 5: ÍNDICES PARA MELHOR PERFORMANCE
-- ============================================================================

-- Índices para status
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);
CREATE INDEX IF NOT EXISTS idx_packages_status ON public.packages(status);

-- Índices para created_at
CREATE INDEX IF NOT EXISTS idx_products_created_at ON public.products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_packages_created_at ON public.packages(created_at DESC);

-- Índices para created_by e updated_by
CREATE INDEX IF NOT EXISTS idx_products_created_by ON public.products(created_by);
CREATE INDEX IF NOT EXISTS idx_products_updated_by ON public.products(updated_by);
CREATE INDEX IF NOT EXISTS idx_packages_created_by ON public.packages(created_by);
CREATE INDEX IF NOT EXISTS idx_packages_updated_by ON public.packages(updated_by);

-- ============================================================================
-- PARTE 6: COMENTÁRIOS
-- ============================================================================

COMMENT ON COLUMN public.products.status IS 'Status do produto: active, inactive, discontinued, coming_soon';
COMMENT ON COLUMN public.products.created_at IS 'Data de criação do produto';
COMMENT ON COLUMN public.products.updated_at IS 'Data da última atualização do produto';
COMMENT ON COLUMN public.products.created_by IS 'Usuário que criou o produto';
COMMENT ON COLUMN public.products.updated_by IS 'Usuário que atualizou o produto pela última vez';

COMMENT ON COLUMN public.packages.status IS 'Status do pacote: active, inactive, discontinued, coming_soon';
COMMENT ON COLUMN public.packages.created_at IS 'Data de criação do pacote';
COMMENT ON COLUMN public.packages.updated_at IS 'Data da última atualização do pacote';
COMMENT ON COLUMN public.packages.created_by IS 'Usuário que criou o pacote';
COMMENT ON COLUMN public.packages.updated_by IS 'Usuário que atualizou o pacote pela última vez';

-- ============================================================================
-- PARTE 7: VERIFICAÇÃO FINAL
-- ============================================================================

-- Verificar colunas criadas
SELECT 
    table_name,
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name IN ('products', 'packages')
    AND column_name IN ('status', 'created_at', 'updated_at', 'created_by', 'updated_by')
ORDER BY table_name, column_name;

-- Verificar foreign keys
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

-- Verificar triggers
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN ('update_products_updated_at', 'update_packages_updated_at')
ORDER BY event_object_table;

