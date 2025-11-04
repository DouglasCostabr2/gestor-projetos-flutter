# Configuração do Google OAuth

## ℹ️ Credenciais Incluídas

As credenciais do Google OAuth já estão configuradas no código (`lib/services/google_drive/auth_service.dart`) para facilitar o uso.

**Nota**: Para projetos open-source ou compartilhados, considere usar variáveis de ambiente.

## 📋 Como Funciona

### Credenciais Pré-configuradas

O app já vem com credenciais OAuth configuradas em `lib/services/google_drive/auth_service.dart`.

**Você não precisa fazer nada!** A integração com Google Drive funcionará automaticamente.

### Usar Suas Próprias Credenciais (Opcional)

Se você quiser usar suas próprias credenciais do Google Cloud:

1. **Obter Credenciais**:
   - Acesse: https://console.cloud.google.com/apis/credentials
   - Crie um novo projeto ou selecione um existente
   - Clique em "Criar Credenciais" → "ID do cliente OAuth 2.0"
   - Configure a tela de consentimento OAuth se necessário
   - Tipo de aplicativo: "Aplicativo de desktop"
   - Copie o **Client ID** e **Client Secret**

2. **Atualizar no Código**:
   - Abra `lib/services/google_drive/auth_service.dart`
   - Localize o método `clientViaRefreshToken`
   - Substitua as credenciais pelas suas:
   ```dart
   final clientId = ClientId(
     'SEU-CLIENT-ID.apps.googleusercontent.com',
     'SEU-CLIENT-SECRET',
   );
   ```

## 🔒 Segurança

Para projetos privados (como este):
- ✅ Credenciais podem estar no código
- ✅ O repositório é privado, então as credenciais estão seguras

Para projetos open-source ou compartilhados:
- ⚠️ Use variáveis de ambiente
- ⚠️ Nunca commite credenciais no código
- ⚠️ Use GitHub Secrets para CI/CD

## 📝 Notas

- As credenciais já estão configuradas e funcionando
- A integração com Google Drive está pronta para uso
- Cada usuário precisará autorizar o app na primeira vez que usar o Google Drive

