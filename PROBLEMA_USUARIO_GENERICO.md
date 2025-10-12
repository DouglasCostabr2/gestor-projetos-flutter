# 🚨 PROBLEMA CRÍTICO - USUÁRIO GENÉRICO

Data: 2025-10-02

---

## ❌ **PROBLEMA IDENTIFICADO:**

> "quando abro o app o meu usuario parece corretamente no side menu, mas quando eu começo a navegar entre as paginas muda para um usuario generico"

**Isso explica o erro de RLS!**

Se o usuário muda para "genérico" durante a navegação, então:
- ❌ O usuário "genérico" NÃO é membro do projeto
- ❌ As políticas RLS bloqueiam o INSERT
- ❌ Erro: "new row violates row-level security policy"

---

## 🔍 **CAUSA PROVÁVEL:**

### Possibilidade 1: Sessão expirando
- Token de autenticação expira
- App volta para usuário anônimo/genérico
- Supabase perde a sessão

### Possibilidade 2: Navegação resetando auth
- Alguma página está fazendo logout
- Navegação está limpando o estado de autenticação
- Context/Provider perdendo o usuário

### Possibilidade 3: Múltiplas instâncias do Supabase
- Diferentes partes do app usando diferentes instâncias
- Uma instância autenticada, outra não

---

## 🎯 **DEBUGS ADICIONADOS:**

Adicionei debugs em:

### 1. TasksPage._save()
```dart
debugPrint('=== SAVE TASK DEBUG ===');
debugPrint('Current User ID: ${currentUser?.id}');
debugPrint('Current User Email: ${currentUser?.email}');
debugPrint('Project ID: $_projectId');
debugPrint('Linked Products: ${_linkedProducts.length}');
```

### 2. Ao salvar produtos vinculados
```dart
debugPrint('=== SAVING LINKED PRODUCTS ===');
debugPrint('Task ID: $taskId');
debugPrint('Products to link: ${_linkedProducts.length}');
debugPrint('Current User: ${client.auth.currentUser?.id}');
debugPrint('Current User Email: ${client.auth.currentUser?.email}');
```

---

## 📋 **COMO TESTAR:**

1. **Execute o app** (hot reload ou restart)
2. **Verifique o console** ao abrir o app
3. **Navegue entre páginas** e observe o console
4. **Tente editar uma task** e adicionar produtos
5. **Observe os debugs** no console

---

## 🔎 **O QUE PROCURAR NO CONSOLE:**

### ✅ **Comportamento Correto:**
```
=== SAVE TASK DEBUG ===
Current User ID: abc123-def456-...
Current User Email: seu@email.com
Project ID: xyz789
Linked Products: 2

=== SAVING LINKED PRODUCTS ===
Task ID: 7bb80bfb-97ff-4e46-8f09-71e4b560bbb9
Products to link: 2
Current User: abc123-def456-...
Current User Email: seu@email.com
Inserting 2 products...
Products linked successfully!
```

### ❌ **Comportamento Incorreto (Usuário Genérico):**
```
=== SAVE TASK DEBUG ===
Current User ID: null
Current User Email: null
OU
Current User ID: generic-user-id
Current User Email: generic@example.com

=== SAVING LINKED PRODUCTS ===
Current User: null
OU
Current User: generic-user-id
Falha ao salvar produtos vinculados: RLS error
```

---

## 🛠️ **POSSÍVEIS SOLUÇÕES:**

### Solução 1: Verificar persistência de sessão
Verificar se o Supabase está configurado para persistir a sessão:

```dart
// Em main.dart ou onde inicializa o Supabase
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_ANON_KEY',
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    autoRefreshToken: true,  // ← Importante!
    persistSession: true,     // ← Importante!
  ),
);
```

### Solução 2: Verificar se há logout acidental
Procurar por:
- `Supabase.instance.client.auth.signOut()`
- Navegação que limpa o estado
- Providers/Context sendo resetados

### Solução 3: Adicionar listener de auth state
```dart
Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  debugPrint('Auth State Changed: ${data.event}');
  debugPrint('User: ${data.session?.user.email}');
});
```

---

## 🎯 **PRÓXIMOS PASSOS:**

1. ⚠️ **Execute o app com os novos debugs**
2. 📝 **Copie TODA a saída do console**
3. 🔍 **Procure por mudanças no User ID**
4. 📋 **Me envie os logs**

---

## 💡 **INVESTIGAÇÃO ADICIONAL:**

Se o usuário está mudando, precisamos descobrir:

1. **Quando muda?**
   - Ao navegar para qual página?
   - Após quanto tempo?
   - Após qual ação?

2. **Para qual usuário muda?**
   - null?
   - Um ID genérico específico?
   - Um email genérico?

3. **O que acontece no side menu?**
   - O nome muda visualmente?
   - O avatar muda?
   - Algum indicador de logout?

---

## 🚀 **AÇÃO IMEDIATA:**

1. ⚠️ **Execute o app** (flutter run ou hot restart)
2. 📝 **Observe o console** desde o início
3. 🔍 **Navegue entre páginas** e veja se o User ID muda
4. 📋 **Me envie os logs completos**

---

**EXECUTE E ME ENVIE OS LOGS DO CONSOLE!** 🚀

