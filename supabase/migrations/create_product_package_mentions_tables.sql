-- ============================================================================
-- CLIENT MENTIONS TABLE
-- ============================================================================

-- Tabela para armazenar menções em clientes
CREATE TABLE IF NOT EXISTS client_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL, -- 'notes'
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Índices para performance
  CONSTRAINT unique_client_mention UNIQUE (client_id, mentioned_user_id, field_name)
);

-- Índices para client_mentions
CREATE INDEX IF NOT EXISTS idx_client_mentions_client_id ON client_mentions(client_id);
CREATE INDEX IF NOT EXISTS idx_client_mentions_mentioned_user_id ON client_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_client_mentions_mentioned_by_user_id ON client_mentions(mentioned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_client_mentions_created_at ON client_mentions(created_at DESC);

-- RLS para client_mentions
ALTER TABLE client_mentions ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ler menções
CREATE POLICY "Todos podem ler menções de clientes"
  ON client_mentions FOR SELECT
  USING (true);

-- Política: Usuários autenticados podem criar menções
CREATE POLICY "Usuários autenticados podem criar menções de clientes"
  ON client_mentions FOR INSERT
  WITH CHECK (auth.uid() = mentioned_by_user_id);

-- Política: Apenas quem criou pode deletar
CREATE POLICY "Apenas quem criou pode deletar menções de clientes"
  ON client_mentions FOR DELETE
  USING (auth.uid() = mentioned_by_user_id);

-- ============================================================================
-- COMPANY MENTIONS TABLE
-- ============================================================================

-- Tabela para armazenar menções em empresas
CREATE TABLE IF NOT EXISTS company_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL, -- 'notes'
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Índices para performance
  CONSTRAINT unique_company_mention UNIQUE (company_id, mentioned_user_id, field_name)
);

-- Índices para company_mentions
CREATE INDEX IF NOT EXISTS idx_company_mentions_company_id ON company_mentions(company_id);
CREATE INDEX IF NOT EXISTS idx_company_mentions_mentioned_user_id ON company_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_company_mentions_mentioned_by_user_id ON company_mentions(mentioned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_company_mentions_created_at ON company_mentions(created_at DESC);

-- RLS para company_mentions
ALTER TABLE company_mentions ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ler menções
CREATE POLICY "Todos podem ler menções de empresas"
  ON company_mentions FOR SELECT
  USING (true);

-- Política: Usuários autenticados podem criar menções
CREATE POLICY "Usuários autenticados podem criar menções de empresas"
  ON company_mentions FOR INSERT
  WITH CHECK (auth.uid() = mentioned_by_user_id);

-- Política: Apenas quem criou pode deletar
CREATE POLICY "Apenas quem criou pode deletar menções de empresas"
  ON company_mentions FOR DELETE
  USING (auth.uid() = mentioned_by_user_id);

-- ============================================================================
-- PRODUCT MENTIONS TABLE
-- ============================================================================

-- Tabela para armazenar menções em produtos
CREATE TABLE IF NOT EXISTS product_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL, -- 'description'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índices para performance
  CONSTRAINT unique_product_mention UNIQUE (product_id, mentioned_user_id, field_name)
);

-- Índices para product_mentions
CREATE INDEX IF NOT EXISTS idx_product_mentions_product_id ON product_mentions(product_id);
CREATE INDEX IF NOT EXISTS idx_product_mentions_mentioned_user_id ON product_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_product_mentions_mentioned_by_user_id ON product_mentions(mentioned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_product_mentions_created_at ON product_mentions(created_at DESC);

-- RLS para product_mentions
ALTER TABLE product_mentions ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ler menções
CREATE POLICY "Todos podem ler menções de produtos"
  ON product_mentions FOR SELECT
  USING (true);

-- Política: Usuários autenticados podem criar menções
CREATE POLICY "Usuários autenticados podem criar menções de produtos"
  ON product_mentions FOR INSERT
  WITH CHECK (auth.uid() = mentioned_by_user_id);

-- Política: Apenas quem criou pode deletar
CREATE POLICY "Apenas quem criou pode deletar menções de produtos"
  ON product_mentions FOR DELETE
  USING (auth.uid() = mentioned_by_user_id);

-- ============================================================================
-- PACKAGE MENTIONS TABLE
-- ============================================================================

-- Tabela para armazenar menções em pacotes
CREATE TABLE IF NOT EXISTS package_mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  mentioned_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  mentioned_by_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL, -- 'description'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Índices para performance
  CONSTRAINT unique_package_mention UNIQUE (package_id, mentioned_user_id, field_name)
);

-- Índices para package_mentions
CREATE INDEX IF NOT EXISTS idx_package_mentions_package_id ON package_mentions(package_id);
CREATE INDEX IF NOT EXISTS idx_package_mentions_mentioned_user_id ON package_mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_package_mentions_mentioned_by_user_id ON package_mentions(mentioned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_package_mentions_created_at ON package_mentions(created_at DESC);

-- RLS para package_mentions
ALTER TABLE package_mentions ENABLE ROW LEVEL SECURITY;

-- Política: Todos podem ler menções
CREATE POLICY "Todos podem ler menções de pacotes"
  ON package_mentions FOR SELECT
  USING (true);

-- Política: Usuários autenticados podem criar menções
CREATE POLICY "Usuários autenticados podem criar menções de pacotes"
  ON package_mentions FOR INSERT
  WITH CHECK (auth.uid() = mentioned_by_user_id);

-- Política: Apenas quem criou pode deletar
CREATE POLICY "Apenas quem criou pode deletar menções de pacotes"
  ON package_mentions FOR DELETE
  USING (auth.uid() = mentioned_by_user_id);

