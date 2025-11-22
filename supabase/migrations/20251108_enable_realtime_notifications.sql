-- ============================================================================
-- Migration: Enable Realtime for notifications table
-- Date: 2025-11-08
-- Description: Enables Supabase Realtime for the notifications table to allow
--              real-time updates when notifications are created, updated, or deleted
-- ============================================================================

-- Enable Realtime for the notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Verify that Realtime is enabled
SELECT 
  schemaname,
  tablename,
  pubname
FROM pg_publication_tables
WHERE tablename = 'notifications';

