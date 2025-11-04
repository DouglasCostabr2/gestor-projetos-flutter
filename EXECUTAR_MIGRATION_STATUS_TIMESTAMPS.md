# 📋 Instruções para Executar Migração: Status e Timestamps no Catálogo

## 🎯 Objetivo

Adicionar colunas de **status**, **created_at**, **updated_at**, **created_by** e **updated_by** nas tabelas `products` e `packages` do Supabase.

## 📊 Alterações no Banco de Dados

### Tabela `products`
- ✅ `status` (text) - Status do produto: 'active', 'inactive', 'discontinued', 'coming_soon'
- ✅ `created_at` (timestamptz) - Data de criação
- ✅ `updated_at` (timestamptz) - Data da última atualização
- ✅ `created_by` (uuid) - Usuário que criou
- ✅ `updated_by` (uuid) - Usuário que atualizou

### Tabela `packages`
- ✅ `status` (text) - Status do pacote: 'active', 'inactive', 'discontinued', 'coming_soon'
- ✅ `created_at` (timestamptz) - Data de criação
- ✅ `updated_at` (timestamptz) - Data da última atualização
- ✅ `created_by` (uuid) - Usuário que criou
- ✅ `updated_by` (uuid) - Usuário que atualizou

### Triggers
- ✅ Trigger automático para atualizar `updated_at` em cada UPDATE

### Índices
- ✅ Índice em `status` para filtros rápidos
- ✅ Índice em `created_at` para ordenação por data

## 🚀 Como Executar

### Opção 1: Via Supabase Dashboard (Recomendado)

1. **Acesse o Supabase Dashboard**
   - Vá para: https://supabase.com/dashboard
   - Selecione seu projeto

2. **Abra o SQL Editor**
   - No menu lateral, clique em **SQL Editor**
   - Clique em **New Query**

3. **Cole o SQL**
   - Abra o arquivo: `supabase/migrations/add_status_timestamps_to_catalog.sql`
   - Copie todo o conteúdo
   - Cole no SQL Editor

4. **Execute**
   - Clique em **Run** (ou pressione `Ctrl+Enter`)
   - Aguarde a confirmação de sucesso

5. **Verifique**
   - Vá para **Table Editor**
   - Selecione a tabela `products`
   - Verifique se as novas colunas aparecem
   - Repita para a tabela `packages`

### Opção 2: Via Supabase CLI (Avançado)

```bash
# 1. Certifique-se de que o Supabase CLI está instalado
supabase --version

# 2. Faça login (se ainda não estiver logado)
supabase login

# 3. Link com seu projeto (se ainda não estiver linkado)
supabase link --project-ref SEU_PROJECT_REF

# 4. Execute a migração
supabase db push

# Ou execute diretamente o arquivo SQL
supabase db execute -f supabase/migrations/add_status_timestamps_to_catalog.sql
```

### Opção 3: Via psql (Linha de Comando)

```bash
# Conecte-se ao banco de dados
psql "postgresql://postgres:[SUA_SENHA]@[SEU_HOST]:5432/postgres"

# Execute o arquivo
\i supabase/migrations/add_status_timestamps_to_catalog.sql

# Ou cole o conteúdo diretamente
```

## ✅ Verificação Pós-Migração

Execute este SQL para verificar se as colunas foram criadas:

```sql
-- Verificar colunas de products
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'products'
  AND column_name IN ('status', 'created_at', 'updated_at', 'created_by', 'updated_by')
ORDER BY column_name;

-- Verificar colunas de packages
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'packages'
  AND column_name IN ('status', 'created_at', 'updated_at', 'created_by', 'updated_by')
ORDER BY column_name;

-- Verificar triggers
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name IN ('update_products_updated_at', 'update_packages_updated_at');

-- Verificar índices
SELECT indexname, tablename
FROM pg_indexes
WHERE indexname IN ('idx_products_status', 'idx_packages_status', 'idx_products_created_at', 'idx_packages_created_at');
```

## 📝 Valores Padrão

- **status**: `'active'` (todos os produtos/pacotes existentes serão marcados como ativos)
- **created_at**: `now()` (data atual para registros existentes)
- **updated_at**: `now()` (data atual para registros existentes)
- **created_by**: `NULL` (não sabemos quem criou os registros antigos)
- **updated_by**: `NULL` (não sabemos quem atualizou os registros antigos)

## 🔄 Próximos Passos

Após executar a migração com sucesso:

1. ✅ Atualizar o código Flutter para:
   - Exibir as novas colunas na tabela
   - Salvar `status`, `created_by` e `updated_by` ao criar/editar
   - Formatar datas de forma amigável
   - Adicionar filtro por status

2. ✅ Testar:
   - Criar novo produto → verificar se `created_at`, `created_by` e `status` são salvos
   - Editar produto → verificar se `updated_at` e `updated_by` são atualizados
   - Filtrar por status → verificar se funciona
   - Ordenar por data → verificar se funciona

## ⚠️ Observações Importantes

- **Segurança**: A migração usa `DO $$ BEGIN ... END $$` para verificar se as colunas já existem antes de criá-las, evitando erros se executada múltiplas vezes
- **Performance**: Índices foram criados para otimizar consultas por status e data
- **Triggers**: O `updated_at` será atualizado automaticamente em cada UPDATE
- **Compatibilidade**: Produtos/pacotes existentes receberão valores padrão

## 🆘 Problemas Comuns

### Erro: "permission denied"
- **Solução**: Certifique-se de estar usando um usuário com permissões de administrador

### Erro: "column already exists"
- **Solução**: A migração já foi executada. Não há problema, pode ignorar.

### Erro: "relation does not exist"
- **Solução**: Verifique se as tabelas `products` e `packages` existem no banco

## 📞 Suporte

Se encontrar problemas, verifique:
1. Logs do Supabase Dashboard
2. Permissões do usuário do banco
3. Se as tabelas `products` e `packages` existem

---

**Status**: ⏳ Aguardando execução
**Criado em**: 2025-10-12
**Arquivo SQL**: `supabase/migrations/add_status_timestamps_to_catalog.sql`

