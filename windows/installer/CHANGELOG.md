# 📝 Changelog do Instalador - My Business

Todas as mudanças notáveis no instalador serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2025-01-31

### ✨ Adicionado

#### Sistema de Verificação de Requisitos
- Verificação de versão do Windows (mínimo: Windows 10 Build 17763)
- Verificação de arquitetura 64-bit obrigatória
- Verificação de espaço em disco (mínimo: 500 MB)
- Mensagens de erro detalhadas e informativas

#### Sistema de Backup
- Backup automático opcional antes de atualizar
- Backup com timestamp único (formato: YYYYMMDDHHNNSS)
- Preservação de dados do usuário durante atualizações
- Opção de escolha do usuário (Sim/Não)

#### Detecção Inteligente de Processos
- Verificação se o aplicativo está em execução
- Fechamento gracioso antes de forçar término
- Múltiplas tentativas de fechamento (até 3)
- Feedback claro ao usuário durante o processo

#### Interface Moderna
- Wizard moderno e responsivo
- Tamanho aumentado (120% do padrão)
- Suporte a português e inglês
- Ícones e visual profissional

#### Associação de Arquivos
- Opção para associar arquivos .mybusiness
- Abertura automática com o aplicativo
- Ícone personalizado no Windows Explorer
- Registro no Windows para associação

#### Sistema de Logs
- Logs detalhados de instalação
- Geração automática de hash SHA256
- Informações de versão no registro do Windows
- Histórico de instalações

#### Documentação
- README.md completo no diretório do instalador
- Guia de atualização detalhado
- Script de teste automatizado
- Exemplos de uso e personalização

### 🔧 Melhorado

#### Script de Build
- Banner visual profissional
- Verificação automática de requisitos
- Detecção inteligente de ferramentas (Inno Setup/NSIS)
- Cálculo de tempo de build
- Resumo detalhado ao final
- Opção de abrir pasta de saída
- Tratamento robusto de erros
- Suporte a múltiplos parâmetros:
  - `-Version`: Especificar versão
  - `-InstallerType`: Escolher tipo (inno/nsis)
  - `-SkipBuild`: Pular compilação
  - `-Clean`: Limpeza completa
  - `-Verbose`: Modo detalhado

#### Processo de Instalação
- Melhor detecção de instalação anterior
- Preservação de dados do usuário
- Fechamento automático do aplicativo
- Criação de atalhos otimizada
- Registro no Windows aprimorado

#### Processo de Desinstalação
- Limpeza completa de arquivos
- Remoção de entradas do registro
- Opção de manter dados do usuário
- Remoção de atalhos e associações

### 🐛 Corrigido

- Tratamento de erros durante fechamento do aplicativo
- Preservação de dados em atualizações
- Limpeza completa na desinstalação
- Detecção de versão anterior mais confiável
- Mensagens de erro mais claras

### 🔐 Segurança

- Geração automática de hash SHA256
- Suporte a assinatura digital (opcional)
- Verificação de integridade do instalador
- Logs de instalação para auditoria

### 📚 Documentação

- README.md completo
- Guia de atualização
- Script de teste automatizado
- Exemplos de personalização
- Solução de problemas comuns

---

## [0.9.0] - 2025-01-15 (Versão Anterior)

### Funcionalidades Básicas

- Instalação básica do aplicativo
- Criação de atalhos
- Desinstalação simples
- Script de build básico
- Suporte a Inno Setup e NSIS

### Limitações

- Sem verificação de requisitos
- Sem backup de dados
- Detecção de processo limitada
- Interface padrão
- Sem logs detalhados
- Documentação mínima

---

## Tipos de Mudanças

- `✨ Adicionado` - Novas funcionalidades
- `🔧 Melhorado` - Melhorias em funcionalidades existentes
- `🐛 Corrigido` - Correções de bugs
- `🔐 Segurança` - Melhorias de segurança
- `📚 Documentação` - Mudanças na documentação
- `⚠️ Descontinuado` - Funcionalidades que serão removidas
- `🗑️ Removido` - Funcionalidades removidas

---

## Roadmap Futuro

### [1.1.0] - Planejado

#### Funcionalidades Planejadas

- [ ] Auto-update automático
- [ ] Instalação silenciosa (modo /SILENT)
- [ ] Instalação portátil (sem instalação)
- [ ] Suporte a múltiplos idiomas
- [ ] Temas personalizáveis
- [ ] Instalação de componentes opcionais
- [ ] Verificação de dependências (Visual C++ Runtime)
- [ ] Rollback automático em caso de falha
- [ ] Telemetria de instalação (opcional)
- [ ] Instalação em rede

#### Melhorias Planejadas

- [ ] Compressão LZMA2 ultra
- [ ] Instalador menor (otimização)
- [ ] Instalação mais rápida
- [ ] Melhor detecção de antivírus
- [ ] Suporte a proxy
- [ ] Instalação offline completa

### [1.2.0] - Futuro

#### Funcionalidades Avançadas

- [ ] Instalador MSI (Windows Installer)
- [ ] Instalador MSIX (Microsoft Store)
- [ ] Suporte a Windows ARM64
- [ ] Instalação em contêiner
- [ ] Suporte a GPO (Group Policy)
- [ ] Instalação via SCCM
- [ ] Suporte a Chocolatey
- [ ] Suporte a WinGet

---

## Notas de Migração

### De 0.9.0 para 1.0.0

#### Mudanças Importantes

1. **Requisitos Mínimos Alterados**
   - Antes: Windows 10 (qualquer versão)
   - Agora: Windows 10 Build 17763 ou superior

2. **Novo Sistema de Backup**
   - Backups são criados em: `%LOCALAPPDATA%\My Business.backup.YYYYMMDDHHNNSS`
   - Recomendado aceitar backup durante atualização

3. **Associação de Arquivos**
   - Nova opção durante instalação
   - Arquivos .mybusiness podem ser abertos diretamente

4. **Script de Build Atualizado**
   - Novos parâmetros disponíveis
   - Verificação automática de requisitos
   - Geração de hash SHA256

#### Ações Recomendadas

1. Testar instalador em ambiente de teste
2. Verificar compatibilidade com Windows 10 Build 17763+
3. Atualizar documentação interna
4. Informar usuários sobre novo sistema de backup
5. Testar processo de atualização

---

## Suporte

Para reportar problemas ou sugerir melhorias:

- **Issues**: https://github.com/DouglasCostabr2/gestor_projetos_flutter/issues
- **Email**: conta.douglascosta@gmail.com
- **Documentação**: Veja README.md neste diretório

---

## Licença

Copyright (C) 2025 Douglas Costa

Veja LICENSE.txt para mais detalhes.

