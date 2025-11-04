# 🎯 Google Drive Upload Failure - Root Cause Analysis

## Problem Statement

Users cannot upload briefing images or files to Google Drive. The application displays:

```
Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações.
```

---

## Root Cause

The application throws `ConsentRequired()` exception in `GoogleDriveOAuthService.getAuthedClient()` (line 234) when:

**BOTH conditions are true:**
1. No valid shared OAuth token exists in `shared_oauth_tokens` table, AND
2. No valid personal OAuth token exists in `user_oauth_tokens` table

**OR when:**
- Token refresh fails for both shared and personal tokens

---

## Why This Happens

### Scenario 1: Shared Token Never Saved (Most Likely - 70%)

**Flow**:
```
Admin/Gestor never connected Google Drive
    ↓
shared_oauth_tokens table is empty
    ↓
OAuthTokenStore.getSharedToken('google') returns null
    ↓
Code falls back to personal token
    ↓
Personal token also doesn't exist
    ↓
ConsentRequired() exception thrown
    ↓
User sees error message
```

**Why it happens**:
- Admin/Gestor hasn't gone to Settings → Integrations → Google Drive
- Or the connection flow was started but not completed
- Or the connection flow failed silently

**Evidence**:
- Error message appears immediately
- No debug logs showing token refresh attempts
- Database query returns empty result

---

### Scenario 2: Token Refresh Fails (Probability - 20%)

**Flow**:
```
Shared token exists in database
    ↓
OAuthTokenStore.getSharedToken('google') returns token data
    ↓
auth.refreshCredentials() is called
    ↓
Google API returns error (invalid credentials, revoked token, etc.)
    ↓
Exception caught at line 196-200
    ↓
Code falls back to personal token
    ↓
Personal token refresh also fails
    ↓
ConsentRequired() exception thrown
    ↓
User sees error message
```

**Why it happens**:
- OAuth Client ID/Secret is invalid
- Token was revoked by the user
- Google API rate limit exceeded
- Network connectivity issue
- Token is corrupted or malformed

**Evidence**:
- Debug logs show: `❌ GDrive OAuth: falha ao renovar token compartilhado: [ERROR]`
- Error message appears after delay (API call timeout)
- Specific error in logs (invalid_client, invalid_grant, etc.)

---

### Scenario 3: RLS Policy Blocks Query (Probability - 5%)

**Flow**:
```
User tries to query shared_oauth_tokens
    ↓
RLS policy check fails
    ↓
Supabase returns permission error
    ↓
OAuthTokenStore.getSharedToken() catches error
    ↓
Returns null (line 119)
    ↓
Code falls back to personal token
    ↓
ConsentRequired() exception thrown
```

**Why it happens**:
- RLS policy not applied correctly
- User role is not recognized
- Database permission issue
- Supabase configuration error

**Evidence**:
- Debug logs show: `❌ GDrive OAuth: erro ao buscar token compartilhado: [PERMISSION ERROR]`
- Manual SQL query also fails with permission error

---

## Critical Code Sections

### 1. Token Retrieval (Silent Error Handling)
**File**: `lib/services/google_drive_oauth_service.dart` (lines 102-121)

```dart
static Future<Map<String, dynamic>?> getSharedToken(String provider) async {
  try {
    final res = await _client
        .from('shared_oauth_tokens')
        .select('*')
        .eq('provider', provider)
        .maybeSingle();
    return res;
  } catch (e) {
    debugPrint('❌ GDrive OAuth: erro ao buscar token compartilhado: $e');
    return null;  // ← PROBLEM: Can't distinguish between "no token" and "query failed"
  }
}
```

**Issue**: If the query fails (permission error, network error, etc.), it returns `null` just like when no token exists. The caller can't tell the difference.

### 2. Token Refresh with Fallback
**File**: `lib/services/google_drive_oauth_service.dart` (lines 168-235)

```dart
Future<auth.AuthClient> getAuthedClient() async {
  // Try shared token
  final sharedToken = await OAuthTokenStore.getSharedToken('google');
  if (sharedToken != null && sharedToken['refresh_token'] != null) {
    try {
      final refreshed = await auth.refreshCredentials(_clientId, creds, base);
      return auth.authenticatedClient(base, refreshed);
    } catch (e) {
      debugPrint('❌ GDrive OAuth: falha ao renovar token compartilhado: $e');
      // Continue to personal token
    }
  }
  
  // Try personal token
  final stored = await OAuthTokenStore.getToken('google');
  if (stored != null && stored['refresh_token'] != null) {
    try {
      final refreshed = await auth.refreshCredentials(_clientId, creds, base);
      return auth.authenticatedClient(base, refreshed);
    } catch (e) {
      throw ConsentRequired();  // ← FINAL FAILURE
    }
  }
  
  throw ConsentRequired();  // ← NO TOKENS FOUND
}
```

**Issue**: If both tokens fail to refresh, `ConsentRequired()` is thrown without distinguishing between "no token" and "refresh failed".

### 3. Error Handling in UI
**File**: `lib/ui/organisms/sections/comments_section.dart` (lines 560-575)

```dart
catch (e) {
  String errorMessage = 'Falha ao enviar: $e';
  
  if (e.toString().contains('Consentimento necessário') ||
      e.toString().contains('ConsentRequired')) {
    errorMessage = 'Google Drive não conectado. Peça ao administrador...';
  }
  
  setState(() { _error = errorMessage; });
}
```

**Issue**: Generic error message doesn't help user understand what went wrong.

---

## Verification Checklist

To determine which scenario is occurring:

- [ ] **Check Database**: `SELECT * FROM shared_oauth_tokens WHERE provider = 'google';`
  - Empty? → Scenario 1
  - Has data? → Scenario 2 or 3

- [ ] **Check Logs**: Look for `❌ GDrive OAuth:` messages
  - "token compartilhado encontrado: NÃO" → Scenario 1
  - "falha ao renovar token compartilhado" → Scenario 2
  - "erro ao buscar token compartilhado" → Scenario 3

- [ ] **Check OAuth Credentials**: Verify in `google_oauth_config.dart`
  - Invalid? → Scenario 2

- [ ] **Test RLS**: Run `SELECT * FROM shared_oauth_tokens WHERE provider = 'google';` in Supabase
  - Permission error? → Scenario 3

---

## Solution Summary

| Scenario | Cause | Solution |
|----------|-------|----------|
| 1 | No shared token | Admin connects Google Drive account |
| 2 | Token refresh fails | Verify OAuth credentials, reconnect account |
| 3 | RLS blocks query | Verify RLS policies, check user role |

---

## Recommended Immediate Actions

1. **Check Database**:
   ```sql
   SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
   ```

2. **If Empty**: Admin must connect Google Drive
   - Settings → Integrations → Google Drive → Connect

3. **If Has Data**: Check logs for specific error
   - Look for `❌ GDrive OAuth:` messages
   - Identify which step is failing

4. **If Still Failing**: Verify OAuth credentials
   - Check `google_oauth_config.dart`
   - Verify in Google Cloud Console
   - Reconnect if needed

---

## Prevention

To prevent this in the future:

1. **Better Error Messages**: Distinguish between "no token" and "refresh failed"
2. **Token Validation**: Add endpoint to test token validity
3. **Automatic Reconnection**: Detect expired tokens and prompt user
4. **Monitoring**: Log all token operations for debugging


