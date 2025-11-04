# 🚀 Instruções: Como Aplicar a Atualização de Dados Fiscais e Bancários

## 📋 Pré-requisitos

- ✅ Acesso ao Supabase Dashboard
- ✅ Permissões de administrador no projeto
- ✅ Backup recente do banco de dados (recomendado)

---

## 🎯 Opção 1: Aplicar Tudo de Uma Vez (Recomendado)

### **Passo 1: Acessar o SQL Editor do Supabase**

1. Abra o [Supabase Dashboard](https://app.supabase.com)
2. Selecione seu projeto
3. No menu lateral, clique em **SQL Editor**

### **Passo 2: Executar o Script Completo**

1. Clique em **New Query**
2. Copie todo o conteúdo do arquivo:
   ```
   supabase/migrations/APPLY_COMPANIES_FISCAL_BANK_UPDATE.sql
   ```
3. Cole no editor SQL
4. Clique em **Run** (ou pressione `Ctrl+Enter`)

### **Passo 3: Verificar o Resultado**

Você deve ver uma mensagem de sucesso com um resumo completo:

```
✅ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO!

📊 RESUMO DAS MUDANÇAS:

1️⃣  CAMPOS ADICIONADOS À TABELA companies:
   ✅ fiscal_data (JSONB) - Dados fiscais por país
   ✅ bank_data (JSONB) - Dados bancários por país
   ✅ fiscal_country (VARCHAR 2) - Código ISO do país ativo

2️⃣  ÍNDICES CRIADOS:
   ✅ idx_companies_fiscal_data (GIN)
   ✅ idx_companies_bank_data (GIN)
   ✅ idx_companies_fiscal_country

3️⃣  TABELA DE AUDITORIA CRIADA:
   ✅ companies_fiscal_bank_audit_log
   ✅ 5 índices para performance
   ✅ RLS habilitado com 2 políticas

🌍 SUPORTE MULTI-PAÍS HABILITADO!
```

---

## 🎯 Opção 2: Aplicar Passo a Passo

Se preferir aplicar as migrations separadamente:

### **Passo 1: Adicionar Campos JSONB**

Execute o arquivo:
```
supabase/migrations/20251103_add_fiscal_bank_data_to_companies.sql
```

### **Passo 2: Criar Tabela de Auditoria**

Execute o arquivo:
```
supabase/migrations/20251103_create_companies_fiscal_bank_audit_log.sql
```

---

## ✅ Verificação Pós-Instalação

### **1. Verificar Campos na Tabela Companies**

Execute no SQL Editor:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public'
  AND table_name = 'companies' 
  AND column_name IN ('fiscal_data', 'bank_data', 'fiscal_country')
ORDER BY column_name;
```

**Resultado esperado:**
```
bank_data      | jsonb                    | YES
fiscal_country | character varying        | YES
fiscal_data    | jsonb                    | YES
```

### **2. Verificar Índices**

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'companies'
  AND indexname LIKE '%fiscal%' OR indexname LIKE '%bank%'
ORDER BY indexname;
```

**Resultado esperado:**
```
idx_companies_bank_data     | CREATE INDEX ... USING gin (bank_data)
idx_companies_fiscal_country| CREATE INDEX ... USING btree (fiscal_country)
idx_companies_fiscal_data   | CREATE INDEX ... USING gin (fiscal_data)
```

### **3. Verificar Tabela de Auditoria**

```sql
SELECT 
  table_name,
  (SELECT count(*) FROM information_schema.columns WHERE table_name = 'companies_fiscal_bank_audit_log') as column_count,
  (SELECT count(*) FROM pg_indexes WHERE tablename = 'companies_fiscal_bank_audit_log') as index_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'companies_fiscal_bank_audit_log';
```

**Resultado esperado:**
```
table_name                          | column_count | index_count
companies_fiscal_bank_audit_log     | 11           | 6
```

### **4. Verificar RLS Policies**

```sql
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'companies_fiscal_bank_audit_log'
ORDER BY policyname;
```

**Resultado esperado:**
```
Only admins and gestors can insert audit logs          | INSERT | ...
Users can view audit logs for companies in their org   | SELECT | ...
```

---

## 🧪 Teste Rápido

### **1. Testar Inserção de Dados**

```sql
-- Buscar uma empresa existente
SELECT id, name FROM companies LIMIT 1;

-- Atualizar com dados fiscais de teste (substitua o UUID)
UPDATE companies
SET 
  fiscal_country = 'BR',
  fiscal_data = '{
    "current_country": "BR",
    "current_person_type": "business",
    "BR": {
      "business": {
        "cnpj": "12.345.678/0001-90",
        "legal_name": "Empresa Teste Ltda"
      }
    }
  }'::jsonb,
  bank_data = '{
    "BR": {
      "bank_name": "Banco Teste",
      "agency": "1234-5",
      "account": "12345-6",
      "pix_key": "teste@email.com"
    }
  }'::jsonb
WHERE id = 'SEU-UUID-AQUI';
```

### **2. Verificar Dados Salvos**

```sql
SELECT 
  id,
  name,
  fiscal_country,
  fiscal_data->'BR'->'business'->>'cnpj' as cnpj,
  bank_data->'BR'->>'bank_name' as banco
FROM companies
WHERE fiscal_country IS NOT NULL
LIMIT 5;
```

---

## 🔄 Rollback (Se Necessário)

Se algo der errado e você precisar reverter:

```sql
-- ATENÇÃO: Isso vai DELETAR os dados fiscais/bancários JSONB!

-- Remover tabela de auditoria
DROP TABLE IF EXISTS public.companies_fiscal_bank_audit_log CASCADE;

-- Remover índices
DROP INDEX IF EXISTS public.idx_companies_fiscal_data;
DROP INDEX IF EXISTS public.idx_companies_bank_data;
DROP INDEX IF EXISTS public.idx_companies_fiscal_country;

-- Remover colunas
ALTER TABLE public.companies DROP COLUMN IF EXISTS fiscal_data;
ALTER TABLE public.companies DROP COLUMN IF EXISTS bank_data;
ALTER TABLE public.companies DROP COLUMN IF EXISTS fiscal_country;
```

**⚠️ AVISO:** Isso vai deletar todos os dados fiscais e bancários JSONB. Use apenas se realmente necessário!

---

## 📊 Próximos Passos Após a Instalação

### **Imediato**
1. ✅ Testar criação de nova empresa
2. ✅ Testar atualização de empresa existente
3. ✅ Verificar se dados antigos foram preservados

### **Curto Prazo**
4. ⏳ Criar interface de usuário para gerenciar dados fiscais/bancários
5. ⏳ Implementar `CompanyFiscalBankDataService`
6. ⏳ Adicionar validações específicas por país

### **Médio Prazo**
7. ⏳ Migrar dados antigos para JSONB (opcional)
8. ⏳ Criar relatórios de auditoria
9. ⏳ Adicionar mais países

---

## 📚 Documentação Relacionada

- **Guia Completo:** `docs/COMPANIES_FISCAL_BANK_UPDATE.md`
- **Resumo Executivo:** `docs/RESUMO_ATUALIZACAO_EMPRESAS.md`
- **Script SQL Completo:** `supabase/migrations/APPLY_COMPANIES_FISCAL_BANK_UPDATE.sql`

---

## 🆘 Problemas Comuns

### **Erro: "relation companies_fiscal_bank_audit_log already exists"**

**Solução:** A tabela já foi criada. Você pode:
1. Ignorar o erro (não afeta nada)
2. Ou executar: `DROP TABLE IF EXISTS companies_fiscal_bank_audit_log CASCADE;` antes de rodar novamente

### **Erro: "column fiscal_data already exists"**

**Solução:** Os campos já foram adicionados. Você pode:
1. Ignorar o erro (não afeta nada)
2. Ou pular a parte 1 do script

### **Erro: "permission denied"**

**Solução:** Você precisa de permissões de administrador. Entre em contato com o owner do projeto.

---

## ✅ Checklist Final

Antes de considerar a instalação completa, verifique:

- [ ] Campos `fiscal_data`, `bank_data` e `fiscal_country` existem na tabela `companies`
- [ ] Índices GIN foram criados para os campos JSONB
- [ ] Tabela `companies_fiscal_bank_audit_log` foi criada
- [ ] RLS está habilitado na tabela de auditoria
- [ ] 2 políticas RLS foram criadas
- [ ] Teste de inserção funcionou corretamente
- [ ] Dados antigos foram preservados

---

## 🎉 Conclusão

Após seguir estas instruções, a tabela `companies` terá **paridade completa** com a tabela `organizations` em termos de dados fiscais e bancários!

**Status:** ✅ Pronto para uso  
**Compatibilidade:** ✅ 100% retrocompatível  
**Próximo passo:** Criar interface de usuário para gerenciar os dados

