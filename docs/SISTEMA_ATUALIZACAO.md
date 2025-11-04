# Sistema de Atualização Automática

Este documento descreve o sistema completo de atualização automática implementado no aplicativo My Business.

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura](#arquitetura)
3. [Configuração Inicial](#configuração-inicial)
4. [Como Publicar uma Nova Versão](#como-publicar-uma-nova-versão)
5. [Fluxo de Atualização](#fluxo-de-atualização)
6. [Testes](#testes)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Visão Geral

O sistema de atualização automática permite que os usuários recebam notificações sobre novas versões do aplicativo e possam atualizar com apenas alguns cliques.

### Características:

- ✅ Verificação automática na inicialização do app
- ✅ Download automático do instalador
- ✅ Barra de progresso durante o download
- ✅ Atualizações opcionais ou obrigatórias
- ✅ Notas de lançamento (release notes)
- ✅ Versionamento semântico (major.minor.patch)
- ✅ Versão mínima suportada

---

## 🏗️ Arquitetura

### Componentes Principais:

1. **Tabela `app_versions` (Supabase)**
   - Armazena informações sobre versões disponíveis
   - Localização: `supabase/migrations/create_app_versions_table.sql`

2. **Modelo `AppUpdate`**
   - Representa uma atualização disponível
   - Localização: `lib/models/app_update.dart`

3. **Serviço `UpdateService`**
   - Verifica atualizações
   - Baixa e instala atualizações
   - Localização: `lib/services/update_service.dart`

4. **Widget `UpdateDialog`**
   - Interface de usuário para notificação
   - Localização: `lib/widgets/update_dialog.dart`

5. **Integração no `main.dart`**
   - Verifica atualizações na inicialização
   - Localização: `lib/main.dart`

---

## ⚙️ Configuração Inicial

### 1. Criar a Tabela no Supabase

Execute o script SQL no Supabase Dashboard:

```bash
# Navegue até: Supabase Dashboard > SQL Editor
# Cole e execute o conteúdo de: supabase/migrations/create_app_versions_table.sql
```

Ou use a CLI do Supabase:

```bash
supabase db push
```

### 2. Verificar Dependências

As seguintes dependências já foram adicionadas ao `pubspec.yaml`:

```yaml
dependencies:
  package_info_plus: ^9.0.0  # Obter versão atual do app
  dio: ^5.9.0                # Download de arquivos
  path_provider: ^2.1.5      # Diretórios do sistema
  url_launcher: ^6.3.2       # Abrir URLs (já existente)
```

### 3. Configurar Versão do App

Edite o arquivo `pubspec.yaml`:

```yaml
version: 1.1.0+2
#        ^^^^^ ^^
#        |     |
#        |     +-- Build number (incrementar a cada build)
#        +-------- Versão semântica (major.minor.patch)
```

---

## 🚀 Como Publicar uma Nova Versão

### Passo 1: Atualizar a Versão no Código

Edite `pubspec.yaml`:

```yaml
version: 1.2.0+3  # Incrementar versão
```

### Passo 2: Compilar o Aplicativo

```bash
# Compilar versão release
flutter build windows --release

# O executável estará em:
# build/windows/x64/runner/Release/gestor_projetos_flutter.exe
```

### Passo 3: Criar Instalador (Opcional mas Recomendado)

Use ferramentas como:
- **Inno Setup** (gratuito, recomendado)
- **NSIS**
- **Advanced Installer**

Exemplo com Inno Setup:

```iss
[Setup]
AppName=My Business
AppVersion=1.2.0
DefaultDirName={pf}\MyBusiness
OutputBaseFilename=MyBusiness-Setup-1.2.0

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
```

### Passo 4: Hospedar o Instalador

Opções:

#### A) GitHub Releases (Recomendado - Gratuito)

```bash
# 1. Criar tag
git tag v1.2.0
git push origin v1.2.0

# 2. Criar release no GitHub
# - Vá para: https://github.com/seu-usuario/seu-repo/releases/new
# - Escolha a tag v1.2.0
# - Faça upload do instalador: MyBusiness-Setup-1.2.0.exe
# - Publique o release

# 3. Copiar URL do instalador
# Exemplo: https://github.com/seu-usuario/seu-repo/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe
```

#### B) Supabase Storage

```bash
# Upload via Supabase Dashboard
# Storage > Create bucket "app-installers" (público)
# Upload: MyBusiness-Setup-1.2.0.exe
# Copiar URL pública
```

#### C) Servidor Próprio

```bash
# Upload para seu servidor web
# Exemplo: https://seusite.com/downloads/MyBusiness-Setup-1.2.0.exe
```

### Passo 5: Registrar Versão no Supabase

Execute no SQL Editor do Supabase:

```sql
INSERT INTO app_versions (
  version,
  download_url,
  release_notes,
  is_mandatory,
  min_supported_version
) VALUES (
  '1.2.0',
  'https://github.com/seu-usuario/seu-repo/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe',
  '# Versão 1.2.0

## Novidades
- Nova funcionalidade X
- Melhorias na interface Y
- Integração com Z

## Correções
- Corrigido bug A
- Melhorado desempenho B',
  false,  -- true para forçar atualização
  '1.0.0' -- versão mínima suportada (opcional)
);
```

---

## 🔄 Fluxo de Atualização

### Para o Usuário:

1. **Inicialização do App**
   - App verifica automaticamente por atualizações (após 2 segundos)

2. **Notificação**
   - Se houver atualização, um diálogo é exibido
   - Mostra versão, notas de lançamento e botões de ação

3. **Opções do Usuário**
   - **Atualização Opcional**: "Mais tarde" ou "Atualizar agora"
   - **Atualização Obrigatória**: Apenas "Atualizar agora"

4. **Download**
   - Barra de progresso mostra o andamento
   - Arquivo salvo em diretório temporário

5. **Instalação**
   - Instalador é executado automaticamente
   - App atual é fechado
   - Instalador substitui arquivos
   - Usuário pode reabrir o app atualizado

### Para o Desenvolvedor:

```dart
// O código já está integrado no main.dart
// Verificação automática acontece em _MyAppState.initState()

Future<void> _checkForUpdates() async {
  await Future.delayed(const Duration(seconds: 2));
  
  final updateService = UpdateService();
  final update = await updateService.checkForUpdates();
  
  if (update != null) {
    await UpdateDialog.show(context, update, updateService);
  }
}
```

---

## 🧪 Testes

### Testar Verificação de Atualização

1. **Criar versão de teste no Supabase:**

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '99.99.99',  -- Versão muito alta para sempre aparecer
  'https://exemplo.com/teste.exe',
  '# Versão de Teste\n\nEsta é uma versão de teste.',
  false
);
```

2. **Executar o app:**

```bash
flutter run -d windows
```

3. **Verificar:**
   - Diálogo deve aparecer após 2 segundos
   - Informações devem estar corretas
   - Botões devem funcionar

4. **Limpar teste:**

```sql
DELETE FROM app_versions WHERE version = '99.99.99';
```

### Testar Download (Cuidado!)

⚠️ **ATENÇÃO**: Testar o download completo irá fechar o aplicativo!

```dart
// Para testar sem fechar o app, comente a linha em update_service.dart:
// exit(0);  // <-- Comentar esta linha
```

---

## 🔧 Troubleshooting

### Problema: Diálogo não aparece

**Possíveis causas:**
- Tabela `app_versions` vazia
- Versão no Supabase é menor ou igual à atual
- Erro de conexão com Supabase

**Solução:**
```bash
# Verificar logs no console
flutter run -d windows

# Procurar por:
# 🔍 Verificando atualizações...
# 📱 Versão atual: X.X.X
# 🌐 Versão mais recente no servidor: X.X.X
```

### Problema: Erro ao baixar

**Possíveis causas:**
- URL inválida
- Arquivo não existe
- Sem conexão com internet

**Solução:**
- Verificar URL no navegador
- Testar download manual
- Verificar logs de erro

### Problema: Instalador não executa

**Possíveis causas:**
- Arquivo corrompido
- Antivírus bloqueando
- Permissões insuficientes

**Solução:**
- Verificar integridade do arquivo
- Adicionar exceção no antivírus
- Executar como administrador

---

## 📝 Notas Importantes

1. **Versionamento Semântico**
   - Use o formato `major.minor.patch`
   - Exemplo: `1.2.3`
   - Incremente corretamente conforme as mudanças

2. **Atualizações Obrigatórias**
   - Use com moderação
   - Apenas para correções críticas ou mudanças de segurança
   - Usuário não pode fechar o diálogo

3. **Versão Mínima Suportada**
   - Define versões antigas que devem atualizar obrigatoriamente
   - Útil para descontinuar versões muito antigas

4. **Release Notes**
   - Use Markdown para formatação
   - Seja claro e conciso
   - Liste novidades e correções

5. **Segurança**
   - Considere assinar digitalmente o executável
   - Use HTTPS para URLs de download
   - Valide integridade dos arquivos (hash)

---

## 🎓 Exemplos de Uso

### Atualização Opcional

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.3.0',
  'https://github.com/user/repo/releases/download/v1.3.0/MyBusiness-Setup-1.3.0.exe',
  '# Novidades\n- Nova funcionalidade\n- Melhorias de UI',
  false  -- Opcional
);
```

### Atualização Obrigatória

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '2.0.0',
  'https://github.com/user/repo/releases/download/v2.0.0/MyBusiness-Setup-2.0.0.exe',
  '# Atualização Crítica\n- Correção de segurança\n- Mudanças importantes',
  true  -- Obrigatória
);
```

### Com Versão Mínima

```sql
INSERT INTO app_versions (
  version, download_url, release_notes, is_mandatory, min_supported_version
) VALUES (
  '2.1.0',
  'https://github.com/user/repo/releases/download/v2.1.0/MyBusiness-Setup-2.1.0.exe',
  '# Versão 2.1.0\n- Novas funcionalidades',
  false,
  '2.0.0'  -- Versões abaixo de 2.0.0 devem atualizar obrigatoriamente
);
```

---

## 📚 Referências

- [Package Info Plus](https://pub.dev/packages/package_info_plus)
- [Dio](https://pub.dev/packages/dio)
- [Semantic Versioning](https://semver.org/)
- [Inno Setup](https://jrsoftware.org/isinfo.php)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)

