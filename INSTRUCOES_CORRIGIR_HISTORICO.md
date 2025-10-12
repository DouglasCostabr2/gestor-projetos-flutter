# 🔧 Instruções para Corrigir Histórico de Alterações

## ❌ Problema Identificado

O histórico de alterações **NÃO estava registrando** mudanças na descrição (briefing) das tasks.

## ✅ Solução Implementada

### 1. **Código Flutter Atualizado** ✓

O código Flutter já foi atualizado:
- ✅ Widget de histórico agora mostra "Briefing" ao invés de "Descrição"
- ✅ Formatação melhorada para exibir "editado" ao invés de JSON truncado

### 2. **Banco de Dados - REQUER AÇÃO** ⚠️

Você precisa executar um script SQL no Supabase para atualizar a função trigger.

## 📋 Passo a Passo

### **Passo 1: Acessar o Supabase**

1. Acesse https://supabase.com
2. Faça login na sua conta
3. Selecione o projeto `gestor_projetos_flutter`

### **Passo 2: Abrir o SQL Editor**

1. No menu lateral, clique em **"SQL Editor"**
2. Clique em **"New query"**

### **Passo 3: Executar o Script**

1. Copie todo o conteúdo do arquivo `APLICAR_FIX_DESCRIPTION_HISTORY.sql`
2. Cole no SQL Editor
3. Clique em **"Run"** (ou pressione Ctrl+Enter)

### **Passo 4: Verificar se Funcionou**

Após executar o script, você deve ver:

```
Query executed successfully
```

E uma tabela mostrando:

| trigger_name | enabled | function_name |
|--------------|---------|---------------|
| task_changes_trigger | O | log_task_changes |

✅ Se `enabled` = **'O'** → Trigger está **ATIVO** (correto!)
❌ Se `enabled` = **'D'** → Trigger está **DESABILITADO** (execute o comando abaixo)

Se estiver desabilitado, execute:

```sql
ALTER TABLE public.tasks ENABLE TRIGGER task_changes_trigger;
```

## 🧪 Como Testar

Após aplicar a correção:

1. **Abra o app Flutter**
2. **Edite uma task existente**
3. **Altere o briefing** (descrição)
4. **Salve a task**
5. **Abra o histórico de alterações**
6. **Você deve ver**: "Douglas Costa alterou o Briefing"

## 📝 O Que Mudou

### Antes:
- ❌ Descrição não era registrada no histórico
- ❌ Quando registrada, mostrava JSON truncado: `[{"insert":"texto...`

### Depois:
- ✅ Descrição é registrada no histórico
- ✅ Mostra mensagem simples: "alterou o Briefing"
- ✅ Não mostra valores antigos/novos (pois o briefing pode ser muito grande)

## 🎯 Campos Rastreados

Após a correção, o histórico registra mudanças em:

1. ✅ **Título** (title)
2. ✅ **Briefing** (description) ← **CORRIGIDO!**
3. ✅ **Status** (status)
4. ✅ **Prioridade** (priority)
5. ✅ **Responsável** (assigned_to)
6. ✅ **Prazo** (due_date)

## ⚠️ Importante

- Esta correção **NÃO afeta** registros antigos do histórico
- Apenas **novas alterações** (após aplicar o script) serão registradas corretamente
- O trigger já existia, apenas foi **melhorado** para mostrar mensagens mais claras

## 🆘 Problemas?

Se após executar o script você ainda não ver alterações de briefing no histórico:

1. Verifique se o trigger está ativo (Passo 4)
2. Tente fazer uma nova alteração em uma task
3. Verifique os logs do console do Flutter para erros
4. Me avise se o problema persistir!

