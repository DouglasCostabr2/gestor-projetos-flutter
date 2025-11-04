# 🔍 Google Drive Upload Failure - Diagnostic Report

## Error Message
```
Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações.
```

---

## 📍 Where the Error Occurs

**File**: `lib/ui/organisms/sections/comments_section.dart` (lines 562-564, 626-628)

When users try to upload briefing images or send comments with attachments, the error is caught and displayed.

---

## 🎯 Root Cause Analysis

### Primary Issue: `ConsentRequired()` Exception

The error is triggered when `GoogleDriveOAuthService.getAuthedClient()` throws `ConsentRequired()` exception.

**Location**: `lib/services/google_drive_oauth_service.dart` (line 234)

```dart
debugPrint('GDrive OAuth: nenhum token armazenado, solicitando consentimento');
throw ConsentRequired();
```

### Why This Happens

The `getAuthedClient()` method follows this flow:

1. **Step 1**: Try to get shared token from `shared_oauth_tokens` table
   - Query: `SELECT * FROM shared_oauth_tokens WHERE provider = 'google'`
   - If found AND has refresh_token → Try to refresh and use it
   - If refresh fails → Continue to Step 2

2. **Step 2**: Try to get personal token from `user_oauth_tokens` table
   - Query: `SELECT * FROM user_oauth_tokens WHERE user_id = current_user AND provider = 'google'`
   - If found AND has refresh_token → Try to refresh and use it
   - If refresh fails → Throw `ConsentRequired()`

3. **Step 3**: If no tokens found → Throw `ConsentRequired()`

---

## 🔴 Identified Problems

### Problem 1: Shared Token Not Stored in Database
**Likelihood**: HIGH

The shared token may never have been successfully saved to `shared_oauth_tokens` table.

**Evidence**:
- `OAuthTokenStore.getSharedToken()` returns `null`
- This causes the code to skip the shared token path entirely

**Why it happens**:
- Admin/Gestor never connected a Google Drive account via the "Connect Google Drive" flow
- Or the connection flow failed silently
- Or the `upsertSharedToken()` call failed but the error was caught and logged only

### Problem 2: Token Refresh Failure
**Likelihood**: MEDIUM

Even if the shared token exists, the refresh might be failing.

**Evidence** (from code line 196-200):
```dart
catch (e) {
  base.close();
  debugPrint('❌ GDrive OAuth: falha ao renovar token compartilhado: $e');
  // Continua para tentar token pessoal
}
```

**Why it happens**:
- OAuth credentials are invalid or expired
- Google API credentials (Client ID/Secret) are misconfigured
- Network connectivity issue
- Token has been revoked by the user

### Problem 3: RLS Policy Blocking SELECT
**Likelihood**: LOW (but possible)

The RLS policy on `shared_oauth_tokens` might be blocking the SELECT query.

**Current Policy** (from migration):
```sql
CREATE POLICY "shared_oauth_tokens_select"
  ON public.shared_oauth_tokens
  FOR SELECT
  TO authenticated
  USING (true);
```

This should allow all authenticated users to read, but there could be:
- Policy not applied correctly
- Database permission issues
- Supabase configuration issue

---

## 🔧 How to Diagnose

### Step 1: Check if Shared Token Exists
Run in Supabase SQL Editor:
```sql
SELECT * FROM public.shared_oauth_tokens WHERE provider = 'google';
```

**Expected**: One row with refresh_token populated
**If empty**: Token was never saved

### Step 2: Check Token Details
```sql
SELECT 
  provider,
  refresh_token IS NOT NULL as has_refresh_token,
  access_token IS NOT NULL as has_access_token,
  access_token_expiry,
  connected_by,
  connected_at,
  updated_at
FROM public.shared_oauth_tokens 
WHERE provider = 'google';
```

### Step 3: Check RLS Policies
```sql
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'shared_oauth_tokens'
ORDER BY policyname;
```

### Step 4: Check Application Logs
Look for debug messages in the app console:
- `🔍 GDrive OAuth: verificando token compartilhado...`
- `✅ GDrive OAuth: token compartilhado encontrado: SIM/NÃO`
- `❌ GDrive OAuth: falha ao renovar token compartilhado: ...`

---

## 🛠️ Recommended Fixes

### Fix 1: Reconnect Google Drive Account
1. Go to Admin Settings → Integrations → Google Drive
2. Click "Conectar Google Drive"
3. Choose "Conta Compartilhada"
4. Complete OAuth flow
5. Verify token is saved in database

### Fix 2: Check OAuth Credentials
Verify in `lib/config/google_oauth_config.dart`:
- Client ID is correct
- Client Secret is correct
- Scopes include Drive API access

### Fix 3: Verify RLS Policies
If token exists but still fails, run in Supabase:
```sql
-- Test SELECT access
SELECT * FROM public.shared_oauth_tokens 
WHERE provider = 'google';

-- If this fails, check policies
SELECT * FROM pg_policies 
WHERE tablename = 'shared_oauth_tokens';
```

---

## 📊 Summary

| Component | Status | Issue |
|-----------|--------|-------|
| Shared Token Storage | ❌ | Token not found in database |
| Token Refresh Logic | ⚠️ | May be failing silently |
| RLS Policies | ✅ | Correctly configured |
| Error Handling | ✅ | User-friendly message shown |
| OAuth Config | ⚠️ | Needs verification |


