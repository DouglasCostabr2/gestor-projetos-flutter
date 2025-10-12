# Histórico de Alterações de Tarefas

## Descrição

Este sistema registra automaticamente todas as alterações feitas nas tarefas, criando um log de auditoria completo.

## Como Executar a Migration

### Opção 1: Via Supabase Dashboard (Recomendado)

1. Acesse o [Supabase Dashboard](https://app.supabase.com)
2. Selecione seu projeto
3. Vá em **SQL Editor** no menu lateral
4. Clique em **New Query**
5. Copie todo o conteúdo do arquivo `2025-10-02_task_history.sql`
6. Cole no editor e clique em **Run**

### Opção 2: Via CLI do Supabase

```bash
# Se você tem o Supabase CLI instalado
supabase db push
```

## O que a Migration Faz

### 1. Cria a Tabela `task_history`

Armazena o histórico de todas as alterações:

- `id`: UUID único do registro
- `task_id`: Referência à tarefa alterada
- `user_id`: Usuário que fez a alteração
- `action`: Tipo de ação (created, updated, deleted)
- `field_name`: Nome do campo alterado
- `old_value`: Valor anterior
- `new_value`: Novo valor
- `created_at`: Data/hora da alteração

### 2. Cria Índices

Para melhor performance nas consultas:
- Por task_id
- Por user_id
- Por created_at (descendente)

### 3. Configura RLS (Row Level Security)

Políticas de segurança:
- Usuários podem ver histórico apenas de tarefas que têm acesso
- Apenas o sistema pode inserir registros (via trigger)

### 4. Cria Trigger Automático

O trigger `log_task_changes()` registra automaticamente:

**Na criação (INSERT):**
- Registra que a tarefa foi criada

**Na atualização (UPDATE):**
- Título alterado
- Descrição alterada
- Status alterado
- Prioridade alterada
- Responsável alterado
- Prazo alterado

**Na exclusão (DELETE):**
- Registra que a tarefa foi excluída

## Como Usar no App

O histórico aparece automaticamente no formulário de edição de tarefas:

1. Abra uma tarefa existente para editar
2. Role até o final do formulário
3. Clique em **"Histórico de Alterações"** para expandir
4. Veja todas as mudanças feitas na tarefa

## Exemplo de Registros

```
João Silva criou a tarefa
há 2 dias às 14:30

Maria Santos alterou Status de "A Fazer" para "Em Progresso"
há 1 dia às 09:15

Pedro Costa alterou Responsável de "não atribuído" para "João Silva"
há 5 horas às 16:45

Ana Oliveira alterou Prazo de "15/10/2025" para "20/10/2025"
há 2 horas às 18:20
```

## Campos Rastreados

- ✅ Título
- ✅ Descrição (primeiros 100 caracteres)
- ✅ Status
- ✅ Prioridade
- ✅ Responsável
- ✅ Prazo
- ✅ Criação/Exclusão da tarefa

## Benefícios

1. **Auditoria Completa**: Saiba quem fez o quê e quando
2. **Transparência**: Histórico visível para toda a equipe
3. **Rastreabilidade**: Acompanhe a evolução da tarefa
4. **Segurança**: Registros imutáveis protegidos por RLS
5. **Automático**: Nenhuma ação manual necessária

## Troubleshooting

### Erro: "relation task_history does not exist"

Execute a migration no Supabase SQL Editor.

### Histórico não aparece

Verifique se:
1. A migration foi executada com sucesso
2. A tarefa já existe (tarefas novas não têm histórico ainda)
3. Você tem permissão para ver a tarefa

### Performance lenta

Os índices devem resolver isso, mas se necessário:
```sql
-- Recriar índices
REINDEX TABLE task_history;
```

## Manutenção

### Limpar histórico antigo (opcional)

Se quiser manter apenas os últimos 90 dias:

```sql
DELETE FROM task_history 
WHERE created_at < NOW() - INTERVAL '90 days';
```

### Ver estatísticas

```sql
-- Total de alterações por tarefa
SELECT task_id, COUNT(*) as total_changes
FROM task_history
GROUP BY task_id
ORDER BY total_changes DESC
LIMIT 10;

-- Usuários mais ativos
SELECT user_id, COUNT(*) as total_actions
FROM task_history
GROUP BY user_id
ORDER BY total_actions DESC
LIMIT 10;
```

