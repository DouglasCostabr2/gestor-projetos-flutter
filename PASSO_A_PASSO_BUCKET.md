# 🎯 Passo a Passo: Criar Bucket de Avatares no Supabase

## 📋 Método Recomendado: Interface do Supabase

### Passo 1: Acessar o Storage
1. Abra https://app.supabase.com
2. Faça login
3. Selecione seu projeto: **zfgsddweabsemxcchxjq**
4. No menu lateral esquerdo, clique em **Storage**

### Passo 2: Criar Novo Bucket
1. Clique no botão **New bucket** (canto superior direito)
2. Preencha os campos:
   - **Name**: `avatars` (exatamente assim, sem maiúsculas)
   - **Public bucket**: ✅ **MARQUE ESTA OPÇÃO** (muito importante!)
   - **File size limit**: `5` MB
   - **Allowed MIME types**: Deixe em branco ou adicione:
     - `image/jpeg`
     - `image/jpg`
     - `image/png`
     - `image/webp`

3. Clique em **Create bucket**

### Passo 3: Configurar Políticas (RLS)
1. Após criar o bucket, clique nele na lista
2. Clique na aba **Policies** (ou **Políticas**)
3. Clique em **New policy**

#### Política 1: Leitura Pública
- **Policy name**: `Public Access`
- **Allowed operation**: `SELECT`
- **Policy definition**: 
  ```sql
  bucket_id = 'avatars'
  ```
- Clique em **Review** e depois **Save policy**

#### Política 2: Upload Autenticado
- Clique em **New policy** novamente
- **Policy name**: `Authenticated Upload`
- **Allowed operation**: `INSERT`
- **Policy definition**:
  ```sql
  bucket_id = 'avatars' AND auth.role() = 'authenticated'
  ```
- Clique em **Review** e depois **Save policy**

#### Política 3: Atualização Autenticada
- Clique em **New policy** novamente
- **Policy name**: `Authenticated Update`
- **Allowed operation**: `UPDATE`
- **Policy definition**:
  ```sql
  bucket_id = 'avatars' AND auth.role() = 'authenticated'
  ```
- Clique em **Review** e depois **Save policy**

#### Política 4: Deleção Autenticada
- Clique em **New policy** novamente
- **Policy name**: `Authenticated Delete`
- **Allowed operation**: `DELETE`
- **Policy definition**:
  ```sql
  bucket_id = 'avatars' AND auth.role() = 'authenticated'
  ```
- Clique em **Review** e depois **Save policy**

---

## 🔧 Método Alternativo: SQL Editor

Se preferir usar SQL (mais rápido):

### Passo 1: Abrir SQL Editor
1. No menu lateral do Supabase, clique em **SQL Editor**
2. Clique em **New query**

### Passo 2: Executar Script
1. Copie TODO o conteúdo do arquivo `supabase_avatars_bucket_simples.sql`
2. Cole no editor SQL
3. Clique em **Run** (ou pressione Ctrl+Enter)

### Passo 3: Verificar Resultado
- Deve aparecer "Success. No rows returned"
- A última query deve retornar 1 linha mostrando o bucket 'avatars'

---

## ✅ Verificação Final

### Como saber se funcionou:

1. Vá em **Storage** no menu lateral
2. Você deve ver o bucket **avatars** na lista
3. Clique nele
4. Deve estar vazio (sem arquivos ainda)
5. Na aba **Policies**, deve ter 4 políticas criadas

### Testar no App:

1. Abra o aplicativo Flutter
2. Vá em **Configurações** (último item do menu)
3. Clique no **botão de câmera** no avatar
4. Selecione uma imagem
5. Aguarde o upload
6. Deve aparecer "Foto de perfil atualizada com sucesso!"
7. A foto deve aparecer no avatar

---

## 🐛 Solução de Problemas

### Erro: "Bucket not found"
- O bucket não foi criado corretamente
- Execute o script SQL novamente

### Erro: "Permission denied" ou "new row violates row-level security"
- As políticas RLS não foram criadas
- Execute as políticas manualmente ou via SQL

### Erro: "File too large"
- A imagem é maior que 5MB
- Tente com uma imagem menor
- Ou aumente o limite no bucket

### Imagem não aparece após upload
- Verifique se o bucket está marcado como **público**
- Vá em Storage > avatars > Configuration
- Certifique-se que "Public bucket" está ativado

### Upload muito lento
- Normal para imagens grandes
- A compressão pode levar alguns segundos
- Aguarde a mensagem de sucesso

---

## 📞 Precisa de Ajuda?

Se nada funcionar:

1. Tire um print da tela de erro
2. Verifique o console do navegador (F12)
3. Verifique se o bucket 'avatars' existe em Storage
4. Verifique se as 4 políticas foram criadas

