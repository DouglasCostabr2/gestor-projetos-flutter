-- Script para testar se a trigger de notificação de convite está funcionando

-- 1. Verificar se a trigger existe
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  pg_get_triggerdef(oid) as definition
FROM pg_trigger
WHERE tgname = 'trigger_notify_organization_invite';

-- 2. Verificar se a função existe
SELECT 
  proname as function_name,
  prosrc as source_code
FROM pg_proc
WHERE proname = 'notify_organization_invite';

-- 3. Listar convites recentes (última hora)
SELECT 
  id,
  email,
  organization_id,
  status,
  invited_by,
  created_at
FROM public.organization_invites
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- 4. Listar notificações de convite recentes (última hora)
SELECT 
  id,
  user_id,
  organization_id,
  type,
  title,
  message,
  is_read,
  created_at
FROM public.notifications
WHERE type = 'organization_invite_received'
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- 5. Verificar se há usuários com os emails dos convites
SELECT 
  i.email,
  i.created_at as invite_created_at,
  u.id as user_id,
  u.email as user_email,
  n.id as notification_id,
  n.created_at as notification_created_at
FROM public.organization_invites i
LEFT JOIN auth.users u ON u.email = i.email
LEFT JOIN public.notifications n ON n.user_id = u.id 
  AND n.type = 'organization_invite_received'
  AND n.created_at >= i.created_at
WHERE i.created_at > NOW() - INTERVAL '1 hour'
ORDER BY i.created_at DESC;

