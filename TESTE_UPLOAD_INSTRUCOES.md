# 📝 Instruções para Testar Upload e Capturar Logs

## O que fazer agora:

### Passo 1: Abra o App
O app já está rodando. Se não estiver visível, procure pela janela "Gestor de Projetos".

### Passo 2: Faça Login
- Use suas credenciais de admin ou gestor

### Passo 3: Abra uma Tarefa
- Clique em qualquer projeto
- Clique em qualquer tarefa

### Passo 4: Vá para Comentários
- Procure pela seção de "Comentários" ou "Comments"
- Você deve ver um campo de texto para adicionar comentários

### Passo 5: Tente Adicionar uma Imagem
- Clique no ícone de imagem (📷) no editor de comentários
- Selecione uma imagem do seu computador
- Clique em "Enviar" ou "Send"

### Passo 6: Observe o Erro
- Você deve ver uma mensagem de erro
- **Copie a mensagem de erro exata**

### Passo 7: Capture os Logs
- Volte para o terminal onde o Flutter está rodando
- Procure por mensagens que começam com:
  - `🔍` (azul)
  - `✅` (verde)
  - `❌` (vermelho)
  - `[Comments._send]`
  - `[Comments._send/BG]`
  - `GDrive OAuth:`

### Passo 8: Copie os Logs
- Selecione todos os logs relevantes
- Copie e cole aqui para que eu possa analisar

---

## O que procurar nos logs:

### Logs Esperados (Sucesso):
```
🔍 GDrive OAuth: verificando token compartilhado...
✅ GDrive OAuth: token compartilhado encontrado: SIM
🔄 GDrive OAuth: renovando token compartilhado...
✅ GDrive OAuth: token compartilhado renovado com sucesso
```

### Logs de Erro (Falha):
```
⚠️ GDrive OAuth: nenhum token compartilhado encontrado
❌ GDrive OAuth: falha ao renovar token compartilhado: [ERRO]
❌ GDrive OAuth: erro ao buscar token compartilhado: [ERRO]
```

### Logs de Background:
```
[Comments._send] scheduling background upload...
[Comments._send/BG] started
[Comments._send/BG] sharedToken.refresh=true/false
[Comments._send/BG] calling uploadCachedImages
```

---

## Próximos Passos:

1. **Faça o teste acima**
2. **Copie os logs do terminal**
3. **Cole aqui para que eu possa analisar**
4. **Eu vou identificar exatamente onde está o problema**


