# Criação de Instalador para My Business

Este diretório contém os arquivos necessários para criar um instalador profissional do My Business para Windows.

## 📋 Pré-requisitos

1. **Inno Setup** (gratuito)
   - Download: https://jrsoftware.org/isdl.php
   - Versão recomendada: 6.x ou superior

2. **App compilado em modo Release**
   ```bash
   flutter build windows --release
   ```

## 🚀 Como Criar o Instalador

### Método 1: Interface Gráfica (Recomendado para iniciantes)

1. Abra o **Inno Setup Compiler**
2. Clique em **File > Open** e selecione `setup.iss`
3. Edite as informações necessárias (versão, empresa, etc.)
4. Clique em **Build > Compile** (ou pressione F9)
5. O instalador será criado em `installer/Output/`

### Método 2: Linha de Comando (Recomendado para automação)

```bash
# Windows
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss

# PowerShell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss
```

## ⚙️ Configuração do Script

### Informações Básicas

Edite estas linhas no arquivo `setup.iss`:

```pascal
#define MyAppName "My Business"
#define MyAppVersion "1.1.0"          // ← ATUALIZAR A CADA VERSÃO
#define MyAppPublisher "Sua Empresa"  // ← ALTERAR
#define MyAppURL "https://seusite.com" // ← ALTERAR
```

### App ID Único

Na primeira vez, gere um GUID único:

1. Acesse: https://www.guidgenerator.com/
2. Copie o GUID gerado
3. Substitua em `setup.iss`:

```pascal
AppId={{COLE-SEU-GUID-AQUI}}
```

Exemplo:
```pascal
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}}
```

⚠️ **IMPORTANTE**: Nunca mude este GUID depois de publicar a primeira versão!

## 📦 Estrutura do Instalador

O instalador criado irá:

1. ✅ Verificar se o app está rodando e fechar se necessário
2. ✅ Instalar em `C:\Program Files\My Business\`
3. ✅ Criar atalho no Menu Iniciar
4. ✅ Criar atalho na Área de Trabalho (opcional)
5. ✅ Registrar no "Adicionar ou Remover Programas"
6. ✅ Criar desinstalador automático
7. ✅ Executar o app após instalação (opcional)

## 🎨 Personalização

### Ícone do Instalador

Substitua o ícone padrão:

```pascal
SetupIconFile=..\windows\runner\resources\app_icon.ico
```

### Imagens do Wizard

Adicione imagens personalizadas (opcional):

1. Crie `WizardImage.bmp` (164x314 pixels)
2. Crie `WizardSmallImage.bmp` (55x58 pixels)
3. Atualize em `setup.iss`:

```pascal
WizardImageFile=WizardImage.bmp
WizardSmallImageFile=WizardSmallImage.bmp
```

### Idioma

O instalador está configurado para Português do Brasil:

```pascal
[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
```

Para adicionar mais idiomas:

```pascal
[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
```

## 🔄 Processo Completo de Release

### 1. Atualizar Versão

```yaml
# pubspec.yaml
version: 1.2.0+3
```

### 2. Compilar App

```bash
flutter build windows --release
```

### 3. Atualizar Script do Instalador

```pascal
// setup.iss
#define MyAppVersion "1.2.0"
```

### 4. Compilar Instalador

```bash
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" setup.iss
```

### 5. Testar Instalador

```bash
# Execute o instalador gerado
installer\Output\MyBusiness-Setup-1.2.0.exe
```

### 6. Publicar

Faça upload para:
- GitHub Releases
- Supabase Storage
- Seu servidor web

### 7. Registrar no Supabase

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.2.0',
  'https://github.com/user/repo/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe',
  '# Versão 1.2.0\n\n## Novidades\n- ...',
  false
);
```

## 🧪 Testes Recomendados

Antes de publicar, teste:

1. ✅ Instalação limpa (sem versão anterior)
2. ✅ Atualização sobre versão anterior
3. ✅ Desinstalação completa
4. ✅ Instalação em diferentes versões do Windows
5. ✅ Instalação com/sem privilégios de admin
6. ✅ Execução após instalação
7. ✅ Atalhos funcionando

## 📝 Checklist de Release

- [ ] Versão atualizada em `pubspec.yaml`
- [ ] Versão atualizada em `setup.iss`
- [ ] App compilado em modo Release
- [ ] Instalador compilado sem erros
- [ ] Instalador testado em máquina limpa
- [ ] Instalador assinado digitalmente (opcional)
- [ ] Upload para servidor/GitHub
- [ ] Versão registrada no Supabase
- [ ] Release notes escritas
- [ ] Changelog atualizado

## 🔐 Assinatura Digital (Opcional mas Recomendado)

Para evitar avisos do Windows SmartScreen:

1. Obtenha um certificado de assinatura de código
2. Adicione ao script:

```pascal
[Setup]
SignTool=signtool
SignedUninstaller=yes
```

3. Configure o SignTool:

```pascal
[Setup]
SignTool=signtool sign /f "MeuCertificado.pfx" /p "senha" /t http://timestamp.digicert.com $f
```

## 🐛 Troubleshooting

### Erro: "Cannot find file"

**Causa**: Caminho do executável incorreto

**Solução**: Verifique se o app foi compilado:
```bash
flutter build windows --release
```

### Erro: "Access denied"

**Causa**: Inno Setup precisa de permissões

**Solução**: Execute o Inno Setup como Administrador

### Instalador muito grande

**Causa**: Arquivos desnecessários incluídos

**Solução**: Revise a seção `[Files]` e use `Compression=lzma2/max`

### Antivírus bloqueia instalador

**Causa**: Instalador não assinado

**Solução**: 
- Assine digitalmente o instalador
- Ou adicione exceção no antivírus durante testes

## 📚 Recursos Adicionais

- [Documentação Inno Setup](https://jrsoftware.org/ishelp/)
- [Exemplos de Scripts](https://jrsoftware.org/ishelp/index.php?topic=samples)
- [Fórum Inno Setup](https://groups.google.com/g/innosetup)
- [Assinatura de Código](https://docs.microsoft.com/en-us/windows/win32/seccrypto/signtool)

## 💡 Dicas

1. **Versionamento**: Sempre incremente a versão corretamente
2. **Testes**: Teste em máquina virtual limpa
3. **Backup**: Mantenha backup dos instaladores antigos
4. **Logs**: Habilite logs durante desenvolvimento:
   ```pascal
   [Setup]
   SetupLogging=yes
   ```
5. **Compressão**: Use `lzma2/max` para menor tamanho
6. **Desinstalação**: Teste a desinstalação também!

## 🎯 Próximos Passos

Após criar o instalador:

1. Teste em diferentes máquinas
2. Publique no GitHub Releases
3. Registre no Supabase
4. Notifique os usuários
5. Monitore feedbacks

---

**Dúvidas?** Consulte a [documentação completa](../docs/SISTEMA_ATUALIZACAO.md)

