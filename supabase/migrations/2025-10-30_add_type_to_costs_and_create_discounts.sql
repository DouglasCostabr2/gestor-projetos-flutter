-- Adicionar coluna 'type' na tabela project_additional_costs
-- type pode ser 'percentage' ou 'fixed'
ALTER TABLE public.project_additional_costs 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'fixed' CHECK (type IN ('percentage', 'fixed'));

-- Criar tabela project_discounts
CREATE TABLE IF NOT EXISTS public.project_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  value_cents INTEGER NOT NULL DEFAULT 0,
  type TEXT NOT NULL DEFAULT 'percentage' CHECK (type IN ('percentage', 'fixed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Criar índice para melhorar performance
CREATE INDEX IF NOT EXISTS idx_project_discounts_project_id ON public.project_discounts(project_id);

-- Habilitar RLS
ALTER TABLE public.project_discounts ENABLE ROW LEVEL SECURITY;

-- Criar política de acesso (permitir tudo para usuários autenticados, como nas outras tabelas)
CREATE POLICY "project_discounts_all" ON public.project_discounts 
FOR ALL TO authenticated 
USING (true) 
WITH CHECK (true);

-- Comentários para documentação
COMMENT ON TABLE public.project_discounts IS 'Descontos aplicados aos projetos';
COMMENT ON COLUMN public.project_discounts.type IS 'Tipo de desconto: percentage (porcentagem sobre subtotal) ou fixed (valor fixo)';
COMMENT ON COLUMN public.project_discounts.value_cents IS 'Valor em centavos. Se type=percentage, representa a porcentagem * 100 (ex: 10% = 1000)';

