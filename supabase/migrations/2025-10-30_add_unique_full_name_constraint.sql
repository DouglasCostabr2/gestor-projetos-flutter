-- ============================================================================
-- Migration: Add unique constraint to full_name in profiles table
-- Date: 2025-10-30
-- Description: Ensures that each user has a unique full name to support
--              the mentions system (@mentions) without ambiguity
-- ============================================================================

-- ============================================================================
-- PARTE 1: VERIFICAR E CORRIGIR NOMES DUPLICADOS EXISTENTES
-- ============================================================================

-- Primeiro, vamos identificar e corrigir nomes duplicados adicionando um sufixo
DO $$
DECLARE
  duplicate_record RECORD;
  counter INTEGER;
BEGIN
  -- Para cada nome duplicado, adicionar um número sequencial
  FOR duplicate_record IN 
    SELECT full_name, COUNT(*) as count
    FROM profiles
    GROUP BY full_name
    HAVING COUNT(*) > 1
  LOOP
    counter := 1;
    
    -- Atualizar cada registro duplicado (exceto o primeiro)
    FOR duplicate_record IN
      SELECT id, full_name
      FROM profiles
      WHERE full_name = duplicate_record.full_name
      ORDER BY created_at
      OFFSET 1
    LOOP
      UPDATE profiles
      SET full_name = duplicate_record.full_name || ' (' || counter || ')'
      WHERE id = duplicate_record.id;
      
      counter := counter + 1;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================================
-- PARTE 2: ADICIONAR CONSTRAINT DE UNICIDADE
-- ============================================================================

-- Adicionar constraint para garantir que full_name seja único
ALTER TABLE public.profiles
ADD CONSTRAINT profiles_full_name_unique UNIQUE (full_name);

-- ============================================================================
-- PARTE 3: CRIAR ÍNDICE PARA PERFORMANCE
-- ============================================================================

-- Criar índice para buscas rápidas por nome (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_profiles_full_name_lower
ON public.profiles(LOWER(full_name));

-- ============================================================================
-- PARTE 4: COMENTÁRIOS
-- ============================================================================

COMMENT ON CONSTRAINT profiles_full_name_unique ON public.profiles IS 
'Garante que cada usuário tenha um nome único para suportar o sistema de menções (@mentions) sem ambiguidade';

