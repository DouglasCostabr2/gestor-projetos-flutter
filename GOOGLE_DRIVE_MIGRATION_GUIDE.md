# Guia de Migração - Google Drive Service

## 📋 Visão Geral

Este guia explica como migrar do serviço legado `google_drive_oauth_service.dart` para os novos serviços especializados do Google Drive.

---

## 🔄 Antes vs Depois

### Antes (Serviço Legado)

```dart
import '../services/google_drive_oauth_service.dart';

final driveService = GoogleDriveOAuthService();
final client = await driveService.getAuthedClient();
```

### Depois (Novos Serviços)

```dart
import '../services/google_drive/google_drive_service.dart';

final driveService = GoogleDriveService();
final client = await driveService.getAuthedClient();
```

---

## 📚 Mapeamento de Métodos

### Autenticação

| Método Legado | Novo Serviço | Novo Método |
|---------------|--------------|-------------|
| `getAuthedClient()` | `GoogleDriveService` | `getAuthedClient()` |
| `saveRefreshToken()` | `GoogleDriveService` | `saveRefreshToken()` |
| `hasToken()` | `GoogleDriveService` | `hasToken()` |
| `removeToken()` | `GoogleDriveService` | `removeToken()` |

### Pastas

| Método Legado | Novo Serviço | Novo Método |
|---------------|--------------|-------------|
| `getOrCreateRootFolder()` | `GoogleDriveService` | `getOrCreateRootFolder()` |
| `getOrCreateSubfolder()` | `GoogleDriveService` | `getOrCreateSubfolder()` |
| `renameFolder()` | `GoogleDriveService` | `renameFolder()` |
| `deleteFolder()` | `GoogleDriveService` | `deleteFolder()` |
| `findFolderByName()` | `GoogleDriveService` | `findFolderByName()` |

### Arquivos

| Método Legado | Novo Serviço | Novo Método |
|---------------|--------------|-------------|
| `deleteFile()` | `GoogleDriveService` | `deleteFile()` |
| `renameFile()` | `GoogleDriveService` | `renameFile()` |
| `listFilesInFolder()` | `GoogleDriveService` | `listFilesInFolder()` |
| `moveFile()` | `GoogleDriveService` | `moveFile()` |
| `findFileByName()` | `GoogleDriveService` | `findFileByName()` |

### Upload

| Método Legado | Novo Serviço | Novo Método |
|---------------|--------------|-------------|
| `uploadFile()` | `GoogleDriveService` | `uploadFile()` |
| `uploadMultipleFiles()` | `GoogleDriveService` | `uploadMultipleFiles()` |
| `replaceFile()` | `GoogleDriveService` | `replaceFile()` |
| `checkFileExists()` | `GoogleDriveService` | `checkFileExists()` |

### Métodos de Alto Nível

| Método Legado | Novo Serviço | Novo Método |
|---------------|--------------|-------------|
| `createProjectFolder()` | `GoogleDriveService` | `createProjectFolder()` |
| `createTaskFolder()` | `GoogleDriveService` | `createTaskFolder()` |

---

## 🔧 Exemplos de Migração

### Exemplo 1: Upload de Arquivo

#### Antes
```dart
import '../services/google_drive_oauth_service.dart';

final driveService = GoogleDriveOAuthService();
final client = await driveService.getAuthedClient();

final uploaded = await driveService.uploadFile(
  client: client,
  folderId: 'folder123',
  filename: 'image.jpg',
  bytes: imageBytes,
  mimeType: 'image/jpeg',
);
```

#### Depois
```dart
import '../services/google_drive/google_drive_service.dart';

final driveService = GoogleDriveService();
final client = await driveService.getAuthedClient();

final uploaded = await driveService.uploadFile(
  client: client,
  folderId: 'folder123',
  filename: 'image.jpg',
  bytes: imageBytes,
  mimeType: 'image/jpeg',
);
```

**Mudança:** Apenas o import!

### Exemplo 2: Criar Estrutura de Pastas

#### Antes
```dart
import '../services/google_drive_oauth_service.dart';

final driveService = GoogleDriveOAuthService();
final client = await driveService.getAuthedClient();

final projectFolderId = await driveService.createProjectFolder(
  client: client,
  clientName: 'Cliente ABC',
  projectName: 'Projeto XYZ',
  companyName: 'Empresa 123',
);
```

#### Depois
```dart
import '../services/google_drive/google_drive_service.dart';

final driveService = GoogleDriveService();
final client = await driveService.getAuthedClient();

final projectFolderId = await driveService.createProjectFolder(
  client: client,
  clientName: 'Cliente ABC',
  projectName: 'Projeto XYZ',
  companyName: 'Empresa 123',
);
```

**Mudança:** Apenas o import!

### Exemplo 3: Deletar Arquivo

#### Antes
```dart
import '../services/google_drive_oauth_service.dart';

final driveService = GoogleDriveOAuthService();
final client = await driveService.getAuthedClient();

await driveService.deleteFile(
  client: client,
  driveFileId: 'file123',
);
```

#### Depois
```dart
import '../services/google_drive/google_drive_service.dart';

final driveService = GoogleDriveService();
final client = await driveService.getAuthedClient();

await driveService.deleteFile(
  client: client,
  driveFileId: 'file123',
);
```

**Mudança:** Apenas o import!

---

## 🎯 Vantagens dos Novos Serviços

### 1. Melhor Organização
- Código dividido em serviços especializados
- Cada serviço tem uma responsabilidade clara
- Fácil localização de funcionalidades

### 2. Tratamento de Erros
- Exceções customizadas (`DriveException`, `AuthException`, etc.)
- Logging consistente via `ErrorHandler`
- Mensagens de erro mais claras

### 3. Documentação
- Todos os métodos documentados
- Exemplos de uso incluídos
- Parâmetros e retornos explicados

### 4. Testabilidade
- Serviços menores e mais focados
- Fácil criação de mocks
- Testes mais simples

### 5. Manutenibilidade
- Código mais limpo
- Fácil adição de novas funcionalidades
- Menos acoplamento

---

## 📝 Checklist de Migração

### Passo 1: Atualizar Imports
- [ ] Substituir `import '../services/google_drive_oauth_service.dart';`
- [ ] Por `import '../services/google_drive/google_drive_service.dart';`

### Passo 2: Verificar Instanciação
- [ ] Substituir `GoogleDriveOAuthService()` por `GoogleDriveService()`

### Passo 3: Testar Funcionalidades
- [ ] Autenticação
- [ ] Upload de arquivos
- [ ] Criação de pastas
- [ ] Deleção de arquivos/pastas
- [ ] Renomeação

### Passo 4: Atualizar Tratamento de Erros
- [ ] Capturar exceções customizadas
- [ ] Usar `ErrorHandler` para logging
- [ ] Exibir mensagens amigáveis ao usuário

---

## ⚠️ Pontos de Atenção

### 1. Compatibilidade Total
Os novos serviços mantêm **100% de compatibilidade** com a API anterior. Você só precisa mudar o import!

### 2. Exceções
Os novos serviços lançam exceções customizadas. Certifique-se de capturá-las adequadamente:

```dart
try {
  await driveService.uploadFile(...);
} catch (e) {
  if (e is DriveException) {
    ErrorHandler.showErrorSnackBar(context, e);
  } else if (e is AuthException) {
    // Redirecionar para login
  }
}
```

### 3. Logging
Os novos serviços usam `ErrorHandler.logError()` para logging consistente. Verifique os logs para debug.

---

## 🔍 Arquivos que Precisam Migração

### Alta Prioridade
1. `lib/services/briefing_image_service.dart` - Já migrado ✅
2. `lib/widgets/custom_briefing_editor.dart` - Já migrado ✅

### Média Prioridade
3. Outros arquivos que usam `GoogleDriveOAuthService` diretamente

### Baixa Prioridade
4. Testes que mockam o serviço legado

---

## 🚀 Próximos Passos

1. **Migrar todos os arquivos** que usam o serviço legado
2. **Testar completamente** todas as funcionalidades
3. **Remover o arquivo legado** `google_drive_oauth_service.dart`
4. **Atualizar documentação** do projeto

---

## 📞 Suporte

Se encontrar problemas durante a migração:

1. Verifique a documentação em `ARCHITECTURE.md`
2. Consulte os exemplos neste guia
3. Revise os logs de erro usando `ErrorHandler`
4. Verifique se todos os imports foram atualizados

---

## ✅ Conclusão

A migração é **simples e direta**:
1. Atualizar imports
2. Testar funcionalidades
3. Pronto! ✨

Os novos serviços oferecem a mesma funcionalidade com melhor organização, documentação e tratamento de erros.

**Boa migração! 🚀**

