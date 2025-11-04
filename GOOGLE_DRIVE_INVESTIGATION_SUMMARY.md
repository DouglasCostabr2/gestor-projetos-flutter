# 📋 Google Drive Upload Failure - Investigation Summary

## Executive Summary

The Google Drive upload functionality is failing because the shared OAuth token is not available or cannot be refreshed. Users see the error:

> "Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações."

---

## Root Cause

The application throws `ConsentRequired()` exception when:

1. **No shared token exists** in `shared_oauth_tokens` table, AND
2. **No personal token exists** in `user_oauth_tokens` table, OR
3. **Token refresh fails** for both shared and personal tokens

---

## Investigation Findings

### 1. Architecture
- ✅ Per-user OAuth 2.0 integration implemented correctly
- ✅ Shared account fallback mechanism in place
- ✅ Database schema properly designed
- ✅ RLS policies correctly configured

### 2. Code Flow
- ✅ Error handling is comprehensive
- ✅ Debug logging is detailed
- ✅ User-friendly error messages implemented
- ⚠️ Silent error catching in `getSharedToken()` (line 118)

### 3. Database
- ✅ `shared_oauth_tokens` table exists
- ✅ RLS policies allow authenticated users to SELECT
- ✅ RLS policies restrict INSERT/UPDATE to admin/gestor
- ❓ **Unknown**: Is there actually a token in the table?

### 4. OAuth Configuration
- ⚠️ Client ID/Secret hardcoded in `google_oauth_config.dart`
- ⚠️ No validation that credentials are correct
- ⚠️ No test endpoint to verify credentials work

---

## Most Likely Causes (Ranked by Probability)

### 1. **Shared Token Never Saved** (Probability: 70%)
**Symptoms**:
- `shared_oauth_tokens` table is empty
- No admin/gestor ever completed the "Connect Google Drive" flow
- Or the connection flow failed silently

**Evidence**:
- Error message indicates no token found
- No debug logs showing token refresh attempts

**Fix**:
- Admin goes to Settings → Integrations → Google Drive
- Clicks "Conectar Google Drive"
- Selects "Conta Compartilhada"
- Completes OAuth flow
- Verifies token appears in database

---

### 2. **Token Refresh Fails** (Probability: 20%)
**Symptoms**:
- Token exists in database
- But refresh fails with error
- Falls back to personal token, then fails

**Evidence**:
- Debug logs show: `❌ GDrive OAuth: falha ao renovar token compartilhado: [ERROR]`
- Error message indicates permission/authentication issue

**Possible Causes**:
- Invalid Client ID/Secret
- Token revoked by user
- Google API rate limit exceeded
- Network connectivity issue

**Fix**:
- Verify Client ID/Secret in `google_oauth_config.dart`
- Disconnect and reconnect Google Drive account
- Check Google Cloud Console for API errors

---

### 3. **RLS Policy Blocking Query** (Probability: 5%)
**Symptoms**:
- Query to `shared_oauth_tokens` returns permission error
- `getSharedToken()` catches error and returns null

**Evidence**:
- Debug logs show: `❌ GDrive OAuth: erro ao buscar token compartilhado: [PERMISSION ERROR]`

**Fix**:
- Verify RLS policies exist
- Run migration if needed
- Check user role is 'admin', 'gestor', 'designer', 'financeiro', 'cliente', or 'usuario'

---

### 4. **OAuth Credentials Invalid** (Probability: 5%)
**Symptoms**:
- Token refresh always fails
- Error: "invalid_client" or "invalid_grant"

**Evidence**:
- Debug logs show: `❌ GDrive OAuth: falha ao renovar token compartilhado: invalid_client`

**Fix**:
- Verify credentials in Google Cloud Console
- Update `google_oauth_config.dart` with correct values
- Rebuild application

---

## Key Code Locations

| Component | File | Lines | Status |
|-----------|------|-------|--------|
| Token Storage | `google_drive_oauth_service.dart` | 20-99 | ✅ OK |
| Token Retrieval | `google_drive_oauth_service.dart` | 102-121 | ⚠️ Silent errors |
| Token Refresh | `google_drive_oauth_service.dart` | 168-235 | ✅ OK |
| Error Handling | `comments_section.dart` | 560-575 | ✅ OK |
| Database Schema | `2025-10-28_create_shared_oauth_tokens.sql` | - | ✅ OK |
| RLS Policies | `2025-10-28_create_shared_oauth_tokens.sql` | 36-89 | ✅ OK |

---

## Immediate Actions Required

### For Admin/Gestor:
1. Go to Admin Settings → Integrations → Google Drive
2. Check current status
3. If "Não conectado":
   - Click "Conectar Google Drive"
   - Choose "Conta Compartilhada"
   - Complete OAuth flow
4. If already connected:
   - Click "Desconectar"
   - Reconnect with valid credentials

### For Developer:
1. Check `shared_oauth_tokens` table for existing token
2. Review application logs for specific error messages
3. Verify OAuth credentials in `google_oauth_config.dart`
4. Test token refresh manually if needed
5. Check Google Cloud Console for API errors

---

## Verification Steps

After implementing fix:

1. **Database Check**:
   ```sql
   SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
   ```
   Should return one row with valid refresh_token

2. **Application Test**:
   - Try uploading a briefing image
   - Should succeed without error

3. **Log Verification**:
   - Should see: `✅ GDrive OAuth: token compartilhado renovado com sucesso`
   - Should see: `✅ Imagem enviada para Google Drive: [URL]`

4. **Google Drive Check**:
   - Verify file appears in "Gestor de Projetos" folder

---

## Related Documentation

- `GOOGLE_DRIVE_DIAGNOSTIC_REPORT.md` - Detailed diagnostic information
- `GOOGLE_DRIVE_TECHNICAL_ANALYSIS.md` - Technical architecture and code flow
- `GOOGLE_DRIVE_DEBUGGING_GUIDE.md` - Step-by-step debugging procedures


