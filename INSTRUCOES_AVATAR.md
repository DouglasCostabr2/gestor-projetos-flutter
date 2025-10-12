# 📸 Instruções para Configurar Upload de Avatar

## 🎯 O que foi implementado:

1. **Upload de foto de perfil** com compressão automática
2. **Redimensionamento** para 400x400 pixels
3. **Compressão JPEG** com qualidade 85% (reduz peso significativamente)
4. **Armazenamento no Supabase Storage**
5. **Botão para remover foto** de perfil

## 🔧 Configuração Necessária no Supabase:

### Opção 1: Via Interface do Supabase (Recomendado)

1. Acesse o dashboard do Supabase: https://app.supabase.com
2. Selecione seu projeto
3. No menu lateral, clique em **Storage**
4. Clique em **New bucket**
5. Configure o bucket:
   - **Name**: `avatars`
   - **Public bucket**: ✅ Marque esta opção (para URLs públicas)
   - **File size limit**: `5 MB`
   - **Allowed MIME types**: `image/jpeg, image/jpg, image/png, image/webp`
6. Clique em **Create bucket**

### Opção 2: Via SQL Editor (Recomendado se a Opção 1 não funcionar)

1. Acesse o dashboard do Supabase: https://app.supabase.com
2. Selecione seu projeto
3. No menu lateral, clique em **SQL Editor**
4. Clique em **New query**
5. Copie e cole o conteúdo do arquivo `supabase_avatars_bucket_simples.sql`
6. Clique em **Run** (ou pressione Ctrl+Enter) para executar o script
7. Verifique se aparece "Success" e se a última query retorna 1 linha com o bucket 'avatars'

**IMPORTANTE**: Se der erro, execute os blocos separadamente (PASSO 1, depois PASSO 2, etc.)

## ✅ Verificação:

Após criar o bucket, verifique se ele aparece na lista de buckets em **Storage**.

## 🎨 Como Usar:

1. Acesse a página de **Configurações** no menu lateral
2. No card de informações da conta, você verá seu avatar atual
3. Clique no **botão de câmera** (ícone azul no canto inferior direito do avatar)
4. Selecione uma imagem do seu computador
5. A imagem será automaticamente:
   - Redimensionada para 400x400 pixels
   - Comprimida para reduzir o tamanho
   - Enviada para o Supabase Storage
   - Atualizada no seu perfil
6. Para remover a foto, clique no botão **Remover** abaixo do avatar

## 📊 Detalhes Técnicos:

- **Formato de saída**: JPEG
- **Tamanho**: 400x400 pixels (mantém proporção)
- **Qualidade**: 85%
- **Peso aproximado**: 50-150 KB (dependendo da imagem original)
- **Limite de upload**: 5 MB
- **Formatos aceitos**: JPEG, JPG, PNG, WebP

## 🔒 Segurança:

- Apenas usuários autenticados podem fazer upload
- Cada usuário só pode modificar seu próprio avatar
- As imagens são públicas (necessário para exibição)
- O nome do arquivo inclui o ID do usuário para evitar conflitos

## 🐛 Solução de Problemas:

### Erro: "Bucket not found"
- Execute o script SQL `supabase_avatars_bucket.sql` no SQL Editor do Supabase

### Erro: "Permission denied"
- Verifique se as políticas RLS foram criadas corretamente
- Execute novamente o script SQL

### Imagem não aparece
- Verifique se o bucket está marcado como **público**
- Limpe o cache do navegador (Ctrl + F5)
- Verifique a URL da imagem no console do navegador

### Upload muito lento
- A compressão pode levar alguns segundos para imagens grandes
- Aguarde a mensagem de sucesso aparecer

