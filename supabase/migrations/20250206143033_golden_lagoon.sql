/*
  # Fix Team Leaders Policies

  1. Changes
    - Drop existing policies if they exist
    - Recreate policies with proper checks
    - Ensure idempotent operations
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Team leaders are viewable by authenticated users" ON team_leaders;
  DROP POLICY IF EXISTS "Team leaders can be managed by admins" ON team_leaders;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create policies with proper checks
DO $$ 
BEGIN
  -- Create view policy if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'team_leaders' 
    AND policyname = 'Team leaders are viewable by authenticated users'
  ) THEN
    CREATE POLICY "Team leaders are viewable by authenticated users"
      ON team_leaders
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  -- Create admin management policy if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'team_leaders' 
    AND policyname = 'Team leaders can be managed by admins'
  ) THEN
    CREATE POLICY "Team leaders can be managed by admins"
      ON team_leaders
      FOR ALL
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM users
          WHERE id = auth.uid()
          AND raw_user_meta_data->>'permission' = 'admin'
        )
      );
  END IF;
END $$;