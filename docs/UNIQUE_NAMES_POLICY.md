# 🔒 Política de Nomes Únicos

## 📋 Visão Geral

Para garantir o funcionamento correto do **sistema de menções (@mentions)**, todos os usuários devem ter nomes únicos no sistema. Esta política evita ambiguidade ao mencionar usuários em comentários, tarefas e projetos.

## ⚠️ Restrição Implementada

### Constraint no Banco de Dados

```sql
ALTER TABLE public.profiles
ADD CONSTRAINT profiles_full_name_unique UNIQUE (full_name);
```

**O que isso significa:**
- ✅ Cada usuário deve ter um nome único
- ❌ Não é possível ter dois usuários com o mesmo nome
- ✅ A validação é feita no nível do banco de dados (garantia de integridade)

## 🎯 Por Que Nomes Únicos?

### Problema Sem Nomes Únicos

Imagine dois usuários chamados "João Silva":

```
Comentário: "Olá @João Silva, pode revisar isso?"
```

**Questão:** Qual João Silva foi mencionado? 🤔

### Solução Com Nomes Únicos

Com nomes únicos, não há ambiguidade:

```
Usuário 1: João Silva
Usuário 2: João Silva Junior
Usuário 3: João Silva (Designer)
```

Agora cada menção é clara e específica! ✅

## 🔧 Como Funciona

### 1. **Migração Automática**

Quando a migração `2025-10-30_add_unique_full_name_constraint.sql` é executada:

1. **Identifica nomes duplicados** existentes no banco
2. **Adiciona sufixo numérico** aos duplicados:
   - Primeiro usuário: `João Silva` (mantém o nome original)
   - Segundo usuário: `João Silva (1)`
   - Terceiro usuário: `João Silva (2)`
3. **Cria a constraint** de unicidade
4. **Cria índice** para buscas rápidas

### 2. **Validação na Interface**

Ao editar o perfil (`SettingsPage`):

```dart
// Verificar se o nome já existe
final existingUsers = await Supabase.instance.client
    .from('profiles')
    .select('id')
    .eq('full_name', newFullName)
    .neq('id', user.id);

if (existingUsers.isNotEmpty) {
  throw Exception('Este nome já está em uso por outro usuário.');
}
```

### 3. **Tratamento de Erros**

O `ErrorHandler` trata erros de duplicação:

```dart
if (message.contains('full_name') || message.contains('profiles_full_name_unique')) {
  return 'Este nome já está em uso por outro usuário. Por favor, escolha um nome diferente.';
}
```

## 📝 Boas Práticas

### ✅ Nomes Recomendados

- **Nome completo**: `João Silva Santos`
- **Nome + sobrenome**: `João Silva`
- **Nome + inicial**: `João S.`
- **Nome + cargo**: `João Silva (Designer)`
- **Nome + departamento**: `João Silva - TI`
- **Nome + localização**: `João Silva SP`

### ❌ Evitar

- Nomes muito genéricos: `João`, `Maria`, `Admin`
- Nomes duplicados: `João Silva` (se já existe)
- Nomes vazios ou apenas espaços

## 🚀 Fluxo de Cadastro/Edição

### Novo Usuário

1. Usuário preenche o nome no formulário
2. Sistema valida se o nome já existe
3. Se existir, mostra erro: **"Este nome já está em uso"**
4. Usuário escolhe um nome diferente
5. Cadastro é concluído com sucesso ✅

### Edição de Perfil

1. Usuário altera seu nome
2. Sistema verifica se o novo nome já está em uso por outro usuário
3. Se estiver, mostra erro: **"Este nome já está em uso"**
4. Usuário escolhe um nome diferente
5. Perfil é atualizado com sucesso ✅

## 🔍 Verificação de Nomes

### Consultar Todos os Nomes

```sql
SELECT full_name, COUNT(*) as count
FROM profiles
GROUP BY full_name
ORDER BY count DESC, full_name;
```

### Encontrar Duplicados (não deveria retornar nada)

```sql
SELECT full_name, COUNT(*) as count
FROM profiles
GROUP BY full_name
HAVING COUNT(*) > 1;
```

## 🛠️ Manutenção

### Adicionar Novo Usuário Manualmente

```sql
-- Verificar se o nome já existe
SELECT * FROM profiles WHERE full_name = 'João Silva';

-- Se não existir, inserir
INSERT INTO profiles (id, email, full_name)
VALUES (
  gen_random_uuid(),
  'joao.silva@example.com',
  'João Silva'
);
```

### Renomear Usuário

```sql
-- Verificar se o novo nome já existe
SELECT * FROM profiles WHERE full_name = 'João Silva Junior';

-- Se não existir, atualizar
UPDATE profiles
SET full_name = 'João Silva Junior'
WHERE id = 'user-id-aqui';
```

## 📊 Impacto no Sistema

### Sistema de Menções

**Antes (com duplicados):**
```
@João Silva → Qual dos 3 João Silva? 🤔
```

**Agora (nomes únicos):**
```
@João Silva → Exatamente este usuário! ✅
```

### Busca de Usuários

- ✅ Busca mais rápida (índice em `full_name`)
- ✅ Resultados únicos e precisos
- ✅ Autocomplete sem ambiguidade

### Performance

- ✅ Índice criado: `idx_profiles_full_name_lower`
- ✅ Busca case-insensitive otimizada
- ✅ Constraint validada no banco (mais rápido que validação na aplicação)

## 🎨 Mensagens de Erro

### Interface do Usuário

**Ao tentar usar nome duplicado:**
```
❌ Este nome já está em uso por outro usuário.
   Por favor, escolha um nome diferente.
```

**Sugestões automáticas:**
```
Nome desejado: João Silva
Sugestões:
  • João Silva Junior
  • João Silva (Designer)
  • João S. Silva
  • João Silva 2024
```

## 🔐 Segurança

### Proteção em Múltiplas Camadas

1. **Banco de Dados**: Constraint `UNIQUE` (camada mais forte)
2. **Aplicação**: Validação antes de salvar
3. **Interface**: Feedback imediato ao usuário

### Prevenção de Race Conditions

A constraint no banco previne que dois usuários criem o mesmo nome simultaneamente:

```
Usuário A: Tenta criar "João Silva" → ✅ Sucesso
Usuário B: Tenta criar "João Silva" → ❌ Erro (constraint violation)
```

## 📚 Referências

- **Migration**: `supabase/migrations/2025-10-30_add_unique_full_name_constraint.sql`
- **Validação**: `lib/src/features/settings/settings_page.dart` (linha 95-105)
- **Error Handler**: `lib/utils/error_handler.dart` (linha 171-173)
- **Sistema de Menções**: `docs/MENTIONS_SYSTEM.md`

## ❓ FAQ

### P: E se eu realmente precisar de dois usuários com o mesmo nome?

**R:** Adicione um diferenciador:
- `João Silva (Desenvolvedor)`
- `João Silva (Designer)`
- `João Silva - São Paulo`
- `João Silva Jr.`

### P: O que acontece com nomes duplicados existentes?

**R:** A migração adiciona automaticamente um sufixo numérico:
- Primeiro: `João Silva` (mantém original)
- Segundo: `João Silva (1)`
- Terceiro: `João Silva (2)`

### P: Posso usar caracteres especiais no nome?

**R:** Sim! Todos os caracteres Unicode são permitidos:
- ✅ `João Silva`
- ✅ `María García`
- ✅ `李明`
- ✅ `Müller`

### P: O nome é case-sensitive?

**R:** Sim, mas há um índice case-insensitive para buscas:
- `João Silva` ≠ `joão silva` (são diferentes)
- Mas a busca encontra ambos

### P: Qual o tamanho máximo do nome?

**R:** Não há limite definido, mas recomendamos:
- **Mínimo**: 2 caracteres
- **Recomendado**: 5-50 caracteres
- **Máximo prático**: 100 caracteres

## 🎯 Conclusão

A política de nomes únicos garante:

- ✅ **Clareza**: Cada menção é inequívoca
- ✅ **Integridade**: Dados consistentes no banco
- ✅ **Performance**: Buscas otimizadas
- ✅ **UX**: Feedback claro ao usuário
- ✅ **Segurança**: Validação em múltiplas camadas

Esta é uma decisão de design que melhora significativamente a experiência do usuário e a confiabilidade do sistema! 🚀

