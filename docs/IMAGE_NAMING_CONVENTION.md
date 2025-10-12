# 📸 Convenção de Nomenclatura de Imagens

## 🎯 Objetivo

Padronizar os nomes dos arquivos de imagem enviados para o Supabase Storage, facilitando a identificação e organização.

---

## 📋 Convenção Implementada

### 1. **Avatar de Usuário** (Perfil)
**Localização**: `lib/src/features/settings/settings_page.dart`

**Formato**: `avatar-nomedousuario.jpg`

**Exemplos**:
- Nome: "João Silva" → Arquivo: `avatar-joao-silva.jpg`
- Nome: "Maria Oliveira" → Arquivo: `avatar-maria-oliveira.jpg`
- Nome: "José Carlos Jr." → Arquivo: `avatar-jose-carlos-jr.jpg`

**Bucket**: `avatars`

**Caminho completo**: `avatars/avatar-nomedousuario.jpg`

---

### 2. **Avatar de Cliente**
**Localização**: `lib/src/features/clients/widgets/client_form.dart`

**Formato**: `{userId}/avatar-nomedocliente.jpg`

**Exemplos**:
- Cliente: "Empresa ABC" → Arquivo: `{userId}/avatar-empresa-abc.jpg`
- Cliente: "João & Maria Ltda" → Arquivo: `{userId}/avatar-joao-maria-ltda.jpg`
- Cliente: "Tech Solutions 2024" → Arquivo: `{userId}/avatar-tech-solutions-2024.jpg`

**Bucket**: `client-avatars`

**Caminho completo**: `client-avatars/{userId}/avatar-nomedocliente.jpg`

---

### 3. **Miniatura de Produto**
**Localização**: `lib/src/features/catalog/catalog_page.dart`

**Formato**: `thumb-nomedoproduto.jpg`

**Exemplos**:
- Produto: "Logo Design" → Arquivo: `thumb-logo-design.jpg`
- Produto: "Website Completo" → Arquivo: `thumb-website-completo.jpg`
- Produto: "Social Media Pack" → Arquivo: `thumb-social-media-pack.jpg`

**Bucket**: `product-thumbnails`

**Caminho completo**: `product-thumbnails/thumb-nomedoproduto.jpg`

---

### 4. **Miniatura de Pacote**
**Localização**: `lib/src/features/catalog/catalog_page.dart`

**Formato**: `thumb-nomedopacote.jpg`

**Exemplos**:
- Pacote: "Pacote Básico" → Arquivo: `thumb-pacote-basico.jpg`
- Pacote: "Pacote Premium 2024" → Arquivo: `thumb-pacote-premium-2024.jpg`
- Pacote: "Combo Marketing" → Arquivo: `thumb-combo-marketing.jpg`

**Bucket**: `product-thumbnails`

**Caminho completo**: `product-thumbnails/thumb-nomedopacote.jpg`

---

## 🔧 Regras de Sanitização

Para garantir compatibilidade com sistemas de arquivos e URLs, os nomes são sanitizados:

1. **Converter para minúsculas**: `João Silva` → `joão silva`
2. **Remover acentos e caracteres especiais**: `joão silva` → `joao silva`
3. **Substituir espaços e caracteres não alfanuméricos por hífen**: `joao silva` → `joao-silva`
4. **Remover hífens duplicados**: `joao--silva` → `joao-silva`
5. **Remover hífens no início e fim**: `-joao-silva-` → `joao-silva`

### Código de Sanitização:

```dart
final sanitizedName = name.trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]'), '-')  // Substitui não-alfanuméricos por hífen
    .replaceAll(RegExp(r'-+'), '-')          // Remove hífens duplicados
    .replaceAll(RegExp(r'^-|-$'), '');       // Remove hífens nas pontas
```

---

## 📊 Exemplos Completos

### Avatar de Usuário:

| Nome do Usuário | Nome do Arquivo | URL Completa |
|----------------|-----------------|--------------|
| Douglas Costa | `avatar-douglas-costa.jpg` | `https://.../avatars/avatar-douglas-costa.jpg` |
| Ana Paula | `avatar-ana-paula.jpg` | `https://.../avatars/avatar-ana-paula.jpg` |
| José Carlos Jr. | `avatar-jose-carlos-jr.jpg` | `https://.../avatars/avatar-jose-carlos-jr.jpg` |

### Avatar de Cliente:

| Nome do Cliente | Nome do Arquivo | URL Completa |
|----------------|-----------------|--------------|
| Empresa XYZ | `{userId}/avatar-empresa-xyz.jpg` | `https://.../client-avatars/{userId}/avatar-empresa-xyz.jpg` |
| João & Maria | `{userId}/avatar-joao-maria.jpg` | `https://.../client-avatars/{userId}/avatar-joao-maria.jpg` |
| Tech 2024 | `{userId}/avatar-tech-2024.jpg` | `https://.../client-avatars/{userId}/avatar-tech-2024.jpg` |

### Miniatura de Produto:

| Nome do Produto | Nome do Arquivo | URL Completa |
|----------------|-----------------|--------------|
| Logo Design | `thumb-logo-design.jpg` | `https://.../product-thumbnails/thumb-logo-design.jpg` |
| Website Completo | `thumb-website-completo.jpg` | `https://.../product-thumbnails/thumb-website-completo.jpg` |
| Social Media Pack | `thumb-social-media-pack.jpg` | `https://.../product-thumbnails/thumb-social-media-pack.jpg` |

### Miniatura de Pacote:

| Nome do Pacote | Nome do Arquivo | URL Completa |
|----------------|-----------------|--------------|
| Pacote Básico | `thumb-pacote-basico.jpg` | `https://.../product-thumbnails/thumb-pacote-basico.jpg` |
| Pacote Premium 2024 | `thumb-pacote-premium-2024.jpg` | `https://.../product-thumbnails/thumb-pacote-premium-2024.jpg` |
| Combo Marketing | `thumb-combo-marketing.jpg` | `https://.../product-thumbnails/thumb-combo-marketing.jpg` |

---

## ✅ Benefícios

1. **Identificação Fácil**: Ao olhar o nome do arquivo, você sabe exatamente o que é
2. **Organização**: Arquivos organizados por nome, não por timestamp ou UUID
3. **Compatibilidade**: Nomes sanitizados funcionam em qualquer sistema
4. **Substituição Automática**: Como o nome é baseado no nome do item, ao fazer upload de uma nova imagem, a antiga é substituída automaticamente (usando `upsert: true`)
5. **Busca Facilitada**: Fácil encontrar imagens específicas no Supabase Storage

---

## 🔄 Comportamento de Atualização

### Avatar de Usuário:
- Ao fazer upload de um novo avatar, o arquivo antigo é **deletado** primeiro
- Depois o novo arquivo é enviado com o nome `avatar-nomedousuario.jpg`
- Se o usuário mudar de nome, um novo arquivo será criado e o antigo será deletado

### Avatar de Cliente:
- Ao fazer upload de um novo avatar, o arquivo antigo é **deletado** primeiro
- Depois o novo arquivo é enviado com o nome `avatar-nomedocliente.jpg`
- Se o cliente mudar de nome, um novo arquivo será criado e o antigo será deletado

### Miniatura de Produto/Pacote:
- Ao fazer upload de uma nova miniatura, a antiga é **deletada** primeiro
- Depois a nova miniatura é enviada com o nome `thumb-nomedoproduto.jpg`
- Se o produto/pacote mudar de nome, um novo arquivo será criado e o antigo será deletado

---

## 🐛 Casos Especiais

### Nome Vazio:
Se o nome estiver vazio, usa um fallback:
- **Usuário**: `avatar-usuario.jpg`
- **Cliente**: `avatar-cliente.jpg`
- **Produto/Pacote**: `thumb-produto.jpg`

### Caracteres Especiais:
Todos os caracteres especiais são convertidos para hífen:
- `João & Maria` → `joao-maria`
- `Tech@Solutions` → `tech-solutions`
- `Empresa (2024)` → `empresa-2024`
- `Logo Design #1` → `logo-design-1`

### Nomes Muito Longos:
O sistema não limita o tamanho do nome, mas o Supabase Storage tem limite de 255 caracteres para nomes de arquivo.

---

## 📝 Notas Técnicas

### Avatares (Usuário e Cliente):
- **Formato**: Sempre JPEG (`.jpg`)
- **Compressão**: Qualidade 85%
- **Tamanho**: 400x400 pixels
- **Upsert**: Habilitado para substituir automaticamente
- **Permissões**: Apenas usuários autenticados podem fazer upload

### Miniaturas (Produtos e Pacotes):
- **Formato**: Sempre JPEG (`.jpg`)
- **Compressão**: Qualidade 85%
- **Tamanho**: Máximo 400x400 pixels (mantém proporção)
- **Upsert**: Desabilitado (deleta antiga antes de enviar nova)
- **Permissões**: Apenas usuários autenticados podem fazer upload

---

## 🔍 Verificação

Para verificar se a convenção está funcionando:

### Avatar de Usuário:
1. Faça upload de um avatar de usuário
2. Vá para o Supabase Storage → bucket `avatars`
3. Verifique se o arquivo tem o nome `avatar-nomedousuario.jpg`

### Avatar de Cliente:
1. Faça upload de um avatar de cliente
2. Vá para o Supabase Storage → bucket `client-avatars`
3. Verifique se o arquivo tem o nome `{userId}/avatar-nomedocliente.jpg`

### Miniatura de Produto/Pacote:
1. Faça upload de uma miniatura de produto ou pacote
2. Vá para o Supabase Storage → bucket `product-thumbnails`
3. Verifique se o arquivo tem o nome `thumb-nomedoproduto.jpg` ou `thumb-nomedopacote.jpg`

---

## 🎉 Conclusão

Agora todas as imagens (avatares e miniaturas) seguem uma convenção clara e consistente, facilitando a organização e manutenção do storage!

