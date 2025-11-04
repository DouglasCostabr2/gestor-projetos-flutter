# 🚀 Configuração do GitHub para My Business

Este guia mostra como configurar o repositório GitHub para hospedar o código e as releases do My Business.

## 📋 Passo a Passo

### 1. Criar Repositório no GitHub

1. Acesse: https://github.com/new
2. Preencha os dados:
   - **Repository name**: `gestor-projetos-flutter`
   - **Description**: `My Business - Sistema de Gerenciamento de Projetos e Tarefas em Flutter para Windows`
   - **Visibility**: Public (ou Private, se preferir)
   - **NÃO** marque "Initialize this repository with a README"
3. Clique em **Create repository**

### 2. Configurar Git Local

Abra o PowerShell na pasta do projeto e execute:

```powershell
# Navegar até a pasta do projeto (se ainda não estiver)
cd C:\Users\PC\Downloads\gestor_projetos_flutter

# Inicializar repositório Git (se ainda não foi feito)
git init

# Configurar seu nome e email (se ainda não configurou)
git config user.name "DouglasCostabr2"
git config user.email "conta.douglascosta@gmail.com"

# Adicionar todos os arquivos
git add .

# Fazer commit inicial
git commit -m "feat: implementação inicial do My Business

- Sistema completo de gerenciamento de projetos e tarefas
- Integração com Supabase
- Sistema de atualização automática
- Interface moderna com tema dark
- Suporte para múltiplos usuários e roles
- Timer de tarefas
- Upload de arquivos e imagens
- Integração com Google Drive
- Sistema de comentários e menções
- Catálogo de produtos e pacotes"

# Adicionar repositório remoto
git remote add origin https://github.com/DouglasCostabr2/gestor-projetos-flutter.git

# Renomear branch para main (se necessário)
git branch -M main

# Fazer push inicial
git push -u origin main
```

### 3. Criar Primeira Release (v1.1.0)

#### Opção A: Via Interface Web (Mais Fácil)

1. Acesse: https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/new

2. Preencha os campos:
   - **Tag version**: `v1.1.0`
   - **Release title**: `v1.1.0 - Sistema de Atualização Automática`
   - **Description**:
     ```markdown
     # Versão 1.1.0

     ## 🎉 Novidades

     - ✨ **Sistema de Atualização Automática**: Agora o app verifica e instala atualizações automaticamente
     - 🔄 Verificação automática de updates na inicialização
     - 📥 Download e instalação automática de atualizações
     - 💬 Interface moderna para notificação de updates
     - ⚙️ Suporte para atualizações opcionais e obrigatórias

     ## 🚀 Melhorias

     - ⚡ Melhorias de performance geral
     - 🎨 Interface do usuário aprimorada
     - ⏱️ Sistema de timer de tarefas otimizado

     ## 🐛 Correções

     - ✅ Corrigido problema com timer de tarefas
     - 🔧 Melhorias na estabilidade do aplicativo

     ## 📦 Instalação

     1. Baixe o instalador abaixo
     2. Execute `MyBusiness-Setup-1.1.0.exe`
     3. Siga as instruções do instalador
     4. Pronto! O app está instalado e pronto para uso

     ## 🔗 Links Úteis

     - [Documentação do Sistema de Atualização](docs/SISTEMA_ATUALIZACAO.md)
     - [Guia Rápido](ATUALIZACAO_RAPIDA.md)
     ```

3. **Anexar Binários**:
   - Primeiro, compile o app: `flutter build windows --release`
   - Crie o instalador: `.\scripts\build-installer.ps1`
   - Arraste o arquivo `installer\Output\MyBusiness-Setup-1.1.0.exe` para a área de anexos

4. Clique em **Publish release**

#### Opção B: Via Linha de Comando

```powershell
# Criar tag
git tag -a v1.1.0 -m "Release v1.1.0 - Sistema de Atualização Automática"

# Fazer push da tag
git push origin v1.1.0

# Depois, vá para a interface web e crie a release a partir da tag
```

### 4. Atualizar URL no Supabase

Após criar a release e fazer upload do instalador, copie a URL do arquivo e atualize no Supabase:

1. Na página da release, clique com botão direito no arquivo `.exe`
2. Copie o link (será algo como: `https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.1.0/MyBusiness-Setup-1.1.0.exe`)

3. Execute no Supabase SQL Editor:

```sql
UPDATE app_versions
SET download_url = 'https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.1.0/MyBusiness-Setup-1.1.0.exe'
WHERE version = '1.1.0';
```

### 5. Testar Sistema de Atualização

1. Execute o app: `flutter run -d windows`
2. Aguarde 2 segundos
3. Como a versão atual é 1.1.0 e a do servidor também é 1.1.0, não deve aparecer notificação

Para testar, crie uma versão de teste:

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.1.1',
  'https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.1.0/MyBusiness-Setup-1.1.0.exe',
  '# Versão de Teste 1.1.1\n\nEsta é uma versão de teste para verificar o sistema de atualização.',
  false
);
```

Execute o app novamente e o diálogo de atualização deve aparecer!

## 📝 Comandos Git Úteis

```powershell
# Ver status
git status

# Ver histórico
git log --oneline

# Criar nova branch
git checkout -b feature/nova-funcionalidade

# Voltar para main
git checkout main

# Fazer commit
git add .
git commit -m "feat: descrição da mudança"

# Fazer push
git push

# Ver branches
git branch -a

# Ver remotes
git remote -v

# Atualizar do remoto
git pull
```

## 🏷️ Convenção de Commits

Use commits semânticos:

- `feat:` - Nova funcionalidade
- `fix:` - Correção de bug
- `docs:` - Documentação
- `style:` - Formatação, ponto e vírgula, etc
- `refactor:` - Refatoração de código
- `test:` - Testes
- `chore:` - Tarefas de build, configuração, etc

Exemplos:
```
feat: adicionar sistema de notificações
fix: corrigir erro no timer de tarefas
docs: atualizar README com instruções de instalação
refactor: reorganizar estrutura de pastas
```

## 🔄 Fluxo de Trabalho para Novas Versões

### 1. Desenvolver

```powershell
# Criar branch para feature
git checkout -b feature/nova-funcionalidade

# Fazer mudanças...
# Testar...

# Commit
git add .
git commit -m "feat: adicionar nova funcionalidade"

# Push
git push -u origin feature/nova-funcionalidade
```

### 2. Atualizar Versão

```yaml
# pubspec.yaml
version: 1.2.0+3  # Incrementar
```

### 3. Merge para Main

```powershell
git checkout main
git merge feature/nova-funcionalidade
git push
```

### 4. Criar Release

```powershell
# Compilar
flutter build windows --release

# Criar instalador
.\scripts\build-installer.ps1

# Criar tag
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# Criar release no GitHub (interface web)
# Upload do instalador
```

### 5. Registrar no Supabase

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_mandatory)
VALUES (
  '1.2.0',
  'https://github.com/DouglasCostabr2/gestor-projetos-flutter/releases/download/v1.2.0/MyBusiness-Setup-1.2.0.exe',
  '# Versão 1.2.0\n\n## Novidades\n- ...',
  false
);
```

## 🔒 Segurança

### Arquivos Sensíveis

O `.gitignore` já está configurado para ignorar:
- Certificados (`.pfx`, `.p12`, `.key`, `.pem`)
- Configurações locais do Supabase
- Builds e instaladores

### Nunca Commite:
- ❌ Senhas ou tokens
- ❌ Chaves de API
- ❌ Certificados de assinatura
- ❌ Dados de usuários

## 📚 Recursos

- [Git Documentation](https://git-scm.com/doc)
- [GitHub Docs](https://docs.github.com)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)

## ✅ Checklist de Configuração

- [ ] Repositório criado no GitHub
- [ ] Git inicializado localmente
- [ ] Commit inicial feito
- [ ] Push para GitHub realizado
- [ ] Release v1.1.0 criada
- [ ] Instalador anexado à release
- [ ] URL atualizada no Supabase
- [ ] Sistema de atualização testado

---

**Pronto!** Seu projeto está configurado no GitHub e o sistema de atualização automática está funcionando! 🎉

