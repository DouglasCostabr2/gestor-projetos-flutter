# 🔧 Como Aplicar CASCADE DELETE no Supabase

## 📋 O Que É CASCADE DELETE?

**CASCADE DELETE** é uma funcionalidade do banco de dados que **automaticamente** deleta registros relacionados quando você deleta um registro pai.

### Exemplo Prático:

**ANTES (Sem CASCADE):**
```
Você deleta um Cliente
❌ Projetos do cliente ficam órfãos no banco
❌ Tarefas dos projetos ficam órfãs
❌ Você precisa limpar manualmente
```

**DEPOIS (Com CASCADE):**
```
Você deleta um Cliente
✅ Banco deleta automaticamente todos os Projetos
✅ Banco deleta automaticamente todas as Tarefas
✅ Banco deleta automaticamente todos os Arquivos
✅ Banco deleta automaticamente todos os Comentários
✅ Tudo limpo automaticamente!
```

---

## 🚀 Como Aplicar a Migration

### **Opção 1: Via Supabase Dashboard (Recomendado)**

1. **Acesse o Supabase Dashboard**
   - Vá para: https://supabase.com/dashboard
   - Faça login na sua conta
   - Selecione seu projeto

2. **Abra o SQL Editor**
   - No menu lateral, clique em **"SQL Editor"**
   - Clique em **"New Query"**

3. **Cole o SQL**
   - Abra o arquivo: `supabase/migrations/add_cascade_delete.sql`
   - Copie TODO o conteúdo
   - Cole no SQL Editor do Supabase

4. **Execute a Migration**
   - Clique em **"Run"** (ou pressione Ctrl+Enter)
   - Aguarde a confirmação de sucesso

5. **Verifique**
   - Você deve ver mensagens de sucesso
   - Todas as constraints foram atualizadas

---

### **Opção 2: Via Supabase CLI (Avançado)**

Se você tem o Supabase CLI instalado:

```bash
# 1. Fazer login
supabase login

# 2. Linkar ao projeto
supabase link --project-ref SEU_PROJECT_REF

# 3. Aplicar migration
supabase db push
```

---

## ✅ O Que a Migration Faz

### **1. Clientes → Projetos**
```sql
DELETE FROM clients WHERE id = 'xxx';
-- Deleta automaticamente:
-- ✅ Todos os projetos do cliente
-- ✅ Todas as empresas do cliente
```

### **2. Projetos → Tarefas**
```sql
DELETE FROM projects WHERE id = 'xxx';
-- Deleta automaticamente:
-- ✅ Todas as tarefas do projeto
-- ✅ Todos os pagamentos do projeto
-- ✅ Todos os custos adicionais
-- ✅ Todos os itens do catálogo
-- ✅ Todos os membros do projeto
```

### **3. Tarefas → Subtarefas**
```sql
DELETE FROM tasks WHERE id = 'xxx';
-- Deleta automaticamente:
-- ✅ Todas as subtarefas
-- ✅ Todos os arquivos da tarefa
-- ✅ Todos os comentários da tarefa
```

---

## 🎯 Benefícios

### **Antes (Sem CASCADE):**
- ❌ Registros órfãos acumulam no banco
- ❌ Estatísticas incorretas
- ❌ Precisa limpar manualmente
- ❌ Risco de inconsistência

### **Depois (Com CASCADE):**
- ✅ Banco sempre limpo
- ✅ Estatísticas sempre corretas
- ✅ Limpeza automática
- ✅ Integridade garantida

---

## ⚠️ IMPORTANTE - Backup

**ANTES de aplicar a migration, faça um backup!**

### Como fazer backup no Supabase:

1. Vá para **Database** → **Backups**
2. Clique em **"Create Backup"**
3. Aguarde a conclusão
4. Depois aplique a migration

---

## 🧪 Como Testar Depois

### **Teste 1: Deletar Cliente**

1. Crie um cliente de teste
2. Crie um projeto para esse cliente
3. Crie uma tarefa para esse projeto
4. Delete o cliente
5. **Verifique:** Projeto e tarefa devem ter sido deletados automaticamente

### **Teste 2: Deletar Projeto**

1. Crie um projeto
2. Crie várias tarefas
3. Delete o projeto
4. **Verifique:** Todas as tarefas devem ter sido deletadas automaticamente

### **Teste 3: Deletar Tarefa Pai**

1. Crie uma tarefa
2. Crie várias subtarefas
3. Delete a tarefa pai
4. **Verifique:** Todas as subtarefas devem ter sido deletadas automaticamente

---

## 📊 Estrutura de Cascata

```
CLIENTE
  ├─ PROJETOS (CASCADE)
  │   ├─ TAREFAS (CASCADE)
  │   │   ├─ SUBTAREFAS (CASCADE)
  │   │   ├─ ARQUIVOS (CASCADE)
  │   │   └─ COMENTÁRIOS (CASCADE)
  │   ├─ PAGAMENTOS (CASCADE)
  │   ├─ CUSTOS ADICIONAIS (CASCADE)
  │   ├─ ITENS DO CATÁLOGO (CASCADE)
  │   └─ MEMBROS (CASCADE)
  └─ EMPRESAS (CASCADE)
```

---

## 🔍 Verificar Se Foi Aplicado

Depois de aplicar, você pode verificar se funcionou:

```sql
-- Verificar constraints de projects
SELECT 
    conname AS constraint_name,
    confdeltype AS delete_action
FROM pg_constraint
WHERE conrelid = 'projects'::regclass
AND contype = 'f';

-- Se delete_action = 'c', significa CASCADE está ativo!
```

---

## 💡 Dica Final

Depois de aplicar a migration:

1. **Teste deletando um cliente de teste**
2. **Verifique se os projetos foram deletados automaticamente**
3. **Clique em "Atualizar Estatísticas" no painel de admin**
4. **Os números devem estar corretos agora!**

---

## 🆘 Problemas?

Se algo der errado:

1. **Restaure o backup** que você fez antes
2. **Verifique os logs de erro** no Supabase
3. **Entre em contato** para ajuda

---

## ✅ Conclusão

Depois de aplicar esta migration:

- ✅ **Nunca mais** terá registros órfãos
- ✅ **Nunca mais** precisará clicar em "Limpar Órfãos"
- ✅ **Sempre** terá estatísticas corretas
- ✅ **Banco de dados** sempre limpo e consistente

**É só aplicar UMA VEZ e esquecer! O banco cuida de tudo automaticamente.** 🚀

