# Aplicar Migration: Adicionar Descrição aos Time Logs

## 📋 Visão Geral

Esta migration adiciona a coluna `description` à tabela `time_logs` para permitir que usuários descrevam a atividade realizada durante cada sessão de tempo.

## 🗄️ Arquivo da Migration

**Localização:** `supabase/migrations/2025-10-26_add_description_to_time_logs.sql`

## 🚀 Como Aplicar

### Opção 1: Via Supabase Dashboard (Recomendado)

1. Acesse o [Supabase Dashboard](https://app.supabase.com)
2. Selecione seu projeto
3. Vá para **SQL Editor** no menu lateral
4. Clique em **New Query**
5. Copie e cole o conteúdo do arquivo `supabase/migrations/2025-10-26_add_description_to_time_logs.sql`
6. Clique em **Run** para executar

### Opção 2: Via Supabase CLI

```bash
# Certifique-se de estar na raiz do projeto
cd c:\Users\PC\Downloads\gestor_projetos_flutter

# Aplicar a migration
supabase db push
```

## ✅ Verificação

Após aplicar a migration, você pode verificar se foi bem-sucedida executando:

```sql
-- Verificar se a coluna foi adicionada
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'time_logs'
  AND column_name = 'description';

-- Deve retornar:
-- column_name | data_type | is_nullable
-- description | text      | YES
```

## 📝 O que a Migration Faz

1. **Adiciona coluna `description`:**
   - Tipo: `TEXT`
   - Nullable: `YES` (opcional)
   - Permite armazenar descrições de até ~1GB (limite do PostgreSQL para TEXT)

2. **Adiciona constraint de validação:**
   - Garante que a descrição não seja apenas espaços em branco
   - Se fornecida, deve conter pelo menos um caractere não-espaço

3. **Adiciona comentário:**
   - Documenta o propósito da coluna no banco de dados

## 🔄 Rollback (Se Necessário)

Se precisar reverter a migration:

```sql
-- Remover constraint
ALTER TABLE public.time_logs
  DROP CONSTRAINT IF EXISTS check_description_not_empty;

-- Remover coluna
ALTER TABLE public.time_logs
  DROP COLUMN IF EXISTS description;
```

## 📊 Impacto

- **Performance:** Nenhum impacto significativo (coluna nullable)
- **Espaço:** Mínimo (apenas quando descrições são fornecidas)
- **Compatibilidade:** Totalmente compatível com código existente (campo opcional)

## 🎯 Próximos Passos

Após aplicar a migration:

1. ✅ Reiniciar o aplicativo Flutter
2. ✅ Testar a funcionalidade de adicionar descrição ao parar o timer
3. ✅ Verificar se as descrições aparecem no histórico de tempo
4. ✅ Testar com descrições longas e caracteres especiais

## 📚 Documentação Relacionada

- [Documentação do Sistema de Time Tracking](docs/TIME_TRACKING_SYSTEM.md)
- [Migration Original](supabase/migrations/2025-10-13_create_time_tracking.sql)

