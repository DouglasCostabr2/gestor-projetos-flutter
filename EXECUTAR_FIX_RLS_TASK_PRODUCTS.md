# 🚨 URGENTE - CORRIGIR RLS DE TASK_PRODUCTS

Data: 2025-10-02

---

## ❌ **ERRO IDENTIFICADO:**

```
Falha ao salvar produtos vinculados (quick edit): PostgrestException(message: new row violates row-level security policy for table "task_products", code: 42501, details: Forbidden, hint: null)
```

**Causa**: As políticas RLS (Row Level Security) da tabela `task_products` estão bloqueando inserções.

---

## ✅ **SOLUÇÃO:**

Execute a migration: `supabase/migrations/2025-10-02_fix_task_products_rls.sql`

---

## 📋 **COMO EXECUTAR:**

### 1. Acesse o Supabase SQL Editor
- URL: https://app.supabase.com
- Navegue até: SQL Editor → New Query

### 2. Cole o conteúdo da migration
Copie todo o conteúdo do arquivo `supabase/migrations/2025-10-02_fix_task_products_rls.sql`

### 3. Execute (Ctrl+Enter)
Aguarde a mensagem "Success"

---

## 🔍 **O QUE A MIGRATION FAZ:**

1. **Remove políticas antigas** (que estavam incorretas)
2. **Recria políticas corretas** que verificam:
   - Se a task existe
   - Se o usuário é membro do projeto da task
   - Permite SELECT, INSERT, UPDATE, DELETE

---

## ✅ **VERIFICAR SE DEU CERTO:**

Após executar a migration, teste:

1. Criar uma task
2. Adicionar 2-3 produtos
3. Salvar
4. Verificar se não há erro no console
5. Editar a task
6. Verificar se os produtos aparecem

---

## 📊 **DEBUG ATUAL:**

Do console, vemos que:
- ✅ TaskProductLinkSection está carregando corretamente
- ✅ Encontrou 0 produtos (porque ainda não salvou nenhum)
- ❌ Erro ao salvar: RLS bloqueando

**Após a migration, o erro deve desaparecer!**

---

## 🎯 **PRÓXIMOS PASSOS:**

1. ⚠️ **AGORA**: Execute a migration
2. ✅ **DEPOIS**: Teste criar task com produtos
3. ✅ **DEPOIS**: Teste editar task e verificar se produtos aparecem

---

**EXECUTE A MIGRATION E TESTE NOVAMENTE!** 🚀

