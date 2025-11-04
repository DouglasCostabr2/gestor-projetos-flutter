# 🚀 Atualização do Instalador Windows - Versão 1.1.0

## 📋 Resumo das Alterações

O instalador do Windows foi completamente atualizado para a versão **1.1.0** com melhorias significativas na experiência do usuário, mensagens mais claras e novas funcionalidades.

---

## ✨ Novidades da Versão 1.1.0

### 🎯 Novas Funcionalidades

1. **Inicialização Automática**
   - Nova opção para iniciar o My Business automaticamente com o Windows
   - Configurável durante a instalação
   - Ideal para usuários que usam o sistema diariamente

2. **Mensagens Aprimoradas**
   - Todas as mensagens agora em português claro e objetivo
   - Ícones visuais (✅, ⚠️, 💾, 🔄, ❌) para melhor identificação
   - Mensagens mais informativas e amigáveis

3. **Melhor Detecção de Atualizações**
   - Sistema aprimorado de detecção de versão anterior
   - Mensagens claras sobre o processo de atualização
   - Confirmação antes de prosseguir com a atualização

4. **Backup Automático de Dados**
   - Oferece backup automático dos dados do usuário antes de atualizar
   - Mensagens claras sobre localização do backup
   - Confirmação de sucesso do backup

### 🔧 Melhorias Técnicas

1. **Informações de Versão Completas**
   - VersionInfoVersion agora inclui build number
   - VersionInfoTextVersion adicionado
   - Melhor rastreamento de versões

2. **Atalhos Aprimorados**
   - Todos os atalhos agora incluem descrições (tooltips)
   - Atalho de desinstalação renomeado para português
   - Suporte a inicialização automática

3. **Verificações de Sistema**
   - Mensagens de erro mais claras para requisitos não atendidos
   - Melhor feedback sobre incompatibilidades
   - Orientações claras sobre como resolver problemas

---

## 📦 Arquivos Atualizados

### 1. `windows/installer/setup.iss`
**Principais alterações:**
- Versão atualizada de 1.0.0 para 1.1.0
- Adicionada constante `MyAppDescription`
- Novas tarefas de instalação (inicialização automática)
- Mensagens completamente reformuladas em português
- Ícones visuais em todas as mensagens
- Melhor tratamento de erros

### 2. `pubspec.yaml`
**Alteração:**
- Versão atualizada de `1.0.0+1` para `1.1.0+2`

### 3. `scripts/build_installer.ps1`
**Alteração:**
- Versão padrão atualizada de "1.0.0" para "1.1.0"

---

## 🎨 Melhorias na Interface

### Mensagens Antes vs Depois

#### ❌ Antes:
```
Este aplicativo requer Windows 10 versão 1809 ou superior.
```

#### ✅ Depois:
```
⚠️ REQUISITO NÃO ATENDIDO

Este aplicativo requer Windows 10 versão 1809 (Build 17763) ou superior.

Versão detectada: 10.0 (Build 19045)

Por favor, atualize seu Windows antes de instalar o My Business.
```

### Novas Opções de Instalação

1. **Criar atalho na Área de Trabalho** (opcional)
2. **Criar atalho na Barra de Inicialização Rápida** (opcional, Windows 7)
3. **Associar arquivos .mybusiness** (opcional)
4. **Iniciar automaticamente com o Windows** (opcional, NOVO!)

---

## 🔄 Processo de Atualização

### Para Usuários com Versão Anterior

Quando um usuário com versão anterior executar o instalador:

1. **Detecção Automática**
   ```
   🔄 ATUALIZAÇÃO DISPONÍVEL
   
   My Business versão 1.0.0 já está instalado.
   
   A instalação irá atualizar para a versão 1.1.0.
   
   ✅ Seus dados serão preservados.
   
   Deseja continuar com a atualização?
   ```

2. **Oferta de Backup**
   ```
   💾 BACKUP DE DADOS
   
   Deseja fazer backup dos seus dados antes de atualizar?
   
   Origem: C:\Users\...\AppData\Local\My Business
   Backup: C:\Users\...\AppData\Local\My Business.backup.20250104120000
   
   ✅ Recomendado: Sim
   ```

3. **Confirmação de Sucesso**
   ```
   ✅ ATUALIZAÇÃO CONCLUÍDA!
   
   My Business foi atualizado com sucesso!
   
   Versão anterior: 1.0.0
   Versão atual: 1.1.0
   
   💾 Seus dados foram preservados em:
   C:\Users\...\AppData\Local\My Business
   ```

---

## 🛠️ Como Gerar o Instalador Atualizado

### Método Rápido (Recomendado)

```powershell
# Na raiz do projeto
.\scripts\build_installer.ps1
```

O script agora usa automaticamente a versão 1.1.0.

### Método com Opções

```powershell
# Build completo com limpeza
.\scripts\build_installer.ps1 -Clean -Verbose

# Apenas recriar instalador (sem recompilar)
.\scripts\build_installer.ps1 -SkipBuild

# Especificar versão customizada
.\scripts\build_installer.ps1 -Version "1.1.1"
```

### Método Manual

```powershell
# 1. Compilar o Flutter
flutter clean
flutter build windows --release

# 2. Gerar instalador
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\setup.iss
```

---

## 📊 Comparação de Versões

| Recurso | v1.0.0 | v1.1.0 |
|---------|--------|--------|
| Mensagens em português | Parcial | ✅ Completo |
| Ícones visuais | ❌ | ✅ |
| Inicialização automática | ❌ | ✅ |
| Backup automático | ✅ | ✅ Melhorado |
| Detecção de atualização | ✅ | ✅ Melhorado |
| Tooltips nos atalhos | ❌ | ✅ |
| Mensagens de erro claras | Básico | ✅ Detalhado |

---

## 🎯 Próximos Passos

### Para Desenvolvedores

1. **Testar o Instalador**
   ```powershell
   .\scripts\test_installer.ps1
   ```

2. **Verificar Integridade**
   - O hash SHA256 é gerado automaticamente
   - Arquivo: `windows\installer\output\MyBusiness-1.1.0-Setup.exe.sha256`

3. **Criar Release no GitHub**
   - Fazer upload do instalador
   - Incluir o arquivo SHA256
   - Adicionar notas de versão

### Para Usuários

1. **Download**
   - Baixar o instalador da página de releases
   - Verificar o hash SHA256 (opcional, mas recomendado)

2. **Instalação**
   - Executar o instalador
   - Seguir as instruções na tela
   - Escolher opções desejadas

3. **Atualização**
   - Executar o novo instalador
   - Aceitar a atualização quando solicitado
   - Opcionalmente fazer backup dos dados

---

## 📝 Notas Técnicas

### Requisitos do Sistema

- **Sistema Operacional:** Windows 10 versão 1809 (Build 17763) ou superior
- **Arquitetura:** 64-bit obrigatório
- **Espaço em Disco:** Mínimo 500 MB
- **Privilégios:** Não requer administrador (instalação por usuário)

### Localização dos Arquivos

- **Instalação:** `C:\Program Files\My Business\`
- **Dados do Usuário:** `%LOCALAPPDATA%\My Business\`
- **Logs:** `%LOCALAPPDATA%\My Business\logs\`
- **Backups:** `%LOCALAPPDATA%\My Business.backup.TIMESTAMP\`

### Registro do Windows

O instalador cria as seguintes entradas no registro:

- `HKCU\Software\My Business\InstallPath` - Caminho de instalação
- `HKCU\Software\My Business\Version` - Versão instalada
- `HKCU\Software\Classes\.mybusiness` - Associação de arquivos (opcional)

---

## 🆘 Solução de Problemas

### Instalador não inicia

**Problema:** Duplo clique no instalador não faz nada

**Solução:**
1. Verificar se o arquivo foi baixado completamente
2. Verificar hash SHA256
3. Executar como administrador (botão direito → "Executar como administrador")

### Erro de versão do Windows

**Problema:** Mensagem de versão incompatível

**Solução:**
1. Verificar versão do Windows: `winver`
2. Atualizar Windows se necessário
3. Mínimo: Windows 10 1809 (Build 17763)

### Aplicativo não fecha durante atualização

**Problema:** Instalador não consegue fechar o aplicativo

**Solução:**
1. Fechar manualmente o My Business
2. Verificar no Gerenciador de Tarefas se há processos residuais
3. Reiniciar o instalador

---

## 📞 Suporte

Para problemas ou dúvidas:

- **Issues:** https://github.com/DouglasCostabr2/gestor_projetos_flutter/issues
- **Releases:** https://github.com/DouglasCostabr2/gestor_projetos_flutter/releases

---

## ✅ Checklist de Publicação

- [ ] Compilar versão Release do Flutter
- [ ] Gerar instalador com Inno Setup
- [ ] Testar instalação limpa
- [ ] Testar atualização de versão anterior
- [ ] Verificar hash SHA256
- [ ] Testar em máquina limpa (VM recomendada)
- [ ] Criar tag no Git: `v1.1.0`
- [ ] Criar release no GitHub
- [ ] Fazer upload do instalador
- [ ] Fazer upload do arquivo SHA256
- [ ] Adicionar notas de versão
- [ ] Anunciar atualização para usuários

---

**Data da Atualização:** 04/01/2025  
**Versão:** 1.1.0  
**Autor:** Douglas Costa

