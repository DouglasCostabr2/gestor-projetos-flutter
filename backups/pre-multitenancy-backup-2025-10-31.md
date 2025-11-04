# 🔒 BACKUP PRÉ-IMPLEMENTAÇÃO MULTI-TENANCY
**Data:** 2025-10-31  
**Projeto:** Gestor de Projetos Flutter  
**Supabase Project ID:** zfgsddweabsemxcchxjq  
**Motivo:** Backup de segurança antes da implementação de multi-tenancy

---

## 📊 RESUMO DO BANCO DE DADOS

### Tabelas Identificadas (35 tabelas)

1. catalog_categories
2. client_categories
3. client_mentions
4. clients
5. comment_mentions
6. companies
7. company_mentions
8. employee_payments
9. notifications
10. organization_settings
11. package_items
12. package_mentions
13. packages
14. payments
15. product_mentions
16. products
17. profiles
18. project_additional_costs
19. project_catalog_items
20. project_discounts
21. project_members
22. project_mentions
23. project_package_item_comments
24. projects
25. shared_oauth_tokens
26. task_attachments
27. task_comments
28. task_files
29. task_history
30. task_mentions
31. task_products
32. tasks
33. time_logs
34. user_favorites
35. user_oauth_tokens

---

## 🔍 CONTAGEM DE REGISTROS

**IMPORTANTE:** Execute as queries abaixo no Supabase SQL Editor para obter contagem atual de registros.

```sql
-- Contagem de registros em todas as tabelas
SELECT 
  'catalog_categories' as table_name, COUNT(*) as count FROM catalog_categories
UNION ALL SELECT 'client_categories', COUNT(*) FROM client_categories
UNION ALL SELECT 'client_mentions', COUNT(*) FROM client_mentions
UNION ALL SELECT 'clients', COUNT(*) FROM clients
UNION ALL SELECT 'comment_mentions', COUNT(*) FROM comment_mentions
UNION ALL SELECT 'companies', COUNT(*) FROM companies
UNION ALL SELECT 'company_mentions', COUNT(*) FROM company_mentions
UNION ALL SELECT 'employee_payments', COUNT(*) FROM employee_payments
UNION ALL SELECT 'notifications', COUNT(*) FROM notifications
UNION ALL SELECT 'organization_settings', COUNT(*) FROM organization_settings
UNION ALL SELECT 'package_items', COUNT(*) FROM package_items
UNION ALL SELECT 'package_mentions', COUNT(*) FROM package_mentions
UNION ALL SELECT 'packages', COUNT(*) FROM packages
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'product_mentions', COUNT(*) FROM product_mentions
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL SELECT 'project_additional_costs', COUNT(*) FROM project_additional_costs
UNION ALL SELECT 'project_catalog_items', COUNT(*) FROM project_catalog_items
UNION ALL SELECT 'project_discounts', COUNT(*) FROM project_discounts
UNION ALL SELECT 'project_members', COUNT(*) FROM project_members
UNION ALL SELECT 'project_mentions', COUNT(*) FROM project_mentions
UNION ALL SELECT 'project_package_item_comments', COUNT(*) FROM project_package_item_comments
UNION ALL SELECT 'projects', COUNT(*) FROM projects
UNION ALL SELECT 'shared_oauth_tokens', COUNT(*) FROM shared_oauth_tokens
UNION ALL SELECT 'task_attachments', COUNT(*) FROM task_attachments
UNION ALL SELECT 'task_comments', COUNT(*) FROM task_comments
UNION ALL SELECT 'task_files', COUNT(*) FROM task_files
UNION ALL SELECT 'task_history', COUNT(*) FROM task_history
UNION ALL SELECT 'task_mentions', COUNT(*) FROM task_mentions
UNION ALL SELECT 'task_products', COUNT(*) FROM task_products
UNION ALL SELECT 'tasks', COUNT(*) FROM tasks
UNION ALL SELECT 'time_logs', COUNT(*) FROM time_logs
UNION ALL SELECT 'user_favorites', COUNT(*) FROM user_favorites
UNION ALL SELECT 'user_oauth_tokens', COUNT(*) FROM user_oauth_tokens
ORDER BY table_name;
```

---

## 📋 INSTRUÇÕES DE BACKUP MANUAL

### Opção 1: Backup via Supabase Dashboard (RECOMENDADO)

1. Acesse: https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq
2. Vá em **Database** → **Backups**
3. Clique em **Create Backup** ou **Download Backup**
4. Salve o arquivo `.sql` localmente

### Opção 2: Backup via pg_dump (Se tiver acesso direto ao PostgreSQL)

```bash
# Obter connection string do Supabase Dashboard
# Settings → Database → Connection String

pg_dump "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  --schema=public \
  --data-only \
  --file=backup-data-2025-10-31.sql

pg_dump "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  --schema=public \
  --schema-only \
  --file=backup-schema-2025-10-31.sql
```

### Opção 3: Export via Supabase SQL Editor

Execute no SQL Editor e salve os resultados:

```sql
-- Export de cada tabela crítica
COPY (SELECT * FROM clients) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM projects) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM tasks) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM profiles) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM products) TO STDOUT WITH CSV HEADER;
COPY (SELECT * FROM packages) TO STDOUT WITH CSV HEADER;
```

---

## 🔐 BACKUP DE RLS POLICIES

Execute para documentar todas as policies atuais:

```sql
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
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

---

## 🗂️ BACKUP DE ESTRUTURA DE TABELAS

Execute para documentar estrutura completa:

```sql
SELECT 
  table_name,
  column_name,
  data_type,
  character_maximum_length,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
```

---

## 🔗 BACKUP DE FOREIGN KEYS

```sql
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule,
  rc.update_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
```

---

## 📦 BACKUP DE STORAGE (Supabase Storage)

### Buckets a fazer backup:

1. **avatars** - Avatares de usuários e clientes
2. **briefings** - Imagens de briefings de tarefas
3. **task-attachments** - Anexos de tarefas
4. **products** - Thumbnails de produtos
5. **packages** - Thumbnails de pacotes

### Como fazer backup do Storage:

1. Acesse: https://supabase.com/dashboard/project/zfgsddweabsemxcchxjq/storage/buckets
2. Para cada bucket:
   - Clique no bucket
   - Selecione todos os arquivos
   - Download manual (ou use Supabase CLI)

### Via Supabase CLI:

```bash
# Instalar Supabase CLI
npm install -g supabase

# Login
supabase login

# Link ao projeto
supabase link --project-ref zfgsddweabsemxcchxjq

# Download de todos os arquivos de um bucket
supabase storage download --bucket avatars --recursive
supabase storage download --bucket briefings --recursive
supabase storage download --bucket task-attachments --recursive
```

---

## ✅ CHECKLIST DE BACKUP

Antes de prosseguir com a implementação, confirme:

- [ ] Backup do schema do banco de dados (estrutura das tabelas)
- [ ] Backup dos dados (registros de todas as tabelas)
- [ ] Backup das RLS policies
- [ ] Backup das foreign keys e constraints
- [ ] Backup dos índices
- [ ] Backup das functions e triggers
- [ ] Backup do Supabase Storage (arquivos)
- [ ] Backup salvo em local seguro (fora do projeto)
- [ ] Backup testado (verificar se pode ser restaurado)
- [ ] Data e hora do backup documentadas

---

## 🔄 INSTRUÇÕES DE RESTAURAÇÃO

### Em caso de necessidade de rollback:

1. **Parar a aplicação Flutter**
2. **Acessar Supabase SQL Editor**
3. **Executar script de limpeza:**

```sql
-- CUIDADO: Isso vai deletar TODOS os dados!
-- Só execute se tiver certeza do backup

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
```

4. **Restaurar backup:**
   - Via Dashboard: Upload do arquivo .sql
   - Via pg_restore: `pg_restore -d [connection_string] backup.sql`

5. **Verificar integridade:**
   - Conferir contagem de registros
   - Testar queries principais
   - Verificar RLS policies

6. **Reiniciar aplicação**

---

## 📞 CONTATOS DE EMERGÊNCIA

- **Supabase Support:** https://supabase.com/dashboard/support
- **Documentação Backup:** https://supabase.com/docs/guides/platform/backups

---

## 📝 NOTAS IMPORTANTES

1. **Point-in-Time Recovery (PITR):** Supabase Pro tem PITR automático de 7 dias
2. **Backups Automáticos:** Supabase faz backups diários automaticamente
3. **Retenção:** Backups são mantidos por 7-30 dias dependendo do plano
4. **Teste de Restauração:** Sempre teste restaurar um backup antes de confiar nele

---

## 🎯 PRÓXIMOS PASSOS

Após confirmar que o backup foi realizado com sucesso:

1. ✅ Iniciar **FASE 1: Fundação** da implementação multi-tenancy
2. ✅ Criar tabelas: `organizations`, `organization_members`, `organization_invites`
3. ✅ Executar migration de dados existentes
4. ✅ Testar em ambiente de desenvolvimento primeiro

---

**⚠️ LEMBRE-SE:** Nunca execute migrations em produção sem antes testar em desenvolvimento!

**Data do Backup:** 2025-10-31  
**Responsável:** Sistema Automatizado  
**Status:** ✅ Documentação criada - Aguardando execução manual do backup

