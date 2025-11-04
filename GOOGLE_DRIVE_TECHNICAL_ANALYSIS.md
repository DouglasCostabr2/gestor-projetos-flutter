# 🔐 Google Drive OAuth 2.0 - Technical Analysis

## Architecture Overview

### Per-User OAuth Integration
The project implements **per-user OAuth 2.0** with a shared account fallback:

```
User Upload Request
    ↓
BriefingImageService._uploadSingleImage()
    ↓
GoogleDriveOAuthService.getAuthedClient()
    ↓
    ├─→ Try Shared Token (shared_oauth_tokens table)
    │   ├─→ Query: SELECT * WHERE provider='google'
    │   ├─→ If found: Refresh token via Google API
    │   └─→ If refresh fails: Continue to personal token
    │
    └─→ Try Personal Token (user_oauth_tokens table)
        ├─→ Query: SELECT * WHERE user_id=current_user AND provider='google'
        ├─→ If found: Refresh token via Google API
        └─→ If refresh fails: Throw ConsentRequired()
```

---

## Database Schema

### Table: `shared_oauth_tokens`
```sql
CREATE TABLE public.shared_oauth_tokens (
  id uuid PRIMARY KEY,
  provider text NOT NULL UNIQUE,        -- 'google'
  refresh_token text,                   -- OAuth refresh token
  access_token text,                    -- Current access token
  access_token_expiry timestamptz,      -- Token expiration
  connected_by uuid,                    -- User who connected
  connected_at timestamptz,             -- Connection timestamp
  updated_at timestamptz                -- Last update
);
```

### RLS Policies
```sql
-- SELECT: All authenticated users can read
USING (true);

-- INSERT/UPDATE: Only admin/gestor
WITH CHECK (
  EXISTS (SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'gestor'))
);

-- DELETE: Only admin
USING (
  EXISTS (SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin')
);
```

---

## Code Flow Analysis

### 1. Token Retrieval (`OAuthTokenStore.getSharedToken`)

**File**: `lib/services/google_drive_oauth_service.dart` (lines 102-121)

```dart
static Future<Map<String, dynamic>?> getSharedToken(String provider) async {
  try {
    debugPrint('🔍 GDrive OAuth: buscando token compartilhado...');
    final res = await _client
        .from('shared_oauth_tokens')
        .select('*')
        .eq('provider', provider)
        .maybeSingle();  // ← Returns null if not found
    
    debugPrint('✅ GDrive OAuth: token encontrado: ${res != null ? "SIM" : "NÃO"}');
    return res;
  } catch (e) {
    debugPrint('❌ GDrive OAuth: erro ao buscar: $e');
    return null;  // ← Silently returns null on error
  }
}
```

**Issues**:
- If query fails, error is logged but null is returned
- Caller can't distinguish between "no token" and "query failed"

### 2. Token Refresh (`getAuthedClient`)

**File**: `lib/services/google_drive_oauth_service.dart` (lines 168-235)

```dart
Future<auth.AuthClient> getAuthedClient() async {
  // 1. Try shared token
  final sharedToken = await OAuthTokenStore.getSharedToken('google');
  if (sharedToken != null && sharedToken['refresh_token'] != null) {
    try {
      final refreshed = await auth.refreshCredentials(_clientId, creds, base);
      // Update token in database
      await OAuthTokenStore.upsertSharedToken(...);
      return auth.authenticatedClient(base, refreshed);
    } catch (e) {
      debugPrint('❌ GDrive OAuth: falha ao renovar: $e');
      // Continue to personal token
    }
  }
  
  // 2. Try personal token (fallback)
  final stored = await OAuthTokenStore.getToken('google');
  if (stored != null && stored['refresh_token'] != null) {
    try {
      final refreshed = await auth.refreshCredentials(_clientId, creds, base);
      return auth.authenticatedClient(base, refreshed);
    } catch (e) {
      throw ConsentRequired();  // ← Final failure
    }
  }
  
  throw ConsentRequired();  // ← No tokens found
}
```

**Critical Points**:
- Line 186: `auth.refreshCredentials()` can fail silently
- Line 198: Error is logged but execution continues
- Line 234: Final `ConsentRequired()` is thrown

### 3. Error Handling in UI

**File**: `lib/ui/organisms/sections/comments_section.dart` (lines 560-575)

```dart
catch (e) {
  String errorMessage = 'Falha ao enviar: $e';
  
  // Check if it's a Google Drive consent error
  if (e.toString().contains('Consentimento necessário') ||
      e.toString().contains('ConsentRequired')) {
    errorMessage = 'Google Drive não conectado. Peça ao administrador...';
  }
  
  setState(() { _error = errorMessage; });
}
```

---

## Failure Points

### Point 1: Token Not in Database
```
Condition: shared_oauth_tokens table is empty
Result: getSharedToken() returns null
Impact: Falls back to personal token, then throws ConsentRequired()
```

### Point 2: Token Refresh Fails
```
Condition: auth.refreshCredentials() throws exception
Possible Causes:
  - Invalid Client ID/Secret
  - Token revoked by user
  - Network error
  - Google API rate limit
Result: Exception caught, continues to personal token
Impact: If personal token also fails, throws ConsentRequired()
```

### Point 3: RLS Policy Blocks Query
```
Condition: SELECT policy not applied correctly
Result: Supabase returns permission error
Impact: getSharedToken() catches error and returns null
```

---

## OAuth Credentials

**File**: `lib/config/google_oauth_config.dart`

The Client ID and Secret are hardcoded or passed via `--dart-define`:
```dart
static const String clientId = '...';
static const String clientSecret = '...';
```

**Risk**: If credentials are invalid, token refresh will always fail.

---

## Recommendations

1. **Verify Token Exists**: Check `shared_oauth_tokens` table
2. **Test Token Refresh**: Try refreshing manually with valid credentials
3. **Check OAuth Config**: Verify Client ID/Secret are correct
4. **Review Logs**: Look for specific error messages during refresh
5. **Test RLS**: Manually query the table to verify permissions


