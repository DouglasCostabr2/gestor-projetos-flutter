# 🚀 Publicação Rápida - Gestor de Projetos Windows

## ⚡ Resumo Executivo

Você pode publicar seu programa Flutter como instalador Windows em **3 passos simples**:

1. **Instalar Inno Setup** (5 min)
2. **Compilar Release** (5-10 min)
3. **Gerar Instalador** (2 min)

**Tempo total: ~20 minutos**

---

## 📋 Checklist Pré-Publicação

- [ ] Versão do programa testada e funcionando
- [ ] Atualizou `pubspec.yaml` com versão correta
- [ ] Atualizou `windows/runner/Runner.rc` com informações corretas
- [ ] Ícone personalizado em `windows/runner/resources/app_icon.ico` (opcional)
- [ ] Arquivo `LICENSE.txt` na raiz do projeto (opcional)

---

## 🎯 Passo 1: Instalar Inno Setup

### Windows
1. Acesse: https://jrsoftware.org/isdl.php
2. Baixe "Inno Setup 6.x.x"
3. Execute o instalador
4. Escolha "Install Inno Setup"
5. Conclua a instalação

**Tempo: ~5 minutos**

---

## 🔨 Passo 2: Compilar Versão Release

### Opção A: Usando PowerShell (Automático)

```powershell
# Abra PowerShell na pasta do projeto e execute:
.\scripts\build_installer.ps1 -Version "1.0.0" -InstallerType "inno"
```

### Opção B: Manual

```bash
# Terminal na pasta do projeto
flutter clean
flutter build windows --release
```

**Tempo: ~5-10 minutos**

---

## 📦 Passo 3: Gerar Instalador

### Opção A: Automático (Recomendado)

O script `build_installer.ps1` já faz isso automaticamente!

### Opção B: Manual com Inno Setup

1. Abra **Inno Setup Compiler**
2. Clique em **File → Open**
3. Selecione `windows/installer/setup.iss`
4. Clique em **Compile**
5. Aguarde a compilação

**Resultado:** `windows/installer/output/GestorProjetos-1.0.0-Setup.exe`

**Tempo: ~2 minutos**

---

## ✅ Verificação Final

Após gerar o instalador:

1. **Teste em VM ou computador diferente**
   - Baixe o `.exe` gerado
   - Execute e instale
   - Teste todas as funcionalidades

2. **Verifique:**
   - ✅ Instalação sem erros
   - ✅ Atalhos criados corretamente
   - ✅ Desinstalação funciona
   - ✅ Programa inicia normalmente

---

## 📊 Informações do Instalador

| Item | Localização |
|------|------------|
| **Executável** | `build\windows\x64\runner\Release\gestor_projetos_flutter.exe` |
| **Script Inno** | `windows/installer/setup.iss` |
| **Script NSIS** | `windows/installer/setup.nsi` |
| **Saída** | `windows/installer/output/GestorProjetos-1.0.0-Setup.exe` |

---

## 🎨 Personalização

### Alterar Nome/Versão

Edite `windows/installer/setup.iss`:

```ini
AppName=Seu Nome
AppVersion=1.0.1
AppPublisher=Seu Nome/Empresa
```

### Alterar Ícone

1. Crie ícone 256x256 em `.ico`
2. Coloque em `windows/runner/resources/app_icon.ico`
3. Recompile com `flutter build windows --release`

### Adicionar Licença

1. Crie arquivo `LICENSE.txt` na raiz
2. Descomente a linha em `setup.iss`:
   ```ini
   LicenseFile=LICENSE.txt
   ```

---

## 🌐 Distribuição

### Opções de Hospedagem

1. **GitHub Releases** (Gratuito)
   - Crie release no GitHub
   - Faça upload do `.exe`
   - Compartilhe link

2. **Seu Site** (Profissional)
   - Hospede em seu servidor
   - Crie página de download

3. **SourceForge** (Tradicional)
   - Plataforma clássica de distribuição
   - Estatísticas de download

4. **Microsoft Store** (Avançado)
   - Requer certificado
   - Maior alcance

---

## 🔐 Assinatura Digital (Opcional)

Para evitar avisos de "Programa desconhecido":

1. Obtenha certificado de código
2. Assine o `.exe` com ferramenta como `signtool.exe`
3. Distribua o `.exe` assinado

---

## 📞 Suporte

### Problemas Comuns

**P: "Inno Setup não encontrado"**
- R: Instale Inno Setup em `C:\Program Files (x86)\Inno Setup 6\`

**P: "Erro ao compilar Flutter"**
- R: Execute `flutter clean` e tente novamente

**P: "Instalador muito grande"**
- R: Normal! Flutter Windows é ~150-200MB. Use compressão LZMA.

**P: "Programa não inicia após instalar"**
- R: Verifique se todas as dependências estão incluídas no build

---

## 📈 Próximos Passos

1. ✅ Publicar versão 1.0.0
2. 📝 Criar página de download
3. 🔄 Implementar auto-atualização
4. 📊 Monitorar downloads
5. 🐛 Coletar feedback dos usuários

---

## 💡 Dicas Profissionais

- ✅ Mantenha histórico de versões
- ✅ Use versionamento semântico (1.0.0, 1.0.1, 1.1.0, etc.)
- ✅ Crie notas de release (changelog)
- ✅ Teste em múltiplas versões do Windows
- ✅ Considere assinatura digital para confiança
- ✅ Implemente sistema de auto-atualização

---

**Pronto para publicar? Comece pelo Passo 1! 🚀**

