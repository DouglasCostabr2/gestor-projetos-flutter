# 🔧 Troubleshooting - Publicação Windows

## ❌ Problemas Comuns e Soluções

### 1. "Inno Setup não encontrado"

**Erro:**
```
⚠️ Inno Setup não encontrado em C:\Program Files (x86)\Inno Setup 6\ISCC.exe
```

**Soluções:**

1. **Verificar instalação:**
   - Abra `C:\Program Files (x86)\`
   - Procure pasta `Inno Setup 6`
   - Se não existir, instale em: https://jrsoftware.org/isdl.php

2. **Caminho diferente:**
   - Edite `scripts/build_installer.ps1`
   - Altere linha: `$innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"`
   - Para seu caminho real

3. **Usar manualmente:**
   - Abra Inno Setup Compiler
   - File → Open → `windows/installer/setup.iss`
   - Clique Compile

---

### 2. "Erro ao compilar Flutter"

**Erro:**
```
❌ Erro ao compilar! Abortando...
```

**Soluções:**

```bash
# 1. Limpar cache
flutter clean

# 2. Atualizar dependências
flutter pub get

# 3. Verificar versão Flutter
flutter --version

# 4. Tentar novamente
flutter build windows --release

# 5. Se ainda falhar, verificar logs
flutter build windows --release -v
```

**Causas comuns:**
- ❌ Dependências não instaladas
- ❌ Versão Flutter desatualizada
- ❌ Arquivo corrompido em `pubspec.lock`
- ❌ Espaço em disco insuficiente

---

### 3. "Executável não encontrado"

**Erro:**
```
❌ Executável não encontrado em build\windows\x64\runner\Release\gestor_projetos_flutter.exe
```

**Soluções:**

1. **Verificar se build foi bem-sucedido:**
   ```bash
   flutter build windows --release -v
   ```

2. **Verificar estrutura de pastas:**
   ```
   build/
   └── windows/
       └── x64/
           └── runner/
               └── Release/
                   └── gestor_projetos_flutter.exe
   ```

3. **Limpar e reconstruir:**
   ```bash
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

---

### 4. "Instalador muito grande"

**Problema:**
- Arquivo `.exe` > 300 MB

**Soluções:**

1. **Usar compressão LZMA** (já configurado em `setup.iss`)
   ```ini
   Compression=lzma
   SolidCompression=yes
   ```

2. **Remover arquivos desnecessários:**
   - Verifique `build/windows/x64/runner/Release/`
   - Remova arquivos `.pdb` (debug symbols)
   - Remova arquivos temporários

3. **Usar build otimizado:**
   ```bash
   flutter build windows --release --split-debug-info=build/debug_info
   ```

---

### 5. "Programa não inicia após instalar"

**Problema:**
- Instalação bem-sucedida, mas programa não abre

**Soluções:**

1. **Verificar logs:**
   ```bash
   # Abra PowerShell como Admin
   Get-EventLog -LogName Application -Source "gestor_projetos_flutter" -Newest 10
   ```

2. **Testar executável diretamente:**
   ```bash
   # Abra PowerShell na pasta de instalação
   .\gestor_projetos_flutter.exe
   ```

3. **Verificar dependências:**
   - Instale Visual C++ Redistributable:
     https://support.microsoft.com/en-us/help/2977003
   - Instale .NET Runtime (se necessário)

4. **Verificar permissões:**
   - Clique direito no `.exe`
   - Propriedades → Compatibilidade
   - Marque "Executar este programa em modo de compatibilidade"

---

### 6. "Erro: 'The system cannot find the file specified'"

**Problema:**
- Arquivo de configuração ou dependência não encontrada

**Soluções:**

1. **Verificar caminho de arquivos:**
   - Edite `setup.iss`
   - Verifique linha: `Source: "..\..\build\windows\x64\runner\Release\*"`
   - Certifique-se que o caminho está correto

2. **Incluir todos os arquivos:**
   ```ini
   Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
   ```

3. **Verificar estrutura:**
   ```bash
   # Verifique se todos os arquivos estão em Release
   dir build\windows\x64\runner\Release\
   ```

---

### 7. "Aviso: 'Programa desconhecido' ao instalar"

**Problema:**
- Windows mostra aviso de segurança

**Soluções:**

1. **Assinatura digital** (melhor solução):
   - Obtenha certificado de código
   - Assine o `.exe` com `signtool.exe`
   - Distribua versão assinada

2. **Aumentar reputação:**
   - Mais downloads = menos avisos
   - Tempo (Windows aprende que é seguro)
   - Publicar no Microsoft Store

3. **Ignorar aviso** (usuário):
   - Clique "Mais informações"
   - Clique "Executar mesmo assim"

---

### 8. "Erro ao desinstalar"

**Problema:**
- Desinstalação falha ou deixa arquivos

**Soluções:**

1. **Verificar seção Uninstall em `setup.iss`:**
   ```ini
   [UninstallDelete]
   Type: dirifempty; Name: "{app}"
   ```

2. **Remover manualmente:**
   - Abra `C:\Program Files\Gestor de Projetos`
   - Delete pasta manualmente
   - Limpe registro: `HKEY_CURRENT_USER\Software\Gestor de Projetos`

3. **Usar ferramenta de limpeza:**
   - CCleaner
   - Revo Uninstaller

---

### 9. "Erro: 'Cannot find a match for the specified search criteria'"

**Problema:**
- Arquivo de licença não encontrado

**Solução:**

1. **Se não quer licença:**
   - Remova linha em `setup.iss`:
   ```ini
   ; LicenseFile=LICENSE.txt
   ```

2. **Se quer licença:**
   - Crie arquivo `LICENSE.txt` na raiz
   - Descomente linha em `setup.iss`

---

### 10. "PowerShell: Não é possível carregar o arquivo"

**Erro:**
```
Não é possível carregar o arquivo ... porque a execução de scripts está desabilitada
```

**Solução:**

```powershell
# Abra PowerShell como Admin e execute:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Depois execute o script:
.\scripts\build_installer.ps1
```

---

## 🔍 Verificação de Saúde

Execute este checklist antes de publicar:

```bash
# 1. Verificar Flutter
flutter doctor

# 2. Verificar dependências
flutter pub get

# 3. Analisar código
flutter analyze

# 4. Executar testes
flutter test

# 5. Build Release
flutter build windows --release

# 6. Verificar executável
dir build\windows\x64\runner\Release\gestor_projetos_flutter.exe

# 7. Testar executável
.\build\windows\x64\runner\Release\gestor_projetos_flutter.exe
```

---

## 📞 Recursos Adicionais

- **Flutter Docs:** https://flutter.dev/docs/deployment/windows
- **Inno Setup Docs:** https://jrsoftware.org/ishelp/
- **NSIS Docs:** https://nsis.sourceforge.io/Docs/
- **Stack Overflow:** Tag `flutter-windows`

---

## 💡 Dicas de Debug

1. **Ativar modo verbose:**
   ```bash
   flutter build windows --release -v
   ```

2. **Verificar logs do Windows:**
   - Abra Event Viewer
   - Windows Logs → Application
   - Procure por erros

3. **Usar debugger:**
   ```bash
   flutter run -d windows
   ```

4. **Criar issue no GitHub:**
   - Descreva o problema
   - Inclua saída de `flutter doctor -v`
   - Inclua logs completos

---

**Não encontrou sua solução? Crie uma issue no GitHub! 🆘**

