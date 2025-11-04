# ✅ Checklist Interativo - Publicação Windows

## 📋 Fase 1: Preparação (Dia 1)

### Configuração Inicial
- [ ] Li o arquivo PUBLICACAO_RAPIDA.md
- [ ] Instalei Inno Setup (https://jrsoftware.org/isdl.php)
- [ ] Verifiquei que Flutter está instalado (`flutter --version`)
- [ ] Verifiquei que tenho espaço em disco (mínimo 5GB)

### Atualização de Versão
- [ ] Abri `pubspec.yaml`
- [ ] Atualizei versão para `1.0.0+1` (ou versão desejada)
- [ ] Salvei o arquivo

### Informações do Programa
- [ ] Abri `windows/runner/Runner.rc`
- [ ] Atualizei `CompanyName` com meu nome/empresa
- [ ] Atualizei `FileDescription` com descrição clara
- [ ] Atualizei `LegalCopyright` com informações corretas
- [ ] Salvei o arquivo

### Ícone Personalizado (Opcional)
- [ ] Criei ícone 256x256 em formato `.ico`
- [ ] Coloquei em `windows/runner/resources/app_icon.ico`
- [ ] Verifiquei que o arquivo foi substituído

### Arquivo de Licença (Opcional)
- [ ] Criei arquivo `LICENSE.txt` na raiz do projeto
- [ ] Adicionei texto de licença
- [ ] Salvei o arquivo

---

## 🔨 Fase 2: Build Release (Dia 2)

### Limpeza e Preparação
- [ ] Abri PowerShell na pasta do projeto
- [ ] Executei `flutter clean`
- [ ] Executei `flutter pub get`
- [ ] Aguardei conclusão

### Compilação Release
- [ ] Executei `flutter build windows --release`
- [ ] Aguardei conclusão (5-10 minutos)
- [ ] Verifiquei que não houve erros

### Verificação do Executável
- [ ] Naveguei para `build\windows\x64\runner\Release\`
- [ ] Verifiquei que `gestor_projetos_flutter.exe` existe
- [ ] Verifiquei tamanho do arquivo (~150-200 MB)
- [ ] Testei executável clicando duas vezes
- [ ] Verifiquei que programa inicia corretamente
- [ ] Fechei o programa

---

## 📦 Fase 3: Criar Instalador (Dia 3)

### Opção A: Automático (Recomendado)
- [ ] Abri PowerShell na pasta do projeto
- [ ] Executei: `.\scripts\build_installer.ps1 -Version "1.0.0" -InstallerType "inno"`
- [ ] Aguardei conclusão
- [ ] Verifiquei que não houve erros
- [ ] Verifiquei que arquivo foi criado em `windows/installer/output/`

### Opção B: Manual com Inno Setup
- [ ] Abri Inno Setup Compiler
- [ ] Cliquei File → Open
- [ ] Selecionei `windows/installer/setup.iss`
- [ ] Cliquei Compile
- [ ] Aguardei conclusão
- [ ] Verifiquei que arquivo foi criado em `windows/installer/output/`

### Verificação do Instalador
- [ ] Verifiquei que `GestorProjetos-1.0.0-Setup.exe` foi criado
- [ ] Verifiquei tamanho do arquivo (~80-120 MB)
- [ ] Copiei arquivo para local seguro (backup)

---

## 🧪 Fase 4: Testes (Dia 4)

### Teste em PC Diferente (Recomendado)
- [ ] Copiei `GestorProjetos-1.0.0-Setup.exe` para outro PC
- [ ] Executei o instalador
- [ ] Cliquei "Next" em todas as telas
- [ ] Verifiquei que instalação foi bem-sucedida
- [ ] Verifiquei que atalhos foram criados (Desktop, Menu Iniciar)
- [ ] Cliquei no atalho para iniciar programa
- [ ] Testei funcionalidades principais
- [ ] Verifiquei que programa funciona corretamente
- [ ] Desinstalei o programa
- [ ] Verifiquei que desinstalação foi limpa

### Teste em VM (Alternativa)
- [ ] Criei máquina virtual com Windows 10/11
- [ ] Copiei instalador para VM
- [ ] Executei testes acima

### Teste em PC Atual
- [ ] Executei instalador no PC atual
- [ ] Testei funcionalidades
- [ ] Desinstalei

---

## 📤 Fase 5: Distribuição (Dia 5)

### Escolher Canal de Distribuição
- [ ] Decidi entre: GitHub Releases, Meu Site, Microsoft Store
- [ ] Escolhi: **_________________** (preencha)

### Opção 1: GitHub Releases
- [ ] Acessei https://github.com/seu-usuario/seu-repo
- [ ] Cliquei em "Releases"
- [ ] Cliquei em "Create a new release"
- [ ] Preenchi "Tag version": `v1.0.0`
- [ ] Preenchi "Release title": `Gestor de Projetos v1.0.0`
- [ ] Preenchi "Description" com notas de release
- [ ] Fiz upload de `GestorProjetos-1.0.0-Setup.exe`
- [ ] Cliquei "Publish release"
- [ ] Copiei link de download
- [ ] Testei link em navegador

### Opção 2: Seu Site
- [ ] Criei pasta `/downloads` no servidor
- [ ] Fiz upload de `GestorProjetos-1.0.0-Setup.exe`
- [ ] Criei página HTML com link de download
- [ ] Testei link em navegador
- [ ] Verifiquei que download funciona

### Opção 3: Microsoft Store
- [ ] Criei conta Microsoft Developer
- [ ] Paguei taxa de desenvolvedor ($19)
- [ ] Preparei pacote MSIX
- [ ] Enviei para aprovação
- [ ] Aguardei revisão (1-3 dias)

---

## 📢 Fase 6: Divulgação (Dia 6)

### Redes Sociais
- [ ] Postei no LinkedIn (profissional)
- [ ] Postei no Twitter (atualizações)
- [ ] Postei no Facebook (geral)
- [ ] Postei no WhatsApp (contatos)

### Email
- [ ] Enviei email para contatos
- [ ] Incluí link de download
- [ ] Incluí descrição do programa

### Fóruns e Comunidades
- [ ] Postei em fóruns relevantes
- [ ] Postei em grupos do Facebook
- [ ] Postei em comunidades do Reddit

### Seu Site
- [ ] Criei página de download
- [ ] Adicionei screenshots
- [ ] Adicionei descrição
- [ ] Adicionei link para download

---

## 📊 Fase 7: Monitoramento (Contínuo)

### Métricas
- [ ] Monitoro downloads por dia
- [ ] Monitoro feedback dos usuários
- [ ] Monitoro bugs reportados
- [ ] Monitoro avaliações/reviews

### Suporte
- [ ] Respondo emails de suporte
- [ ] Corrijo bugs reportados
- [ ] Publico atualizações
- [ ] Mantenho changelog atualizado

### Melhorias
- [ ] Coleto feedback
- [ ] Planejei versão 1.0.1
- [ ] Planejei versão 1.1.0
- [ ] Considero monetização

---

## 🎯 Próximas Versões

### Versão 1.0.1 (Correções)
- [ ] Corrigi bugs reportados
- [ ] Atualizei versão em `pubspec.yaml`
- [ ] Recompilei Release
- [ ] Gerei novo instalador
- [ ] Publiquei nova versão

### Versão 1.1.0 (Novos Recursos)
- [ ] Implementei novos recursos
- [ ] Testei completamente
- [ ] Atualizei versão
- [ ] Publiquei nova versão

### Versão 2.0.0 (Mudanças Maiores)
- [ ] Planejei mudanças maiores
- [ ] Implementei
- [ ] Testei
- [ ] Publiquei

---

## 💡 Dicas Finais

### Antes de Publicar
- ✅ Sempre teste em outro PC
- ✅ Sempre faça backup do instalador
- ✅ Sempre verifique versão
- ✅ Sempre leia os logs

### Após Publicar
- ✅ Monitore downloads
- ✅ Responda feedback
- ✅ Corrija bugs rapidamente
- ✅ Mantenha atualizado

---

## 📞 Precisa de Ajuda?

Se encontrar problemas:

1. Leia: **TROUBLESHOOTING_PUBLICACAO.md**
2. Procure: **GUIA_PUBLICACAO_WINDOWS.md**
3. Crie issue: GitHub Issues
4. Pesquise: Stack Overflow

---

## 🎉 Parabéns!

Você completou o checklist! Seu programa está pronto para ser publicado!

**Próximo passo: Comece pela Fase 1! 🚀**

---

**Data de início: ___/___/______**
**Data de conclusão: ___/___/______**
**Versão publicada: 1.0.0**
**Canal de distribuição: _________________**
**Link de download: _________________**

