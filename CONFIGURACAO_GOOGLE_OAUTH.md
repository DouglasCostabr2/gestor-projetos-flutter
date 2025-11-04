# Configuração do Google OAuth

## ⚠️ IMPORTANTE: Segurança das Credenciais

As credenciais do Google OAuth **NÃO DEVEM** ser commitadas no repositório Git. Elas devem ser configuradas como variáveis de ambiente.

## 📋 Passo a Passo

### 1. Obter Credenciais do Google Cloud Console

1. Acesse: https://console.cloud.google.com/apis/credentials
2. Crie um novo projeto ou selecione um existente
3. Clique em "Criar Credenciais" → "ID do cliente OAuth 2.0"
4. Configure a tela de consentimento OAuth se necessário
5. Tipo de aplicativo: "Aplicativo de desktop"
6. Copie o **Client ID** e **Client Secret**

### 2. Configurar Variáveis de Ambiente

#### Para Desenvolvimento (Flutter Run)

Execute o app com as variáveis de ambiente:

```bash
flutter run -d windows --dart-define=GOOGLE_OAUTH_CLIENT_ID=seu-client-id-aqui --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=seu-client-secret-aqui
```

#### Para Build de Produção

```bash
flutter build windows --dart-define=GOOGLE_OAUTH_CLIENT_ID=seu-client-id-aqui --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=seu-client-secret-aqui
```

### 3. Configurar no VS Code (launch.json)

Crie ou edite `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "gestor_projetos_flutter",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=GOOGLE_OAUTH_CLIENT_ID=seu-client-id-aqui",
        "--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=seu-client-secret-aqui"
      ]
    }
  ]
}
```

### 4. Configurar para CI/CD (GitHub Actions)

No GitHub, vá em:
- Settings → Secrets and variables → Actions
- Adicione os secrets:
  - `GOOGLE_OAUTH_CLIENT_ID`
  - `GOOGLE_OAUTH_CLIENT_SECRET`

No workflow:

```yaml
- name: Build Windows
  run: |
    flutter build windows \
      --dart-define=GOOGLE_OAUTH_CLIENT_ID=${{ secrets.GOOGLE_OAUTH_CLIENT_ID }} \
      --dart-define=GOOGLE_OAUTH_CLIENT_SECRET=${{ secrets.GOOGLE_OAUTH_CLIENT_SECRET }}
```

## 🔒 Segurança

- ✅ **NUNCA** commite credenciais no código
- ✅ Use variáveis de ambiente
- ✅ Adicione `.env` ao `.gitignore`
- ✅ Use GitHub Secrets para CI/CD
- ✅ Mantenha `.env.example` atualizado (sem valores reais)

## 📝 Notas

- As credenciais são necessárias apenas para a funcionalidade de Google Drive
- Se não configuradas, o app funcionará normalmente, mas a integração com Google Drive não estará disponível
- O código verifica se as credenciais estão configuradas e exibe mensagem de erro apropriada se não estiverem

