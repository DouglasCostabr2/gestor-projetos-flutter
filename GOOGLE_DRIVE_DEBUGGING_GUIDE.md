# 🐛 Google Drive Upload - Debugging & Solutions Guide

## Quick Diagnosis Checklist

- [ ] Is there a shared token in the database?
- [ ] Can the token be refreshed successfully?
- [ ] Are the OAuth credentials valid?
- [ ] Can the user read from `shared_oauth_tokens` table?
- [ ] Is the Google Drive API enabled in Google Cloud Console?

---

## Step-by-Step Debugging

### Step 1: Check Database for Shared Token

**In Supabase Dashboard → SQL Editor:**

```sql
-- Check if shared token exists
SELECT 
  id,
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

**Expected Result**: One row with `has_refresh_token = true`

**If Empty**: 
- No shared token has been saved
- Admin/Gestor never completed the "Connect Google Drive" flow
- **Solution**: Go to Admin Settings → Integrations → Google Drive → Connect

**If Has Data**:
- Check `access_token_expiry` - is it in the past?
- If yes, token is expired and needs refresh
- **Solution**: Reconnect Google Drive account

---

### Step 2: Verify RLS Policies

```sql
-- Check RLS policies on shared_oauth_tokens
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'shared_oauth_tokens'
ORDER BY policyname;
```

**Expected Policies**:
1. `shared_oauth_tokens_select` - FOR SELECT, USING (true)
2. `shared_oauth_tokens_insert` - FOR INSERT, checks role IN ('admin', 'gestor')
3. `shared_oauth_tokens_update` - FOR UPDATE, checks role IN ('admin', 'gestor')
4. `shared_oauth_tokens_delete` - FOR DELETE, checks role = 'admin'

**If Missing**:
- Run migration: `supabase/migrations/2025-10-28_create_shared_oauth_tokens.sql`
- Or manually create policies in Supabase Dashboard

---

### Step 3: Test SELECT Permission

```sql
-- Test if current user can read shared tokens
SELECT * FROM public.shared_oauth_tokens 
WHERE provider = 'google';
```

**If Error**: "new row violates row-level security policy"
- RLS policy is blocking SELECT
- Check that user is authenticated
- Verify policy allows authenticated users

---

### Step 4: Check Application Logs

**In Flutter App Console:**

Look for these debug messages:

```
🔍 GDrive OAuth: verificando token compartilhado...
✅ GDrive OAuth: token compartilhado encontrado: SIM/NÃO
   - has refresh_token: true/false
   - has access_token: true/false
   - connected_by: [user-id]
🔄 GDrive OAuth: renovando token compartilhado...
✅ GDrive OAuth: token compartilhado renovado com sucesso
❌ GDrive OAuth: falha ao renovar token compartilhado: [ERROR]
```

**If you see**:
- `token compartilhado encontrado: NÃO` → Token not in database
- `falha ao renovar token compartilhado: [ERROR]` → Token refresh failed
- No messages at all → Code path not reached

---

### Step 5: Verify OAuth Credentials

**File**: `lib/config/google_oauth_config.dart`

Check:
```dart
static const String clientId = '...';
static const String clientSecret = '...';
```

**Verify in Google Cloud Console**:
1. Go to Google Cloud Console
2. Select your project
3. Go to Credentials
4. Find OAuth 2.0 Client ID
5. Verify Client ID matches
6. Verify Client Secret matches
7. Check "Authorized redirect URIs" includes `http://127.0.0.1:*`

**If Mismatch**:
- Update credentials in `google_oauth_config.dart`
- Rebuild and test

---

### Step 6: Test Token Refresh Manually

**In Supabase SQL Editor:**

```sql
-- Get the refresh token
SELECT refresh_token 
FROM public.shared_oauth_tokens 
WHERE provider = 'google';
```

Then use this token to test refresh via Google API:

```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "refresh_token=REFRESH_TOKEN_FROM_DB" \
  -d "grant_type=refresh_token"
```

**If Error**:
- `invalid_grant`: Token is invalid or revoked
- `invalid_client`: Client ID/Secret is wrong
- **Solution**: Reconnect Google Drive account

---

## Common Issues & Solutions

### Issue 1: "Google Drive não conectado"
**Cause**: No shared token in database
**Solution**:
1. Go to Admin Settings → Integrations
2. Click "Conectar Google Drive"
3. Choose "Conta Compartilhada"
4. Complete OAuth flow
5. Verify token appears in database

### Issue 2: Token Refresh Fails
**Cause**: Invalid credentials or revoked token
**Solution**:
1. Disconnect Google Drive (Admin Settings)
2. Reconnect with valid credentials
3. Verify Client ID/Secret in code

### Issue 3: RLS Permission Denied
**Cause**: Policy not applied or user role incorrect
**Solution**:
1. Verify user has 'admin' or 'gestor' role
2. Check RLS policies exist
3. Run migration if needed

### Issue 4: Token Exists but Still Fails
**Cause**: Token is expired or corrupted
**Solution**:
1. Delete token from database
2. Reconnect Google Drive
3. Verify new token works

---

## Testing Upload After Fix

1. **Verify Token in Database**:
   ```sql
   SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
   ```

2. **Try Upload in App**:
   - Go to a task
   - Try to add a briefing image
   - Should upload successfully

3. **Check Logs**:
   - Should see: `✅ GDrive OAuth: token compartilhado renovado com sucesso`
   - Should see: `✅ Imagem enviada para Google Drive: [URL]`

4. **Verify File in Google Drive**:
   - Check Google Drive for "Gestor de Projetos" folder
   - Verify image is there

---

## Emergency Workaround

If shared token is broken and you need uploads to work:

1. **Use Personal Token**:
   - Each user connects their own Google Drive
   - Go to Admin Settings → Google Drive
   - Click "Conectar Google Drive"
   - Choose "Conta Pessoal"

2. **Temporary Disable Uploads**:
   - Comment out upload code in `BriefingImageService`
   - Allow text-only comments


