# Deploy da Edge Function - Trocar Senha

## 📋 Instruções para Deploy

A funcionalidade de trocar senha de usuários requer uma Edge Function no Supabase.

### Pré-requisitos

1. Ter o Supabase CLI instalado:
   ```bash
   npm install -g supabase
   ```

2. Estar autenticado no Supabase:
   ```bash
   supabase login
   ```

### Deploy da Função

Execute o seguinte comando na raiz do projeto:

```bash
supabase functions deploy change-user-password
```

### Verificar o Deploy

Após o deploy, você pode verificar se a função foi criada corretamente:

1. Acesse o Supabase Dashboard
2. Vá para **Edge Functions**
3. Procure por `change-user-password`
4. Verifique se o status é **Active**

### Testar a Função

Você pode testar a função usando o Supabase Dashboard:

1. Clique na função `change-user-password`
2. Clique em **Invoke**
3. Envie um payload de teste:
   ```json
   {
     "user_id": "uuid-do-usuario",
     "new_password": "nova-senha-123"
   }
   ```

### Solução de Problemas

Se receber um erro de permissão:

1. Verifique se o usuário é admin
2. Verifique se o token de autenticação é válido
3. Verifique se a função tem acesso ao `SUPABASE_SERVICE_ROLE_KEY`

## 🔐 Segurança

- A função verifica se o usuário é admin antes de permitir a mudança de senha
- Usa o `SUPABASE_SERVICE_ROLE_KEY` para fazer a mudança (requer permissões elevadas)
- Valida o token JWT do usuário

## 📝 Notas

- A função está localizada em `supabase/functions/change-user-password/`
- O arquivo principal é `index.ts`
- A função é invocada via `Supabase.instance.client.functions.invoke()`

