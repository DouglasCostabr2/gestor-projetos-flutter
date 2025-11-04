# 📊 Sistema de Rastreamento de Tempo (Time Tracking)

## 📋 Visão Geral

Sistema completo de cronômetro para rastreamento de tempo gasto em tarefas, com persistência automática, sincronização com banco de dados e retomada automática ao reabrir o aplicativo.

---

## 🎯 Funcionalidades

### ✅ Implementadas

1. **Cronômetro por Tarefa**
   - Controles Play/Pause/Stop
   - Display em formato HH:MM:SS
   - Apenas o responsável (assigned_to) pode usar
   - Estado persistente (continua após fechar app)

2. **Persistência Automática**
   - Estado salvo em SharedPreferences
   - Sincronização com Supabase
   - Retomada automática ao reabrir app

3. **Histórico de Tempo**
   - Lista de todas as sessões de trabalho
   - Tempo total acumulado
   - Informações de usuário e data/hora
   - Opção de deletar sessões próprias

4. **Banco de Dados**
   - Tabela `time_logs` para registros de sessões
   - Campo `total_time_spent` em tasks
   - Triggers automáticos para cálculo de duração
   - RLS (Row Level Security) configurado

---

## 🗄️ Estrutura do Banco de Dados

### Tabela `time_logs`

```sql
CREATE TABLE public.time_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL,
  end_time timestamptz,
  duration_seconds integer,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

**Campos:**
- `id`: UUID único do registro
- `task_id`: Referência à tarefa
- `user_id`: Usuário que registrou o tempo
- `start_time`: Data/hora de início da sessão
- `end_time`: Data/hora de fim (NULL se em andamento)
- `duration_seconds`: Duração em segundos (calculado automaticamente)
- `created_at`: Data/hora de criação
- `updated_at`: Data/hora da última atualização

### Campo em `tasks`

```sql
ALTER TABLE public.tasks 
ADD COLUMN total_time_spent integer DEFAULT 0;
```

**Campo:**
- `total_time_spent`: Tempo total acumulado em segundos (soma de todas as sessões)

### Índices

```sql
-- Buscar time_logs por tarefa
CREATE INDEX idx_time_logs_task_id ON public.time_logs(task_id);

-- Buscar time_logs por usuário
CREATE INDEX idx_time_logs_user_id ON public.time_logs(user_id);

-- Ordenar por data de início
CREATE INDEX idx_time_logs_start_time ON public.time_logs(start_time DESC);

-- Buscar sessões ativas
CREATE INDEX idx_time_logs_active ON public.time_logs(task_id, user_id) 
WHERE end_time IS NULL;
```

---

## 🏗️ Arquitetura

### Módulo `time_tracking`

Localização: `lib/modules/time_tracking/`

**Arquivos:**
- `contract.dart` - Interface pública (TimeTrackingContract)
- `repository.dart` - Implementação com Supabase
- `models.dart` - Modelos de dados (TimeLog, UserTimeStats)
- `module.dart` - Exportação pública

**Instância Global:**
```dart
import 'package:gestor_projetos_flutter/modules/modules.dart';

// Usar o módulo
await timeTrackingModule.startTimeLog(taskId: 'task-id');
```

### Serviço `TaskTimerService`

Localização: `lib/services/task_timer_service.dart`

**Responsabilidades:**
- Gerenciar estado do timer (running/paused/stopped)
- Persistir estado em SharedPreferences
- Sincronizar com banco de dados
- Retomar automaticamente ao reabrir app
- Notificar listeners sobre mudanças

**Uso:**
```dart
import 'package:gestor_projetos_flutter/services/task_timer_service.dart';

// Iniciar timer
await taskTimerService.start('task-id');

// Pausar
await taskTimerService.pause();

// Retomar
await taskTimerService.resume();

// Parar e salvar
await taskTimerService.stop();

// Verificar se está ativo
bool isActive = taskTimerService.isActiveForTask('task-id');

// Obter tempo formatado
String time = taskTimerService.getFormattedTime(); // "01:23:45"
```

### Widgets

#### `TaskTimerWidget`

Localização: `lib/src/features/tasks/widgets/task_timer_widget.dart`

Widget de cronômetro com controles Play/Pause/Stop.

**Uso:**
```dart
TaskTimerWidget(
  taskId: task['id'],
  assignedTo: task['assigned_to'],
)
```

**Características:**
- Display do tempo (HH:MM:SS)
- Botões de controle
- Verificação de permissões
- Tema dark integrado
- Indicador visual quando ativo

#### `TaskTimeHistoryWidget`

Localização: `lib/src/features/tasks/widgets/task_time_history_widget.dart`

Widget de histórico de sessões de tempo.

**Uso:**
```dart
TaskTimeHistoryWidget(
  taskId: task['id'],
)
```

**Características:**
- Lista de sessões ordenadas por data
- Tempo total acumulado
- Avatar e nome do usuário
- Data/hora de início e fim
- Duração formatada
- Opção de deletar (apenas próprias sessões)

---

## 🚀 Como Usar

### 1. Executar Migration

Execute a migration no Supabase SQL Editor:

```bash
# Arquivo: supabase/migrations/2025-10-13_create_time_tracking.sql
```

**Passos:**
1. Acesse [Supabase Dashboard](https://app.supabase.com)
2. Selecione seu projeto
3. Vá em **SQL Editor**
4. Clique em **New Query**
5. Cole o conteúdo do arquivo de migration
6. Clique em **Run**

### 2. Usar na Interface

O cronômetro aparece automaticamente no `TaskDetailPage` para o usuário responsável pela tarefa.

**Fluxo:**
1. Abrir uma tarefa (TaskDetailPage)
2. Se você é o responsável (assigned_to), verá o widget de cronômetro
3. Clicar em "Iniciar" para começar a contar o tempo
4. Clicar em "Pausar" para pausar (mantém a sessão ativa)
5. Clicar em "Retomar" para continuar
6. Clicar em "Parar" para finalizar e salvar a sessão

### 3. Ver Histórico

O histórico de tempo aparece logo abaixo do cronômetro, mostrando:
- Todas as sessões de trabalho
- Tempo total acumulado
- Usuário que registrou
- Data e hora de cada sessão
- Duração de cada sessão

---

## 🔒 Permissões e Segurança

### RLS (Row Level Security)

**Políticas Configuradas:**

1. **SELECT**: Usuários podem ver time_logs de tarefas que têm acesso
2. **INSERT**: Usuários podem criar time_logs apenas para tarefas atribuídas a eles
3. **UPDATE**: Usuários podem atualizar apenas seus próprios time_logs
4. **DELETE**: Usuários podem deletar apenas seus próprios time_logs

### Verificações no Frontend

- Apenas o responsável (assigned_to) vê o widget de cronômetro
- Botões desabilitados durante operações
- Confirmação antes de parar o cronômetro
- Validações de permissão antes de cada ação

---

## 📊 Triggers e Automações

### 1. Cálculo Automático de Duração

```sql
CREATE TRIGGER calculate_duration_trigger
  BEFORE INSERT OR UPDATE ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.calculate_time_log_duration();
```

Quando `end_time` é definido, calcula automaticamente `duration_seconds`.

### 2. Atualização de Tempo Total

```sql
CREATE TRIGGER time_log_insert_trigger
  AFTER INSERT ON public.time_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_task_total_time();
```

Atualiza `tasks.total_time_spent` sempre que um time_log é inserido, atualizado ou deletado.

---

## 🧪 Testes

### Cenários de Teste

1. **Iniciar Timer**
   - ✅ Apenas responsável pode iniciar
   - ✅ Não pode iniciar se já existe sessão ativa
   - ✅ Cria registro no banco com start_time

2. **Pausar/Retomar**
   - ✅ Mantém sessão ativa no banco
   - ✅ Estado salvo em SharedPreferences
   - ✅ Tempo continua acumulando ao retomar

3. **Parar Timer**
   - ✅ Define end_time no banco
   - ✅ Calcula duration_seconds automaticamente
   - ✅ Atualiza total_time_spent da tarefa
   - ✅ Limpa estado local

4. **Persistência**
   - ✅ Timer continua após fechar app
   - ✅ Retoma automaticamente ao reabrir
   - ✅ Sincroniza com banco ao retomar

5. **Histórico**
   - ✅ Lista todas as sessões
   - ✅ Mostra tempo total correto
   - ✅ Permite deletar apenas próprias sessões

---

## 🐛 Troubleshooting

### Timer não retoma ao reabrir app

**Causa**: Estado não foi salvo ou time_log foi deletado no banco

**Solução**:
1. Verificar se SharedPreferences está funcionando
2. Verificar se o time_log ainda existe no banco
3. Verificar logs no console

### Tempo total não atualiza

**Causa**: Triggers não estão funcionando

**Solução**:
1. Verificar se os triggers foram criados corretamente
2. Executar a migration novamente
3. Verificar logs do Supabase

### Erro de permissão ao iniciar timer

**Causa**: Usuário não é o responsável pela tarefa

**Solução**:
1. Verificar se `assigned_to` está correto
2. Verificar se o usuário está autenticado
3. Verificar políticas RLS no Supabase

---

## 📈 Melhorias Futuras

### Possíveis Extensões

1. **Relatórios de Tempo**
   - Gráficos de tempo por tarefa
   - Tempo por usuário
   - Tempo por projeto
   - Exportação para CSV/PDF

2. **Estimativas vs Real**
   - Comparar tempo estimado vs tempo real
   - Alertas quando ultrapassar estimativa
   - Métricas de precisão

3. **Integração com Calendário**
   - Sincronizar sessões com Google Calendar
   - Bloqueios de tempo automáticos

4. **Notificações**
   - Lembrete para parar timer ao fim do dia
   - Notificação de tempo acumulado

5. **Edição de Sessões**
   - Permitir editar start_time e end_time
   - Mesclar sessões
   - Dividir sessões

---

## 📚 Referências

- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Timer](https://api.flutter.dev/flutter/dart-async/Timer-class.html)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

