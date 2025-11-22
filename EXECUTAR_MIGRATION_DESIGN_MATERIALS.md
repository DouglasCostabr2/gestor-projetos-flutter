# 🎨 Executar Migration - Design Materials

## 📋 Descrição

Esta migration cria a estrutura de banco de dados para o sistema de **Design Materials** (materiais de design) para clientes.

**Funcionalidades:**
- ✅ Pastas organizadas hierarquicamente (com subpastas)
- ✅ Upload de arquivos (logos, fotos, paletas de cores, etc.)
- ✅ Sistema de tags para organização
- ✅ Integração com Google Drive (sincronização bidirecional)
- ✅ Renomear pastas e arquivos
- ✅ Exclusão em cascata (pasta → subpastas → arquivos)

---

## 🚀 Como Aplicar a Migration

### Método 1: Supabase Dashboard (RECOMENDADO)

#### Passo 1: Acessar Supabase Dashboard
1. Acesse: https://app.supabase.com
2. Faça login
3. Selecione seu projeto

#### Passo 2: Abrir SQL Editor
1. No menu lateral, clique em **"SQL Editor"**
2. Clique em **"New Query"**

#### Passo 3: Executar a Migration
1. Abra o arquivo: `supabase/migrations/20251108_create_design_materials.sql`
2. Copie TODO o conteúdo (Ctrl+A, Ctrl+C)
3. Cole no SQL Editor do Supabase (Ctrl+V)
4. Clique em **"Run"** (ou pressione Ctrl+Enter)
5. Aguarde a mensagem de sucesso

---

## 📊 O Que a Migration Cria

### 1. Tabela `design_tags`
Tags para organizar pastas e arquivos.

**Colunas:**
- `id` - UUID (chave primária)
- `organization_id` - UUID (referência à organização)
- `name` - VARCHAR(100) (nome da tag)
- `color` - VARCHAR(7) (cor em hexadecimal, ex: #FF5733)
- `created_at` - TIMESTAMPTZ
- `created_by` - UUID (usuário que criou)

**Índices:**
- `idx_design_tags_organization` - Para filtrar por organização

**RLS Policies:**
- SELECT: Membros da organização podem ver
- INSERT/UPDATE/DELETE: Apenas admin/gestor/designer

---

### 2. Tabela `design_folders`
Pastas para organizar arquivos (suporta hierarquia).

**Colunas:**
- `id` - UUID (chave primária)
- `organization_id` - UUID (referência à organização)
- `client_id` - UUID (referência ao cliente)
- `parent_folder_id` - UUID (referência à pasta pai, NULL = raiz)
- `name` - VARCHAR(255) (nome da pasta)
- `description` - TEXT (descrição opcional)
- `drive_folder_id` - TEXT (ID da pasta no Google Drive)
- `created_at` / `updated_at` - TIMESTAMPTZ
- `created_by` / `updated_by` - UUID

**Índices:**
- `idx_design_folders_organization` - Para filtrar por organização
- `idx_design_folders_client` - Para filtrar por cliente
- `idx_design_folders_parent` - Para buscar subpastas

**RLS Policies:**
- SELECT: Membros da organização podem ver
- INSERT/UPDATE/DELETE: Apenas admin/gestor/designer

**Cascade Delete:**
- Ao deletar uma pasta, todas as subpastas e arquivos são deletados automaticamente

---

### 3. Tabela `design_files`
Arquivos de design (logos, fotos, etc.).

**Colunas:**
- `id` - UUID (chave primária)
- `organization_id` - UUID (referência à organização)
- `client_id` - UUID (referência ao cliente)
- `folder_id` - UUID (referência à pasta, NULL = raiz)
- `filename` - VARCHAR(255) (nome do arquivo)
- `file_size_bytes` - BIGINT (tamanho em bytes)
- `mime_type` - VARCHAR(100) (tipo MIME, ex: image/png)
- `description` - TEXT (descrição opcional)
- `drive_file_id` - TEXT (ID do arquivo no Google Drive)
- `drive_file_url` - TEXT (URL pública do arquivo)
- `drive_thumbnail_url` - TEXT (URL da thumbnail)
- `created_at` / `updated_at` - TIMESTAMPTZ
- `created_by` / `updated_by` - UUID

**Índices:**
- `idx_design_files_organization` - Para filtrar por organização
- `idx_design_files_client` - Para filtrar por cliente
- `idx_design_files_folder` - Para filtrar por pasta

**RLS Policies:**
- SELECT: Membros da organização podem ver
- INSERT/UPDATE/DELETE: Apenas admin/gestor/designer

---

### 4. Tabela `design_folder_tags`
Relacionamento muitos-para-muitos entre pastas e tags.

**Colunas:**
- `folder_id` - UUID (referência à pasta)
- `tag_id` - UUID (referência à tag)

**Chave Primária Composta:**
- `(folder_id, tag_id)` - Evita duplicatas

**Índices:**
- `idx_design_folder_tags_folder` - Para buscar tags de uma pasta
- `idx_design_folder_tags_tag` - Para buscar pastas com uma tag

---

### 5. Tabela `design_file_tags`
Relacionamento muitos-para-muitos entre arquivos e tags.

**Colunas:**
- `file_id` - UUID (referência ao arquivo)
- `tag_id` - UUID (referência à tag)

**Chave Primária Composta:**
- `(file_id, tag_id)` - Evita duplicatas

**Índices:**
- `idx_design_file_tags_file` - Para buscar tags de um arquivo
- `idx_design_file_tags_tag` - Para buscar arquivos com uma tag

---

## ✅ Verificação Pós-Migration

Execute no SQL Editor para verificar se as tabelas foram criadas:

```sql
-- Verificar tabelas criadas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'design_%'
ORDER BY table_name;

-- Deve retornar:
-- design_files
-- design_file_tags
-- design_folders
-- design_folder_tags
-- design_tags
```

---

## 🎯 Como Usar no App

Após aplicar a migration:

1. **Abra o app Flutter**
2. **Navegue até a página de um Cliente**
3. **Clique na aba "Design Materials"**
4. **Crie pastas e faça upload de arquivos**

**Funcionalidades disponíveis:**
- ✅ Criar pastas e subpastas
- ✅ Upload de múltiplos arquivos
- ✅ Renomear pastas e arquivos
- ✅ Adicionar tags para organização
- ✅ Filtrar por tags
- ✅ Excluir pastas e arquivos
- ✅ Sincronização automática com Google Drive

---

## 🔒 Segurança (RLS)

Todas as tabelas têm **Row Level Security (RLS)** habilitado:

- ✅ **SELECT**: Qualquer membro da organização pode visualizar
- ✅ **INSERT/UPDATE/DELETE**: Apenas usuários com role `admin`, `gestor` ou `designer`

Isso garante que:
- Clientes não podem modificar materiais de design
- Usuários de outras organizações não têm acesso aos dados
- Apenas roles autorizados podem gerenciar os materiais

---

## 📝 Notas Importantes

1. **Google Drive Integration**: Os arquivos são armazenados no Google Drive do usuário, não no Supabase Storage
2. **Estrutura de Pastas no Drive**: `Gestor de Projetos/Organizações/{OrgName}/Clientes/{ClientName}/Design Materials/...`
3. **Sincronização**: Ao deletar no app, o arquivo/pasta também é deletado do Google Drive
4. **Cascade Delete**: Deletar uma pasta remove todas as subpastas e arquivos automaticamente

---

## 🐛 Troubleshooting

### Erro: "relation already exists"
**Solução**: As tabelas já foram criadas. Você pode ignorar este erro ou executar:
```sql
DROP TABLE IF EXISTS design_file_tags CASCADE;
DROP TABLE IF EXISTS design_folder_tags CASCADE;
DROP TABLE IF EXISTS design_files CASCADE;
DROP TABLE IF EXISTS design_folders CASCADE;
DROP TABLE IF EXISTS design_tags CASCADE;
```
E então executar a migration novamente.

### Erro: "permission denied"
**Solução**: Certifique-se de estar usando uma conta com permissões de administrador no Supabase.

---

## 📚 Arquivos Relacionados

**Migration:**
- `supabase/migrations/20251108_create_design_materials.sql`

**Backend:**
- `lib/services/design_materials_repository.dart`
- `lib/services/google_drive_oauth_service.dart` (métodos adicionados)

**Frontend:**
- `lib/src/features/clients/widgets/design_materials/design_materials_tab.dart`
- `lib/src/features/clients/widgets/design_materials/folder_tree_view.dart`
- `lib/src/features/clients/widgets/design_materials/file_grid_view.dart`
- `lib/src/features/clients/widgets/design_materials/tag_chip.dart`
- `lib/src/features/clients/widgets/design_materials/design_materials_dialogs.dart`
- `lib/src/features/clients/client_detail_page.dart` (aba adicionada)

