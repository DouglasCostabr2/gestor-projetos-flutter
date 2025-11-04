# 🚀 Guia de Atualização do Instalador - My Business

## ✨ O Que Foi Atualizado

O instalador do My Business foi completamente modernizado com as seguintes melhorias:

### 🎯 Novas Funcionalidades

#### 1. **Verificação Avançada de Requisitos**
- ✅ Valida Windows 10 Build 17763 ou superior
- ✅ Verifica sistema 64-bit
- ✅ Confirma espaço em disco (mínimo 500 MB)
- ✅ Mensagens de erro detalhadas

#### 2. **Sistema de Backup Automático**
- ✅ Backup opcional antes de atualizar
- ✅ Preservação de dados do usuário
- ✅ Backup com timestamp único
- ✅ Localização: `%LOCALAPPDATA%\My Business.backup.YYYYMMDDHHMMSS`

#### 3. **Detecção Inteligente de Processos**
- ✅ Detecta se o aplicativo está em execução
- ✅ Fecha graciosamente antes de forçar
- ✅ Múltiplas tentativas de fechamento
- ✅ Feedback claro ao usuário

#### 4. **Interface Melhorada**
- ✅ Wizard moderno e responsivo
- ✅ Tamanho aumentado (120% do padrão)
- ✅ Mensagens em português e inglês
- ✅ Ícones e visual profissional

#### 5. **Associação de Arquivos**
- ✅ Opção para associar arquivos .mybusiness
- ✅ Abertura automática com o aplicativo
- ✅ Ícone personalizado no Windows Explorer

#### 6. **Logs e Rastreabilidade**
- ✅ Logs detalhados de instalação
- ✅ Hash SHA256 do instalador
- ✅ Informações de versão no registro
- ✅ Histórico de instalações

### 🔧 Script de Build Aprimorado

#### Novas Opções

```powershell
# Limpeza completa antes de compilar
.\scripts\build_installer.ps1 -Clean

# Pular compilação (usar build existente)
.\scripts\build_installer.ps1 -SkipBuild

# Modo verbose (detalhes completos)
.\scripts\build_installer.ps1 -Verbose

# Especificar versão
.\scripts\build_installer.ps1 -Version "1.0.1"

# Escolher tipo de instalador
.\scripts\build_installer.ps1 -InstallerType "nsis"
```

#### Melhorias no Script

- ✅ Banner visual profissional
- ✅ Verificação automática de requisitos
- ✅ Detecção inteligente de ferramentas
- ✅ Cálculo de tempo de build
- ✅ Geração automática de hash SHA256
- ✅ Resumo detalhado ao final
- ✅ Opção de abrir pasta de saída
- ✅ Tratamento robusto de erros

## 📋 Como Usar as Novas Funcionalidades

### 1. Criar Instalador com Limpeza Completa

```powershell
# Recomendado para releases oficiais
.\scripts\build_installer.ps1 -Clean -Verbose
```

**O que faz:**
- Remove builds anteriores
- Executa `flutter clean`
- Atualiza dependências
- Compila do zero
- Mostra progresso detalhado

### 2. Atualização Rápida (Desenvolvimento)

```powershell
# Para testes rápidos
.\scripts\build_installer.ps1 -SkipBuild
```

**O que faz:**
- Usa o build existente
- Apenas recria o instalador
- Economiza tempo de compilação

### 3. Release de Nova Versão

```powershell
# Processo completo para release
.\scripts\build_installer.ps1 -Version "1.0.1" -Clean -Verbose
```

**O que faz:**
- Define nova versão
- Limpeza completa
- Compilação do zero
- Gera instalador
- Cria hash SHA256
- Mostra resumo completo

## 🎨 Personalização do Instalador

### Alterar Informações do Aplicativo

Edite `windows/installer/setup.iss`:

```pascal
#define MyAppName "Seu Aplicativo"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Seu Nome"
#define MyAppURL "https://seu-site.com"
```

### Alterar Requisitos Mínimos

Edite `windows/installer/setup.iss` (linha 44):

```pascal
MinVersion=10.0.17763  ; Windows 10 1809
```

### Alterar Espaço em Disco Mínimo

Edite `windows/installer/setup.iss` na função `CheckDiskSpace()`:

```pascal
RequiredSpace := 500 * 1024 * 1024; // 500 MB
```

### Personalizar Mensagens

Todas as mensagens estão em português no arquivo `setup.iss`.
Procure por `MsgBox` para encontrar e editar.

## 🧪 Testando o Instalador Atualizado

### Teste 1: Instalação Limpa

```powershell
# 1. Criar instalador
.\scripts\build_installer.ps1 -Clean

# 2. Executar em máquina limpa ou VM
.\windows\installer\output\MyBusiness-1.0.0-Setup.exe

# 3. Verificar:
# - Instalação completa
# - Aplicativo inicia
# - Atalhos criados
# - Funcionalidades operacionais
```

### Teste 2: Atualização

```powershell
# 1. Instalar versão anterior
# 2. Usar o aplicativo e criar dados
# 3. Criar nova versão
.\scripts\build_installer.ps1 -Version "1.0.1" -Clean

# 4. Executar instalador
# 5. Verificar:
# - Detecção de versão anterior
# - Opção de backup oferecida
# - Dados preservados
# - Nova versão funcional
```

### Teste 3: Verificação de Requisitos

```powershell
# Testar em diferentes ambientes:
# - Windows 10 (várias builds)
# - Windows 11
# - Sistema com pouco espaço em disco
# - Sistema 32-bit (deve falhar com mensagem clara)
```

## 📊 Comparação: Antes vs Depois

| Funcionalidade | Antes | Depois |
|----------------|-------|--------|
| Verificação de Windows | ❌ Básica | ✅ Avançada (Build específico) |
| Backup de dados | ❌ Não | ✅ Sim (opcional) |
| Detecção de processo | ⚠️ Simples | ✅ Inteligente (múltiplas tentativas) |
| Logs | ⚠️ Básicos | ✅ Detalhados |
| Hash SHA256 | ❌ Não | ✅ Sim (automático) |
| Associação de arquivos | ❌ Não | ✅ Sim (opcional) |
| Interface | ⚠️ Padrão | ✅ Moderna (120%) |
| Script de build | ⚠️ Básico | ✅ Profissional |
| Tratamento de erros | ⚠️ Limitado | ✅ Robusto |
| Documentação | ⚠️ Mínima | ✅ Completa |

## 🔍 Verificação de Qualidade

### Checklist Pré-Release

- [ ] Compilação limpa sem erros
- [ ] Instalador criado com sucesso
- [ ] Hash SHA256 gerado
- [ ] Testado em Windows 10
- [ ] Testado em Windows 11
- [ ] Instalação limpa funciona
- [ ] Atualização preserva dados
- [ ] Desinstalação limpa
- [ ] Atalhos funcionam
- [ ] Aplicativo inicia sem erros
- [ ] Todas as funcionalidades operacionais
- [ ] Logs de instalação gerados
- [ ] Documentação atualizada

### Verificação de Arquivos

```powershell
# Verificar estrutura
Get-ChildItem -Path "windows\installer\output" -Recurse

# Verificar hash
Get-FileHash -Path "windows\installer\output\MyBusiness-1.0.0-Setup.exe" -Algorithm SHA256

# Verificar tamanho
Get-Item "windows\installer\output\MyBusiness-1.0.0-Setup.exe" | Select-Object Length
```

## 🚀 Processo de Release Recomendado

### 1. Preparação

```powershell
# Atualizar versão no pubspec.yaml
# version: 1.0.1+2

# Atualizar CHANGELOG.md
# Documentar mudanças
```

### 2. Build e Teste

```powershell
# Build completo
.\scripts\build_installer.ps1 -Version "1.0.1" -Clean -Verbose

# Testar instalador
# - Instalação limpa
# - Atualização
# - Funcionalidades
```

### 3. Verificação

```powershell
# Verificar hash
Get-Content "windows\installer\output\MyBusiness-1.0.1-Setup.exe.sha256"

# Verificar tamanho
Get-Item "windows\installer\output\MyBusiness-1.0.1-Setup.exe"
```

### 4. Publicação

```powershell
# Criar tag no Git
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1

# Criar release no GitHub
# Upload do instalador
# Upload do hash SHA256
# Adicionar notas de release
```

## 📝 Notas de Versão

### Versão 1.0.0 (Atualização do Instalador)

**Melhorias:**
- ✅ Sistema de verificação de requisitos avançado
- ✅ Backup automático de dados do usuário
- ✅ Detecção inteligente de processos em execução
- ✅ Interface moderna e responsiva
- ✅ Associação de arquivos .mybusiness
- ✅ Logs detalhados de instalação
- ✅ Geração automática de hash SHA256
- ✅ Script de build profissional
- ✅ Documentação completa

**Correções:**
- ✅ Melhor tratamento de erros
- ✅ Fechamento gracioso do aplicativo
- ✅ Preservação de dados em atualizações
- ✅ Limpeza completa na desinstalação

## 🆘 Suporte

### Problemas Comuns

**1. Script não executa**
```powershell
# Habilitar execução de scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**2. Inno Setup não encontrado**
```powershell
# Usar NSIS como alternativa
.\scripts\build_installer.ps1 -InstallerType "nsis"
```

**3. Build falha**
```powershell
# Limpar e tentar novamente
flutter clean
flutter pub get
.\scripts\build_installer.ps1 -Clean
```

### Onde Obter Ajuda

- 📖 Documentação: `windows/installer/README.md`
- 🐛 Issues: https://github.com/DouglasCostabr2/gestor_projetos_flutter/issues
- 📧 Email: conta.douglascosta@gmail.com

## 📚 Recursos Adicionais

- [Inno Setup Documentation](https://jrsoftware.org/ishelp/)
- [Flutter Windows Desktop](https://docs.flutter.dev/platform-integration/windows/building)
- [Windows Installer Best Practices](https://docs.microsoft.com/en-us/windows/win32/msi/windows-installer-best-practices)

## ✅ Conclusão

O instalador foi completamente modernizado e está pronto para produção!

**Próximos passos:**
1. Testar o instalador em diferentes ambientes
2. Criar release no GitHub
3. Distribuir para os usuários
4. Coletar feedback
5. Iterar e melhorar

---

**Desenvolvido com ❤️ por Douglas Costa**

