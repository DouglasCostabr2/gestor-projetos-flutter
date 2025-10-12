# 🔧 FIX: Erro ao Salvar Cliente - RLS Policy

## ❌ ERRO ATUAL
```
PostgresException(message: new row violates row-level security policy for table "clients", 
code: 42501, details: Forbidden, hint: null)
```

## 🎯 CAUSA
A tabela `clients` tem RLS (Row Level Security) habilitado, mas **não tem políticas** que permitam inserir novos registros.

---

## ✅ SOLUÇÃO

### Passo 1: Acessar Supabase SQL Editor

1. Acesse: https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **SQL Editor** (menu lateral esquerdo)

### Passo 2: Executar a Migration

Copie e cole o conteúdo do arquivo `supabase/migrations/fix_clients_rls.sql` no SQL Editor e clique em **RUN**.

Ou copie o código abaixo:

```sql
-- Fix RLS policies for clients table

-- 1. Enable RLS on clients table (if not already enabled)
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies (if any)
DROP POLICY IF EXISTS "Users can view clients" ON public.clients;
DROP POLICY IF EXISTS "Users can insert clients" ON public.clients;
DROP POLICY IF EXISTS "Users can update clients" ON public.clients;
DROP POLICY IF EXISTS "Users can delete clients" ON public.clients;

-- 3. Create new policies

-- Allow authenticated users to view all clients
CREATE POLICY "Users can view clients"
  ON public.clients
  FOR SELECT
  TO authenticated
  USING (true);

-- Allow authenticated users to insert clients
CREATE POLICY "Users can insert clients"
  ON public.clients
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Allow users to update clients they created or if they are admin/gestor
CREATE POLICY "Users can update clients"
  ON public.clients
  FOR UPDATE
  TO authenticated
  USING (
    owner_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'gestor')
    )
  );

-- Allow users to delete clients they created or if they are admin
CREATE POLICY "Users can delete clients"
  ON public.clients
  FOR DELETE
  TO authenticated
  USING (
    owner_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- 4. Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'clients'
ORDER BY policyname;
```

### Passo 3: Verificar Resultado

Após executar, você deve ver 4 políticas criadas:
- ✅ `Users can view clients` (SELECT)
- ✅ `Users can insert clients` (INSERT)
- ✅ `Users can update clients` (UPDATE)
- ✅ `Users can delete clients` (DELETE)

---

## 📋 O QUE AS POLÍTICAS FAZEM

### 1. **SELECT (Visualizar)**
- ✅ Todos os usuários autenticados podem ver todos os clientes

### 2. **INSERT (Criar)**
- ✅ Todos os usuários autenticados podem criar clientes

### 3. **UPDATE (Editar)**
- ✅ Usuário pode editar clientes que ele criou (`owner_id = auth.uid()`)
- ✅ Admin e Gestor podem editar qualquer cliente

### 4. **DELETE (Excluir)**
- ✅ Usuário pode excluir clientes que ele criou
- ✅ Apenas Admin pode excluir qualquer cliente

---

## 🧪 TESTAR

Após executar a migration:

1. **Feche e reabra** a aplicação Flutter
2. Tente criar um novo cliente
3. ✅ Deve funcionar sem erros!

---

## 🔍 VERIFICAR POLÍTICAS ATUAIS

Se quiser ver as políticas atuais da tabela `clients`, execute:

```sql
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'clients';
```

---

## ⚠️ IMPORTANTE

- Esta migration é **idempotente** (pode ser executada múltiplas vezes sem problemas)
- As políticas antigas são removidas antes de criar as novas
- Se você tiver políticas customizadas, elas serão substituídas

---

## 📞 SUPORTE

Se o erro persistir após executar a migration:

1. Verifique se você está **logado** na aplicação
2. Verifique se a tabela `profiles` existe e tem seu usuário
3. Execute o comando de verificação (Passo 3) para confirmar que as políticas foram criadas

