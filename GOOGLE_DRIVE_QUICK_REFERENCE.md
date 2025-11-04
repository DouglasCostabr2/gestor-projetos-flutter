# ⚡ Google Drive Upload - Quick Reference

## Error Message
```
Google Drive não conectado. Peça ao administrador para conectar uma conta do Google Drive nas configurações.
```

---

## Quick Diagnosis (2 minutes)

### Step 1: Check if Token Exists
```sql
SELECT COUNT(*) FROM shared_oauth_tokens WHERE provider = 'google';
```
- **Result = 0**: Go to Fix #1
- **Result = 1**: Go to Fix #2

### Step 2: Check Token Details
```sql
SELECT 
  refresh_token IS NOT NULL as has_refresh,
  access_token_expiry,
  connected_by,
  updated_at
FROM shared_oauth_tokens 
WHERE provider = 'google';
```
- **has_refresh = false**: Go to Fix #1
- **access_token_expiry in past**: Go to Fix #2
- **has_refresh = true**: Go to Fix #3

---

## Quick Fixes

### Fix #1: No Shared Token (Most Common)

**Problem**: `shared_oauth_tokens` table is empty

**Solution** (Admin/Gestor only):
1. Open app
2. Go to **Admin Settings** (gear icon)
3. Click **Integrations** section
4. Find **Google Drive**
5. Click **Conectar Google Drive**
6. Choose **Conta Compartilhada**
7. Complete OAuth flow in browser
8. Return to app

**Verify**:
```sql
SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
```
Should return one row with `refresh_token` populated.

---

### Fix #2: Token Expired or Invalid

**Problem**: Token exists but refresh fails

**Solution**:
1. Go to **Admin Settings** → **Integrations** → **Google Drive**
2. Click **Desconectar** (Disconnect)
3. Click **Conectar Google Drive** again
4. Choose **Conta Compartilhada**
5. Complete OAuth flow

**Verify**:
```sql
SELECT access_token_expiry FROM shared_oauth_tokens WHERE provider = 'google';
```
Should be in the future.

---

### Fix #3: RLS Policy Issue (Rare)

**Problem**: Query blocked by RLS policy

**Solution**:
1. Go to Supabase Dashboard
2. Click **SQL Editor**
3. Run this query:
```sql
-- Check if policies exist
SELECT policyname FROM pg_policies 
WHERE tablename = 'shared_oauth_tokens';
```

4. If policies missing, run migration:
   - File: `supabase/migrations/2025-10-28_create_shared_oauth_tokens.sql`
   - Or manually create policies in Supabase Dashboard

**Verify**:
```sql
SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
```
Should work without permission error.

---

## Testing After Fix

1. **In App**:
   - Go to any task
   - Try to add a briefing image
   - Should upload successfully

2. **In Database**:
   ```sql
   SELECT * FROM shared_oauth_tokens WHERE provider = 'google';
   ```
   Should show recent `updated_at` timestamp

3. **In Google Drive**:
   - Open Google Drive
   - Look for "Gestor de Projetos" folder
   - Verify image is there

---

## Debug Logs to Look For

### Success Indicators
```
✅ GDrive OAuth: token compartilhado encontrado: SIM
✅ GDrive OAuth: token compartilhado renovado com sucesso
✅ Imagem enviada para Google Drive: [URL]
```

### Failure Indicators
```
⚠️ GDrive OAuth: nenhum token compartilhado encontrado
❌ GDrive OAuth: falha ao renovar token compartilhado: [ERROR]
❌ GDrive OAuth: erro ao buscar token compartilhado: [ERROR]
```

---

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "nenhum token compartilhado encontrado" | No token in DB | Fix #1 |
| "falha ao renovar token compartilhado" | Token expired/invalid | Fix #2 |
| "erro ao buscar token compartilhado" | RLS policy issue | Fix #3 |
| "invalid_client" | Wrong OAuth credentials | Update config |
| "invalid_grant" | Token revoked | Fix #2 |

---

## Emergency Workaround

If shared token is broken and you need uploads NOW:

**Option 1: Use Personal Token**
- Each user connects their own Google Drive
- Go to Admin Settings → Google Drive
- Choose "Conta Pessoal" instead of "Conta Compartilhada"

**Option 2: Disable Uploads Temporarily**
- Comment out upload code in `BriefingImageService`
- Allow text-only comments

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/google_drive_oauth_service.dart` | OAuth logic |
| `lib/services/briefing_image_service.dart` | Image upload |
| `lib/config/google_oauth_config.dart` | OAuth credentials |
| `supabase/migrations/2025-10-28_create_shared_oauth_tokens.sql` | Database schema |
| `lib/ui/organisms/sections/comments_section.dart` | Error handling |

---

## Key Database Tables

| Table | Purpose |
|-------|---------|
| `shared_oauth_tokens` | Shared Google Drive token (all users) |
| `user_oauth_tokens` | Personal Google Drive tokens (per user) |
| `profiles` | User roles (used in RLS policies) |

---

## Key Code Locations

| Component | File | Lines |
|-----------|------|-------|
| Get shared token | `google_drive_oauth_service.dart` | 102-121 |
| Refresh token | `google_drive_oauth_service.dart` | 168-235 |
| Upload image | `briefing_image_service.dart` | 37-285 |
| Error handling | `comments_section.dart` | 560-575 |
| RLS policies | `2025-10-28_create_shared_oauth_tokens.sql` | 36-89 |

---

## Support Contacts

- **For Database Issues**: Check Supabase Dashboard
- **For OAuth Issues**: Check Google Cloud Console
- **For App Issues**: Check Flutter console logs
- **For RLS Issues**: Check Supabase SQL Editor

---

## Related Documents

- `GOOGLE_DRIVE_INVESTIGATION_SUMMARY.md` - Full investigation
- `GOOGLE_DRIVE_ROOT_CAUSE_ANALYSIS.md` - Detailed root cause
- `GOOGLE_DRIVE_DEBUGGING_GUIDE.md` - Step-by-step debugging
- `GOOGLE_DRIVE_TECHNICAL_ANALYSIS.md` - Technical details


