-- Migration: Add foreign key relationship between task_comments and profiles
-- Description: Creates the foreign key constraint so Supabase can resolve the relationship in queries

-- Step 1: Verify that all user_id values in task_comments exist in profiles
-- This prevents the foreign key creation from failing
DO $$
BEGIN
  -- Check for orphaned records
  IF EXISTS (
    SELECT 1 
    FROM task_comments tc
    LEFT JOIN profiles p ON tc.user_id = p.id
    WHERE tc.user_id IS NOT NULL 
    AND p.id IS NULL
  ) THEN
    RAISE NOTICE 'Warning: Found task_comments with user_id that do not exist in profiles table';
    -- Optionally, you could delete these orphaned records or set user_id to NULL
    -- DELETE FROM task_comments WHERE user_id NOT IN (SELECT id FROM profiles);
  END IF;
END $$;

-- Step 2: Add the foreign key constraint if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'task_comments_user_id_fkey' 
    AND table_name = 'task_comments'
  ) THEN
    ALTER TABLE task_comments
    ADD CONSTRAINT task_comments_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES profiles(id)
    ON DELETE SET NULL;  -- When a profile is deleted, set user_id to NULL instead of deleting the comment
    
    RAISE NOTICE 'Foreign key constraint task_comments_user_id_fkey created successfully';
  ELSE
    RAISE NOTICE 'Foreign key constraint task_comments_user_id_fkey already exists';
  END IF;
END $$;

-- Step 3: Create an index on user_id for better query performance
CREATE INDEX IF NOT EXISTS idx_task_comments_user_id ON task_comments(user_id);

-- Step 4: Add comment to document the relationship
COMMENT ON CONSTRAINT task_comments_user_id_fkey ON task_comments IS 'Foreign key to profiles table, allows Supabase to resolve user_profile relationship';

