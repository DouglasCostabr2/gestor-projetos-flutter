# Sistema Multi-Tenancy - Documentação Completa

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Estrutura do Banco de Dados](#estrutura-do-banco-de-dados)
4. [Políticas RLS](#políticas-rls)
5. [Sistema de Permissões](#sistema-de-permissões)
6. [Storage Multi-Tenancy](#storage-multi-tenancy)
7. [Notificações](#notificações)
8. [Guia de Uso](#guia-de-uso)
9. [Testes](#testes)

---

## 🎯 Visão Geral

O sistema multi-tenancy permite que múltiplas organizações compartilhem a mesma aplicação, mantendo **isolamento completo de dados** entre elas. Cada usuário pode pertencer a múltiplas organizações com diferentes níveis de permissão em cada uma.

### Características Principais

- ✅ **Isolamento Total**: Dados de uma organização são completamente invisíveis para outras
- ✅ **Permissões Contextuais**: Permissões baseadas no role do usuário em cada organização
- ✅ **Storage Isolado**: Arquivos organizados por organização com políticas RLS
- ✅ **Notificações Isoladas**: Sistema de notificações filtrado por organização
- ✅ **Hierarquia de Roles**: 6 níveis de permissão (owner → admin → gestor → financeiro → designer → usuario)
- ✅ **Sistema de Convites**: Fluxo completo de convites para adicionar membros

---

## 🏗️ Arquitetura

### Componentes Principais

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                             │
├─────────────────────────────────────────────────────────────┤
│  AppState                                                    │
│  ├─ currentOrganizationId                                   │
│  ├─ currentOrganizationRole                                 │
│  └─ permissions (PermissionsHelper)                         │
├─────────────────────────────────────────────────────────────┤
│  OrganizationContext (Static Helper)                        │
│  └─ Acesso global ao organization_id                        │
├─────────────────────────────────────────────────────────────┤
│  Repositories                                                │
│  └─ Filtram automaticamente por organization_id             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE BACKEND                          │
├─────────────────────────────────────────────────────────────┤
│  Row Level Security (RLS)                                   │
│  ├─ Políticas em 15 tabelas                                │
│  ├─ Políticas em 3 buckets de storage                      │
│  └─ Funções helper para verificação de permissões          │
├─────────────────────────────────────────────────────────────┤
│  Database Tables                                             │
│  ├─ organizations                                           │
│  ├─ organization_members                                    │
│  ├─ organization_invites                                    │
│  └─ 12 tabelas com organization_id FK                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Estrutura do Banco de Dados

### Tabelas Principais

#### 1. `organizations`
Armazena informações das organizações.

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

#### 2. `organization_members`
Relaciona usuários com organizações e seus roles.

```sql
CREATE TABLE organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'gestor', 'financeiro', 'designer', 'usuario')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(organization_id, user_id)
);
```

#### 3. `organization_invites`
Gerencia convites para novos membros.

```sql
CREATE TABLE organization_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  invited_by UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '7 days')
);
```

### Tabelas com `organization_id`

Todas as tabelas abaixo possuem a coluna `organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE`:

1. `clients` - Clientes
2. `projects` - Projetos
3. `tasks` - Tarefas
4. `products` - Produtos
5. `packages` - Pacotes
6. `package_items` - Itens de pacotes
7. `categories` - Categorias
8. `companies` - Empresas
9. `payments` - Pagamentos
10. `invoices` - Faturas
11. `organization_settings` - Configurações
12. `notifications` - Notificações

---

## 🔒 Políticas RLS

### Funções Helper

#### `is_organization_member(org_id UUID)`
Verifica se o usuário autenticado é membro ativo da organização.

```sql
CREATE OR REPLACE FUNCTION is_organization_member(org_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_id = org_id
      AND user_id = auth.uid()
      AND status = 'active'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### `has_organization_role(org_id UUID, required_role TEXT)`
Verifica se o usuário tem um role específico ou superior.

```sql
CREATE OR REPLACE FUNCTION has_organization_role(org_id UUID, required_role TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
  role_hierarchy JSONB := '{"owner": 6, "admin": 5, "gestor": 4, "financeiro": 3, "designer": 2, "usuario": 1}';
BEGIN
  SELECT role INTO user_role
  FROM organization_members
  WHERE organization_id = org_id
    AND user_id = auth.uid()
    AND status = 'active';

  IF user_role IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN (role_hierarchy->>user_role)::INT >= (role_hierarchy->>required_role)::INT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Exemplo de Políticas

#### Tabela `clients`

```sql
-- SELECT: Membros podem ver clientes de suas organizações
CREATE POLICY "Members can view clients in their organizations"
  ON clients FOR SELECT
  TO authenticated
  USING (is_organization_member(organization_id));

-- INSERT: Designers ou superior podem criar clientes
CREATE POLICY "Designers+ can create clients"
  ON clients FOR INSERT
  TO authenticated
  WITH CHECK (has_organization_role(organization_id, 'designer'));

-- UPDATE: Designers ou superior podem editar clientes
CREATE POLICY "Designers+ can update clients"
  ON clients FOR UPDATE
  TO authenticated
  USING (has_organization_role(organization_id, 'designer'));

-- DELETE: Gestores ou superior podem deletar clientes
CREATE POLICY "Gestores+ can delete clients"
  ON clients FOR DELETE
  TO authenticated
  USING (has_organization_role(organization_id, 'gestor'));
```

---

## 🔐 Sistema de Permissões

### Hierarquia de Roles

```
owner (6)      → Controle total da organização
  ↓
admin (5)      → Gerenciamento completo exceto deleção da org
  ↓
gestor (4)     → Gerenciamento de projetos e equipe
  ↓
financeiro (3) → Acesso a dados financeiros
  ↓
designer (2)   → Criação e edição de conteúdo
  ↓
usuario (1)    → Acesso básico de leitura
```

### PermissionsHelper

Classe helper que centraliza toda a lógica de permissões:

```dart
final permissions = appState.permissions;

// Verificar permissões
if (permissions.canCreateClients) {
  // Criar cliente
}

if (permissions.canEditTask(task)) {
  // Editar tarefa (verifica se é owner da task ou admin/gestor)
}

// Obter mensagem de erro
final message = permissions.getPermissionDeniedMessage('criar clientes');
```

### Permissões Disponíveis

**Organizações:**
- `canViewOrganizations` - Todos os membros
- `canEditOrganizations` - Admin ou superior
- `canDeleteOrganizations` - Owner apenas

**Clientes:**
- `canViewClients` - Todos os membros
- `canCreateClients` - Designer ou superior
- `canEditClients` - Designer ou superior
- `canDeleteClients` - Gestor ou superior

**Projetos:**
- `canViewProjects` - Todos os membros
- `canCreateProjects` - Designer ou superior
- `canEditProjects` - Designer ou superior
- `canDeleteProjects` - Gestor ou superior

**Tarefas:**
- `canViewTasks` - Todos os membros
- `canCreateTasks` - Designer ou superior
- `canEditTask(task)` - Owner da task OU Admin/Gestor
- `canDeleteTask(task)` - Owner da task OU Admin/Gestor
- `canAssignTasks` - Designer ou superior

**Produtos/Pacotes:**
- `canViewProducts` - Todos os membros
- `canCreateProducts` - Designer ou superior
- `canEditProducts` - Designer ou superior
- `canDeleteProducts` - Gestor ou superior

**Categorias:**
- `canViewCategories` - Todos os membros
- `canCreateCategories` - Designer ou superior
- `canEditCategories` - Designer ou superior
- `canDeleteCategories` - Gestor ou superior

**Financeiro:**
- `canViewPayments` - Financeiro ou superior
- `canCreatePayments` - Financeiro ou superior
- `canEditPayments` - Financeiro ou superior
- `canDeletePayments` - Gestor ou superior
- `canApprovePayments` - Gestor ou superior

---

## 📦 Storage Multi-Tenancy

### Estrutura de Pastas

Arquivos são organizados por organização usando estrutura de pastas:

```
avatars/
  ├─ {organization_id}/
  │   ├─ avatar-username1.jpg
  │   └─ avatar-username2.jpg
  └─ avatar-legacy.jpg (arquivos antigos sem org_id)

client-avatars/
  └─ {organization_id}/
      ├─ avatar-client1.jpg
      └─ avatar-client2.jpg

product-thumbnails/
  └─ {organization_id}/
      ├─ thumb-product1.jpg
      └─ thumb-product2.jpg
```

### Políticas RLS de Storage

```sql
CREATE POLICY "Users can view avatars in their organizations"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] IN (
        SELECT organization_id::text
        FROM public.organization_members
        WHERE user_id = auth.uid() AND status = 'active'
      )
      OR array_length(storage.foldername(name), 1) IS NULL
    )
  );
```

### Upload de Arquivos

```dart
// Obter organization_id
final organizationId = OrganizationContext.currentOrganizationId;
if (organizationId == null) {
  throw Exception('Nenhuma organização ativa');
}

// Path com organization_id
final path = '$organizationId/$fileName';

// Upload
await Supabase.instance.client.storage
    .from('avatars')
    .uploadBinary(path, fileBytes);
```

---

## 🔔 Notificações

### Tipos de Notificação

**Organizações:**
- `organizationInviteReceived` - Convite recebido
- `organizationRoleChanged` - Role alterado
- `organizationMemberAdded` - Novo membro adicionado

**Tarefas:**
- `taskAssigned` - Tarefa atribuída
- `taskStatusChanged` - Status alterado
- `taskCommentAdded` - Comentário adicionado

### Filtro por Organização

Todas as notificações são filtradas automaticamente por `organization_id`:

```dart
final notifications = await notificationsRepository.getNotifications(
  userId: userId,
  limit: 50,
);
// Retorna apenas notificações da organização ativa
```

---

## 📖 Guia de Uso

### 1. Criar Nova Organização

```dart
final org = await organizationsRepository.create({
  'name': 'Minha Empresa',
  'slug': 'minha-empresa',
});
```

### 2. Convidar Membro

```dart
await organizationsRepository.inviteMember(
  organizationId: orgId,
  email: 'usuario@example.com',
  role: 'designer',
);
```

### 3. Trocar de Organização

```dart
appState.setCurrentOrganization(organizationId, role);
```

### 4. Verificar Permissões

```dart
if (appState.permissions.canCreateClients) {
  // Criar cliente
}
```

---

## 🧪 Testes

### Checklist de Testes

- [ ] Criar 2 organizações diferentes
- [ ] Adicionar dados em cada organização
- [ ] Verificar isolamento total de dados
- [ ] Testar troca entre organizações
- [ ] Verificar permissões por role
- [ ] Testar convites e aceitação
- [ ] Testar upload de arquivos
- [ ] Verificar isolamento de storage
- [ ] Testar notificações por organização

---

## 📊 Estatísticas

- **15 tabelas** com políticas RLS
- **59 políticas RLS** criadas
- **3 buckets** de storage configurados
- **10 políticas** de storage
- **6 níveis** de permissão
- **60+ getters** de permissões
- **3 funções helper** SQL

---

**Última atualização:** 31/10/2025
**Versão:** 1.0.0

