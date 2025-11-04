# 🔐 Configuração de Recuperação de Senha

## ✅ O Que Foi Implementado

Você agora tem um **fluxo completo de recuperação de senha** dentro do aplicativo Flutter, sem precisar de um site externo!

### Componentes Criados:

1. **`forgot_password_dialog.dart`** - Diálogo para solicitar recuperação de senha
2. **`reset_password_page.dart`** - Página para redefinir a senha
3. **Métodos no módulo de autenticação:**
   - `resetPasswordForEmail()` - Solicita email de recuperação
   - `updatePassword()` - Atualiza a senha do usuário

---

## 🚀 Como Funciona

### Fluxo Completo:

```
1. Usuário clica em "Esqueci a Senha" na tela de login
   ↓
2. Abre um diálogo para inserir o email
   ↓
3. Clica em "Enviar"
   ↓
4. Supabase envia um email com link de recuperação
   ↓
5. Usuário clica no link do email
   ↓
6. Aplicativo abre automaticamente a página de reset de senha
   ↓
7. Usuário insere nova senha
   ↓
8. Senha é atualizada no Supabase
   ↓
9. Usuário é redirecionado para login
```

---

## ⚙️ Configuração no Supabase

### Passo 1: Configurar Email de Recuperação

1. Acesse o **Supabase Dashboard**
2. Vá para **Authentication** → **Email Templates**
3. Procure por **"Reset Password"** (ou "Password Recovery")
4. Edite o template e certifique-se de que o link contém:

```
{{ .ConfirmationURL }}
```

Este link será algo como:
```
https://zfgsddweabsemxcchxjq.supabase.co/auth/v1/verify?token=...&type=recovery
```

### Passo 2: Configurar Deep Link (IMPORTANTE!)

O Supabase precisa saber para onde redirecionar após o usuário clicar no link.

**Para Windows Desktop:**

1. No Supabase Dashboard, vá para **Authentication** → **URL Configuration**
2. Em **Redirect URLs**, adicione:
   ```
   io.supabase.flutter://reset-password
   ```

3. Salve as alterações

### Passo 3: Configurar o Aplicativo Flutter

O aplicativo já está configurado para:
- Aceitar o deep link `io.supabase.flutter://reset-password`
- Abrir a página de reset de senha automaticamente
- Processar o token de recuperação do Supabase

---

## 🧪 Testando Localmente

### Teste 1: Fluxo Completo (com email real)

1. Execute o aplicativo
2. Clique em "Esqueci a Senha"
3. Insira seu email
4. Clique em "Enviar"
5. Verifique seu email
6. Clique no link de recuperação
7. A página de reset de senha deve abrir
8. Insira uma nova senha
9. Clique em "Atualizar Senha"
10. Você será redirecionado para login

### Teste 2: Teste sem Email (Desenvolvimento)

Se você quiser testar sem enviar emails reais:

1. Vá para **Supabase Dashboard** → **Authentication** → **Settings**
2. Procure por **"Email Rate Limit"** ou **"Email Confirmations"**
3. Desabilite a confirmação de email para testes (se disponível)

---

## 📱 Fluxo de Usuário

### Tela de Login

```
┌─────────────────────────────────┐
│         Entrar                  │
├─────────────────────────────────┤
│ Email: [________________]        │
│ Senha: [________________]        │
│                                 │
│        Esqueci a Senha ← NOVO!  │
│                                 │
│ [    Entrar    ]                │
└─────────────────────────────────┘
```

### Diálogo de Recuperação

```
┌─────────────────────────────────┐
│  Recuperar Senha                │
├─────────────────────────────────┤
│ Email: [________________]        │
│                                 │
│ Enviaremos um link de           │
│ recuperação para seu email.     │
│                                 │
│ [Cancelar]  [Enviar]            │
└─────────────────────────────────┘
```

### Página de Reset de Senha

```
┌─────────────────────────────────┐
│  Redefinir Senha                │
├─────────────────────────────────┤
│ Nova Senha: [________________]   │
│ Confirmar:  [________________]   │
│                                 │
│ [Atualizar Senha]               │
└─────────────────────────────────┘
```

---

## 🔒 Segurança

### O que está protegido:

✅ **Tokens de recuperação** - Gerados pelo Supabase, válidos por 1 hora  
✅ **Senhas** - Nunca são armazenadas em texto plano  
✅ **Deep links** - Apenas o aplicativo autorizado pode processar  
✅ **Validação** - Senhas devem ter pelo menos 6 caracteres  

### Boas práticas implementadas:

- ✅ Validação de email antes de enviar
- ✅ Validação de força de senha
- ✅ Confirmação de senha (deve corresponder)
- ✅ Mensagens de erro claras
- ✅ Loading states durante operações
- ✅ Redirecionamento automático após sucesso

---

## 🐛 Troubleshooting

### Problema: "Email não recebido"

**Solução:**
1. Verifique a pasta de spam
2. Verifique se o email está correto
3. Aguarde alguns minutos (pode levar tempo)
4. Verifique os logs do Supabase Dashboard

### Problema: "Link expirado"

**Solução:**
1. Solicite um novo email de recuperação
2. Links expiram após 1 hora
3. Clique no link dentro de 1 hora

### Problema: "Página de reset não abre"

**Solução:**
1. Verifique se o deep link está configurado no Supabase
2. Verifique se o aplicativo está instalado
3. Tente abrir manualmente: `io.supabase.flutter://reset-password`

### Problema: "Erro ao atualizar senha"

**Solução:**
1. Verifique se a senha tem pelo menos 6 caracteres
2. Verifique se as senhas correspondem
3. Verifique a conexão com a internet
4. Tente novamente

---

## 📚 Referências

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Flutter Deep Linking](https://flutter.dev/docs/development/ui/navigation/deep-linking)
- [Supabase Password Recovery](https://supabase.com/docs/guides/auth/auth-password-recovery)

---

## ✨ Próximos Passos

1. ✅ Implementação concluída
2. ⏳ Configurar deep link no Supabase (veja "Configuração no Supabase")
3. ⏳ Testar o fluxo completo
4. ⏳ Publicar o aplicativo

---

**Status:** ✅ Pronto para usar!

Agora você tem um fluxo profissional de recuperação de senha sem precisar de um site externo! 🎉

