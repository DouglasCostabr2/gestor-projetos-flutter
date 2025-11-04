# Guia de Testes - Sistema Multi-Tenancy

## 📋 Objetivo

Este guia fornece um roteiro completo para testar o sistema multi-tenancy e garantir que o isolamento de dados está funcionando corretamente.

---

## 🧪 Teste 1: Isolamento Completo de Dados

### Objetivo
Verificar que dados de uma organização são completamente invisíveis para outra.

### Passos

#### 1.1. Criar Primeira Organização

1. Fazer login no sistema
2. Ir para **Configurações → Organização**
3. Clicar em **"Criar Nova Organização"**
4. Preencher:
   - Nome: `Empresa A`
   - Slug: `empresa-a`
5. Salvar

#### 1.2. Adicionar Dados na Empresa A

1. **Criar Cliente:**
   - Ir para **Clientes**
   - Clicar em **"Novo Cliente"**
   - Nome: `Cliente A1`
   - Email: `clientea1@example.com`
   - Salvar

2. **Criar Projeto:**
   - Ir para **Projetos**
   - Clicar em **"Novo Projeto"**
   - Nome: `Projeto A1`
   - Cliente: `Cliente A1`
   - Salvar

3. **Criar Tarefa:**
   - Abrir `Projeto A1`
   - Clicar em **"Nova Tarefa"**
   - Título: `Tarefa A1`
   - Salvar

4. **Criar Produto:**
   - Ir para **Catálogo → Produtos**
   - Clicar em **"Novo Produto"**
   - Nome: `Produto A1`
   - Preço: `100.00`
   - Salvar

5. **Upload de Avatar:**
   - Ir para **Configurações → Perfil**
   - Fazer upload de uma imagem como avatar
   - Verificar que foi salvo

#### 1.3. Criar Segunda Organização

1. Clicar no **seletor de organizações** (canto superior esquerdo)
2. Clicar em **"+ Nova Organização"**
3. Preencher:
   - Nome: `Empresa B`
   - Slug: `empresa-b`
4. Salvar

#### 1.4. Verificar Isolamento

**✅ Verificações Esperadas:**

1. **Clientes:**
   - Ir para **Clientes**
   - ✅ Lista deve estar **vazia**
   - ❌ `Cliente A1` **NÃO** deve aparecer

2. **Projetos:**
   - Ir para **Projetos**
   - ✅ Lista deve estar **vazia**
   - ❌ `Projeto A1` **NÃO** deve aparecer

3. **Tarefas:**
   - Ir para **Tarefas**
   - ✅ Lista deve estar **vazia**
   - ❌ `Tarefa A1` **NÃO** deve aparecer

4. **Produtos:**
   - Ir para **Catálogo → Produtos**
   - ✅ Lista deve estar **vazia**
   - ❌ `Produto A1` **NÃO** deve aparecer

5. **Notificações:**
   - Clicar no ícone de notificações
   - ✅ Lista deve estar **vazia**
   - ❌ Notificações da Empresa A **NÃO** devem aparecer

#### 1.5. Adicionar Dados na Empresa B

1. Criar `Cliente B1`
2. Criar `Projeto B1`
3. Criar `Tarefa B1`
4. Criar `Produto B1`

#### 1.6. Alternar Entre Organizações

1. **Trocar para Empresa A:**
   - Clicar no seletor de organizações
   - Selecionar `Empresa A`
   - ✅ Deve mostrar: `Cliente A1`, `Projeto A1`, `Tarefa A1`, `Produto A1`
   - ❌ **NÃO** deve mostrar dados da Empresa B

2. **Trocar para Empresa B:**
   - Clicar no seletor de organizações
   - Selecionar `Empresa B`
   - ✅ Deve mostrar: `Cliente B1`, `Projeto B1`, `Tarefa B1`, `Produto B1`
   - ❌ **NÃO** deve mostrar dados da Empresa A

**✅ TESTE PASSOU:** Dados estão completamente isolados entre organizações

---

## 🔐 Teste 2: Permissões Contextuais

### Objetivo
Verificar que permissões funcionam corretamente baseadas no role do usuário em cada organização.

### Passos

#### 2.1. Criar Usuário de Teste

1. Criar novo usuário no Supabase Auth:
   - Email: `teste@example.com`
   - Senha: `Teste@123`

#### 2.2. Convidar com Role "Usuario"

1. Na **Empresa A**, ir para **Configurações → Organização → Membros**
2. Clicar em **"Convidar Membro"**
3. Preencher:
   - Email: `teste@example.com`
   - Role: `Usuario`
4. Enviar convite

#### 2.3. Aceitar Convite

1. Fazer logout
2. Fazer login com `teste@example.com`
3. Ir para **Configurações → Organização → Convites**
4. Aceitar convite da `Empresa A`

#### 2.4. Verificar Permissões de "Usuario"

**✅ Deve PODER:**
- Ver clientes
- Ver projetos
- Ver tarefas
- Ver produtos

**❌ NÃO deve PODER:**
- Criar clientes (botão deve estar oculto ou desabilitado)
- Editar clientes
- Deletar clientes
- Criar projetos
- Editar projetos
- Deletar projetos

#### 2.5. Alterar Role para "Designer"

1. Fazer logout
2. Fazer login com usuário admin original
3. Ir para **Configurações → Organização → Membros**
4. Encontrar `teste@example.com`
5. Alterar role para `Designer`
6. Salvar

#### 2.6. Verificar Permissões de "Designer"

1. Fazer logout
2. Fazer login com `teste@example.com`

**✅ Deve PODER:**
- Ver clientes
- **Criar clientes** ✨
- **Editar clientes** ✨
- Ver projetos
- **Criar projetos** ✨
- **Editar projetos** ✨

**❌ NÃO deve PODER:**
- Deletar clientes
- Deletar projetos

#### 2.7. Alterar Role para "Gestor"

1. Repetir processo alterando role para `Gestor`

**✅ Deve PODER:**
- Tudo que Designer pode
- **Deletar clientes** ✨
- **Deletar projetos** ✨
- **Deletar tarefas de outros usuários** ✨

**✅ TESTE PASSOU:** Permissões funcionam corretamente por role

---

## 🔄 Teste 3: Troca de Organização

### Objetivo
Verificar que ao trocar de organização todos os dados são atualizados corretamente.

### Passos

#### 3.1. Preparar Dados

1. Criar dados na **Empresa A**
2. Criar dados na **Empresa B**
3. Garantir que está na **Empresa A**

#### 3.2. Verificar Estado Inicial

1. Anotar:
   - Número de clientes na Empresa A
   - Número de projetos na Empresa A
   - Número de notificações na Empresa A

#### 3.3. Trocar para Empresa B

1. Clicar no seletor de organizações
2. Selecionar `Empresa B`
3. Aguardar atualização

#### 3.4. Verificar Atualização

**✅ Verificações:**

1. **Seletor de Organizações:**
   - ✅ Deve mostrar `Empresa B` como ativa

2. **Listas Atualizadas:**
   - ✅ Lista de clientes deve mostrar apenas clientes da Empresa B
   - ✅ Lista de projetos deve mostrar apenas projetos da Empresa B
   - ✅ Lista de tarefas deve mostrar apenas tarefas da Empresa B

3. **Notificações:**
   - ✅ Deve mostrar apenas notificações da Empresa B

4. **Permissões:**
   - ✅ Permissões devem refletir o role na Empresa B
   - (Se role for diferente entre organizações)

#### 3.5. Trocar de Volta

1. Trocar para `Empresa A`
2. Verificar que dados da Empresa A voltaram

**✅ TESTE PASSOU:** Troca de organização funciona corretamente

---

## 👥 Teste 4: Convites e Membros

### Objetivo
Testar fluxo completo de convites, aceitação e gerenciamento de membros.

### Passos

#### 4.1. Enviar Convite

1. Ir para **Configurações → Organização → Convites**
2. Clicar em **"Convidar Membro"**
3. Preencher:
   - Email: `novomembro@example.com`
   - Role: `Designer`
4. Enviar

**✅ Verificações:**
- ✅ Convite deve aparecer na lista com status `Pendente`
- ✅ Deve mostrar email, role e data de expiração

#### 4.2. Verificar Notificação

1. Fazer login com `novomembro@example.com`
2. Verificar notificações

**✅ Verificações:**
- ✅ Deve ter notificação de convite recebido
- ✅ Notificação deve ter link para aceitar

#### 4.3. Aceitar Convite

1. Ir para **Configurações → Organização → Convites**
2. Encontrar convite pendente
3. Clicar em **"Aceitar"**

**✅ Verificações:**
- ✅ Status do convite deve mudar para `Aceito`
- ✅ Usuário deve aparecer na lista de membros
- ✅ Organização deve aparecer no seletor de organizações

#### 4.4. Rejeitar Convite

1. Enviar novo convite para `outro@example.com`
2. Fazer login com `outro@example.com`
3. Ir para convites
4. Clicar em **"Rejeitar"**

**✅ Verificações:**
- ✅ Status deve mudar para `Rejeitado`
- ✅ Usuário **NÃO** deve aparecer na lista de membros

#### 4.5. Remover Membro

1. Fazer login como admin
2. Ir para **Configurações → Organização → Membros**
3. Encontrar membro
4. Clicar em **"Remover"**
5. Confirmar

**✅ Verificações:**
- ✅ Membro deve ser removido da lista
- ✅ Membro não deve mais ter acesso à organização

**✅ TESTE PASSOU:** Sistema de convites funciona corretamente

---

## 📦 Teste 5: Isolamento de Storage

### Objetivo
Verificar que arquivos de diferentes organizações estão isolados.

### Passos

#### 5.1. Upload na Empresa A

1. Garantir que está na **Empresa A**
2. Ir para **Configurações → Perfil**
3. Fazer upload de avatar (imagem 1)
4. Anotar a URL do avatar

#### 5.2. Upload na Empresa B

1. Trocar para **Empresa B**
2. Ir para **Configurações → Perfil**
3. Fazer upload de avatar (imagem 2 - diferente)
4. Anotar a URL do avatar

#### 5.3. Verificar Isolamento

1. **Trocar para Empresa A:**
   - ✅ Deve mostrar imagem 1
   - ❌ **NÃO** deve mostrar imagem 2

2. **Trocar para Empresa B:**
   - ✅ Deve mostrar imagem 2
   - ❌ **NÃO** deve mostrar imagem 1

#### 5.4. Verificar URLs

1. Comparar as URLs anotadas
2. ✅ Devem conter `organization_id` diferente no path:
   - Empresa A: `avatars/{org_a_id}/avatar-username.jpg`
   - Empresa B: `avatars/{org_b_id}/avatar-username.jpg`

#### 5.5. Testar Outros Uploads

Repetir para:
- Avatar de cliente
- Thumbnail de produto

**✅ TESTE PASSOU:** Storage está isolado por organização

---

## ⚡ Teste 6: Performance

### Objetivo
Verificar que o sistema mantém boa performance com múltiplas organizações.

### Passos

#### 6.1. Criar Dados em Massa

1. Criar 3 organizações
2. Em cada organização, criar:
   - 50 clientes
   - 20 projetos
   - 100 tarefas
   - 30 produtos

#### 6.2. Medir Tempo de Carregamento

1. Trocar entre organizações
2. Medir tempo de carregamento de cada página
3. ✅ Deve carregar em menos de 2 segundos

#### 6.3. Verificar Queries

1. Abrir DevTools do navegador
2. Ir para aba Network
3. Filtrar por chamadas Supabase
4. ✅ Verificar que queries incluem filtro por `organization_id`

**✅ TESTE PASSOU:** Performance está adequada

---

## 📊 Checklist Final

- [ ] Teste 1: Isolamento Completo de Dados
- [ ] Teste 2: Permissões Contextuais
- [ ] Teste 3: Troca de Organização
- [ ] Teste 4: Convites e Membros
- [ ] Teste 5: Isolamento de Storage
- [ ] Teste 6: Performance

---

## 🐛 Reportar Problemas

Se encontrar algum problema durante os testes:

1. Anotar o passo exato onde ocorreu
2. Capturar screenshot se possível
3. Verificar console do navegador para erros
4. Verificar logs do Supabase
5. Reportar com detalhes completos

---

**Última atualização:** 31/10/2025
**Versão:** 1.0.0

