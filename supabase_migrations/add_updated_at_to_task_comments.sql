-- Migration: Add updated_at column to task_comments table
-- Description: Adds updated_at timestamp column and trigger to automatically update it on row modification

-- Step 1: Add updated_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'task_comments' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE task_comments 
    ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    
    -- Initialize updated_at with created_at for existing rows
    UPDATE task_comments 
    SET updated_at = created_at 
    WHERE updated_at IS NULL;
  END IF;
END $$;

-- Step 2: Create or replace the trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger on task_comments table
DROP TRIGGER IF EXISTS set_updated_at ON task_comments;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON task_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Step 4: Add comment to document the column
COMMENT ON COLUMN task_comments.updated_at IS 'Timestamp of last update, automatically set by trigger';

