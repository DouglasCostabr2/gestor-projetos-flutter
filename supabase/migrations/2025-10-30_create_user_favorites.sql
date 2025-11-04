-- ============================================================================
-- Migration: Criar tabela de favoritos de usuários
-- Data: 2025-10-30
-- Descrição: Adiciona suporte para usuários favoritarem projetos, tarefas e subtarefas
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR TABELA user_favorites
-- ============================================================================

-- Criar tabela para armazenar favoritos dos usuários
CREATE TABLE IF NOT EXISTS public.user_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_type text NOT NULL CHECK (item_type IN ('project', 'task', 'subtask')),
  item_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  
  -- Constraint única: um usuário não pode favoritar o mesmo item mais de uma vez
  CONSTRAINT user_favorites_unique_item UNIQUE (user_id, item_type, item_id)
);

-- Comentários explicativos
COMMENT ON TABLE public.user_favorites IS 'Armazena os itens favoritados pelos usuários (projetos, tarefas, subtarefas)';
COMMENT ON COLUMN public.user_favorites.id IS 'ID único do favorito';
COMMENT ON COLUMN public.user_favorites.user_id IS 'ID do usuário que favoritou';
COMMENT ON COLUMN public.user_favorites.item_type IS 'Tipo do item favoritado: project, task ou subtask';
COMMENT ON COLUMN public.user_favorites.item_id IS 'ID do item favoritado (referência para projects.id ou tasks.id)';
COMMENT ON COLUMN public.user_favorites.created_at IS 'Data/hora em que o item foi favoritado';

-- ============================================================================
-- PARTE 2: CRIAR ÍNDICES PARA PERFORMANCE
-- ============================================================================

-- Índice para buscar favoritos de um usuário específico
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id 
  ON public.user_favorites(user_id);

-- Índice para buscar favoritos por tipo
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_type 
  ON public.user_favorites(user_id, item_type);

-- Índice para buscar se um item específico está favoritado
CREATE INDEX IF NOT EXISTS idx_user_favorites_item 
  ON public.user_favorites(user_id, item_type, item_id);

-- ============================================================================
-- PARTE 3: HABILITAR ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Habilitar RLS na tabela
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PARTE 4: CRIAR POLÍTICAS RLS
-- ============================================================================

-- Política: Usuários podem ver apenas seus próprios favoritos
DROP POLICY IF EXISTS "user_favorites_select_own" ON public.user_favorites;
CREATE POLICY "user_favorites_select_own"
  ON public.user_favorites
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Política: Usuários podem inserir favoritos apenas para si mesmos
DROP POLICY IF EXISTS "user_favorites_insert_own" ON public.user_favorites;
CREATE POLICY "user_favorites_insert_own"
  ON public.user_favorites
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Política: Usuários podem deletar apenas seus próprios favoritos
DROP POLICY IF EXISTS "user_favorites_delete_own" ON public.user_favorites;
CREATE POLICY "user_favorites_delete_own"
  ON public.user_favorites
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ============================================================================
-- CONCLUÍDO
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Migration concluída com sucesso!';
  RAISE NOTICE '📝 Tabela criada: user_favorites';
  RAISE NOTICE '🔒 RLS habilitado com políticas de segurança';
  RAISE NOTICE '⚡ Índices criados para performance';
  RAISE NOTICE '✓  Usuários podem favoritar projetos, tarefas e subtarefas';
END $$;

