# 🚀 EXECUTAR MIGRATION - Sistema de Rastreamento de Tempo

## ⚠️ IMPORTANTE

Esta migration cria o sistema completo de rastreamento de tempo (cronômetro) para tarefas.

**DEVE SER EXECUTADA ANTES DE USAR O SISTEMA DE CRONÔMETRO!**

---

## 📋 O que a Migration Faz

### 1. Cria Tabela `time_logs`

Armazena registros de sessões de trabalho:
- `id`: UUID único
- `task_id`: Referência à tarefa
- `user_id`: Usuário que registrou o tempo
- `start_time`: Data/hora de início
- `end_time`: Data/hora de fim (NULL se em andamento)
- `duration_seconds`: Duração em segundos (calculado automaticamente)
- `created_at`: Data de criação
- `updated_at`: Data de atualização

### 2. Adiciona Campo `total_time_spent` em `tasks`

Campo para armazenar o tempo total acumulado em segundos.

### 3. Cria Índices para Performance

- Buscar time_logs por tarefa
- Buscar time_logs por usuário
- Ordenar por data de início
- Buscar sessões ativas (end_time NULL)

### 4. Cria Triggers Automáticos

- **calculate_duration_trigger**: Calcula duração quando end_time é definido
- **time_log_insert_trigger**: Atualiza total_time_spent ao inserir
- **time_log_update_trigger**: Atualiza total_time_spent ao atualizar
- **time_log_delete_trigger**: Atualiza total_time_spent ao deletar

### 5. Configura RLS (Row Level Security)

Políticas de segurança:
- Usuários podem ver time_logs de tarefas que têm acesso
- Usuários podem criar time_logs apenas para tarefas atribuídas a eles
- Usuários podem atualizar/deletar apenas seus próprios time_logs

---

## 🔧 Como Executar

### Opção 1: Via Supabase Dashboard (Recomendado)

1. **Acesse o Supabase Dashboard**
   - URL: https://app.supabase.com
   - Faça login com sua conta

2. **Selecione o Projeto**
   - Clique no projeto `gestor_projetos_flutter`

3. **Abra o SQL Editor**
   - No menu lateral, clique em **SQL Editor**
   - Clique em **New Query**

4. **Cole o SQL**
   - Abra o arquivo: `supabase/migrations/2025-10-13_create_time_tracking.sql`
   - Copie TODO o conteúdo
   - Cole no editor SQL

5. **Execute**
   - Clique em **Run** (ou pressione Ctrl+Enter)
   - Aguarde a mensagem de sucesso

6. **Verifique**
   - Você deve ver mensagens de sucesso no console
   - Verifique se a tabela `time_logs` foi criada em **Table Editor**

### Opção 2: Via Supabase CLI

```bash
# Se você tem o Supabase CLI instalado
cd c:\Users\PC\Downloads\gestor_projetos_flutter
supabase db push
```

---

## ✅ Verificar se Funcionou

Execute estas queries no SQL Editor para verificar:

### 1. Verificar Tabela `time_logs`

```sql
SELECT * FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name = 'time_logs';
```

**Resultado esperado**: 1 linha retornada

### 2. Verificar Campo `total_time_spent` em `tasks`

```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'tasks' 
AND column_name = 'total_time_spent';
```

**Resultado esperado**: 1 linha com `data_type = integer` e `column_default = 0`

### 3. Verificar Índices

```sql
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'time_logs';
```

**Resultado esperado**: 4 índices
- `idx_time_logs_task_id`
- `idx_time_logs_user_id`
- `idx_time_logs_start_time`
- `idx_time_logs_active`

### 4. Verificar Triggers

```sql
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'time_logs';
```

**Resultado esperado**: 4 triggers
- `calculate_duration_trigger`
- `time_log_insert_trigger`
- `time_log_update_trigger`
- `time_log_delete_trigger`

### 5. Verificar RLS

```sql
SELECT tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'time_logs';
```

**Resultado esperado**: 4 políticas
- `Users can view time logs of accessible tasks`
- `Users can insert time logs for assigned tasks`
- `Users can update own time logs`
- `Users can delete own time logs`

---

## 🧪 Testar Funcionalidade

Após executar a migration, teste o sistema:

### 1. Abrir uma Tarefa

1. Execute o aplicativo
2. Navegue até **Tarefas**
3. Clique em uma tarefa da qual você é responsável

### 2. Usar o Cronômetro

1. Você deve ver o widget de cronômetro
2. Clique em **Iniciar**
3. O tempo deve começar a contar
4. Clique em **Pausar** para pausar
5. Clique em **Retomar** para continuar
6. Clique em **Parar** para finalizar e salvar

### 3. Verificar Histórico

1. Abaixo do cronômetro, você deve ver o histórico
2. A sessão que você acabou de criar deve aparecer
3. O tempo total deve estar correto

### 4. Verificar Persistência

1. Inicie o cronômetro
2. Feche o aplicativo
3. Reabra o aplicativo
4. Abra a mesma tarefa
5. O cronômetro deve continuar de onde parou

---

## 🐛 Troubleshooting

### Erro: "relation time_logs does not exist"

**Causa**: A migration não foi executada

**Solução**: Execute a migration conforme instruções acima

### Erro: "permission denied for table time_logs"

**Causa**: RLS não foi configurado corretamente

**Solução**: 
1. Execute a migration novamente
2. Verifique se as políticas RLS foram criadas

### Erro: "column total_time_spent does not exist"

**Causa**: O campo não foi adicionado à tabela tasks

**Solução**: Execute a migration novamente

### Cronômetro não aparece

**Causa**: Você não é o responsável pela tarefa

**Solução**: 
1. Atribua a tarefa a você mesmo
2. Ou abra uma tarefa da qual você já é responsável

### Tempo total não atualiza

**Causa**: Triggers não estão funcionando

**Solução**:
1. Verifique se os triggers foram criados
2. Execute a migration novamente
3. Verifique logs do Supabase

---

## 📊 Estrutura Criada

```
Banco de Dados (Supabase)
├── Tabelas
│   ├── time_logs (NOVA)
│   └── tasks (campo total_time_spent adicionado)
│
├── Índices
│   ├── idx_time_logs_task_id
│   ├── idx_time_logs_user_id
│   ├── idx_time_logs_start_time
│   └── idx_time_logs_active
│
├── Funções
│   ├── calculate_time_log_duration()
│   └── update_task_total_time()
│
├── Triggers
│   ├── calculate_duration_trigger
│   ├── time_log_insert_trigger
│   ├── time_log_update_trigger
│   └── time_log_delete_trigger
│
└── Políticas RLS
    ├── Users can view time logs of accessible tasks
    ├── Users can insert time logs for assigned tasks
    ├── Users can update own time logs
    └── Users can delete own time logs
```

---

## 📚 Documentação Adicional

Para mais informações sobre o sistema de rastreamento de tempo, consulte:

- **Documentação Completa**: `docs/TIME_TRACKING_SYSTEM.md`
- **Código do Módulo**: `lib/modules/time_tracking/`
- **Widgets**: `lib/src/features/tasks/widgets/task_timer_widget.dart`
- **Serviço**: `lib/services/task_timer_service.dart`

---

## ✅ Checklist de Execução

- [ ] Migration executada no Supabase
- [ ] Tabela `time_logs` criada
- [ ] Campo `total_time_spent` adicionado em `tasks`
- [ ] Índices criados
- [ ] Triggers criados
- [ ] RLS configurado
- [ ] Aplicativo executado
- [ ] Cronômetro testado
- [ ] Histórico verificado
- [ ] Persistência testada

---

**Data da Migration**: 2025-10-13  
**Versão**: 1.0.0  
**Status**: ✅ Pronto para execução

