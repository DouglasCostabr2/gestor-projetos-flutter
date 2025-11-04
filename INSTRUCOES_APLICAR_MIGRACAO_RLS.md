# Instruções para Aplicar Migração RLS

## Problema
Ao tentar criar uma nova organização, você pode receber o erro:
```
PostgrestException(message: new row violates row-level security policy for table "organizations", code: 42501, details: Forbidden, hint: null)
```

## Solução

### Opção 1: Aplicar via Supabase Dashboard (Recomendado)

1. **Acesse o Supabase Dashboard**
   - Vá para: https://supabase.com/dashboard
   - Selecione seu projeto

2. **Abra o SQL Editor**
   - No menu lateral, clique em "SQL Editor"
   - Clique em "New Query"

3. **Execute o seguinte SQL:**

```sql
-- Create a function to create organizations
-- This function bypasses RLS and ensures proper creation

-- Drop function if exists
DROP FUNCTION IF EXISTS public.create_organization(text, text, text, text, text);

-- Create function to create organization
CREATE OR REPLACE FUNCTION public.create_organization(
  p_name text,
  p_slug text,
  p_legal_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_org_id uuid;
  v_organization jsonb;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();

  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Check if slug already exists
  IF EXISTS (SELECT 1 FROM organizations WHERE slug = p_slug) THEN
    RAISE EXCEPTION 'Slug já existe: %', p_slug;
  END IF;

  -- Insert organization
  INSERT INTO organizations (
    name,
    slug,
    legal_name,
    email,
    phone,
    owner_id,
    status
  ) VALUES (
    p_name,
    p_slug,
    p_legal_name,
    p_email,
    p_phone,
    v_user_id,
    'active'
  )
  RETURNING id INTO v_org_id;

  -- Add user as owner in organization_members
  INSERT INTO organization_members (
    organization_id,
    user_id,
    role,
    status,
    invited_by,
    joined_at
  ) VALUES (
    v_org_id,
    v_user_id,
    'owner',
    'active',
    v_user_id,
    NOW()
  );

  -- Get the created organization
  SELECT jsonb_build_object(
    'id', id,
    'name', name,
    'slug', slug,
    'legal_name', legal_name,
    'email', email,
    'phone', phone,
    'owner_id', owner_id,
    'status', status,
    'created_at', created_at,
    'updated_at', updated_at
  )
  INTO v_organization
  FROM organizations
  WHERE id = v_org_id;

  RETURN v_organization;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_organization(text, text, text, text, text) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.create_organization IS 'Creates a new organization and adds the current user as owner';
```

4. **Clique em "Run"** para executar a query

5. **Verifique se funcionou:**
   - Tente criar uma nova organização no aplicativo
   - Deve funcionar sem erros

### Opção 2: Aplicar via Supabase CLI (Avançado)

Se você tem o Supabase CLI instalado localmente:

```bash
# 1. Certifique-se de estar na pasta do projeto
cd c:\Users\PC\Downloads\gestor_projetos_flutter

# 2. Aplique a migração
supabase db push

# Ou, se estiver usando migrations locais:
supabase migration up
```

### Opção 3: Verificar Política Atual

Para verificar se a política já existe:

```sql
-- Ver todas as políticas da tabela organizations
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'organizations';
```

## Verificação

Após aplicar a migração, teste criando uma organização:

1. Abra o aplicativo
2. Clique no seletor de organizações
3. Selecione "Criar Nova Organização"
4. Preencha os dados e clique em "Criar Organização"
5. Deve funcionar sem erros!

## Notas Técnicas

A política RLS garante que:
- Apenas usuários autenticados podem criar organizações
- O usuário que cria a organização deve ser definido como `owner_id`
- Isso previne que usuários criem organizações em nome de outros

## Troubleshooting

Se ainda houver problemas:

1. **Verifique se o usuário está autenticado:**
   - Faça logout e login novamente
   - Verifique se o token JWT está válido

2. **Verifique se a tabela organizations existe:**
   ```sql
   SELECT * FROM information_schema.tables 
   WHERE table_name = 'organizations';
   ```

3. **Verifique se RLS está habilitado:**
   ```sql
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE tablename = 'organizations';
   ```

4. **Desabilite temporariamente RLS para teste (NÃO RECOMENDADO EM PRODUÇÃO):**
   ```sql
   ALTER TABLE public.organizations DISABLE ROW LEVEL SECURITY;
   ```
   
   Depois de testar, reabilite:
   ```sql
   ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
   ```

