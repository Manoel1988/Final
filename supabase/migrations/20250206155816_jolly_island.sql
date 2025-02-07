-- Safely create delete policy if it doesn't exist
DO $$ 
BEGIN
  -- Drop the policy if it exists
  DROP POLICY IF EXISTS "enable_delete_access" ON users;
  
  -- Create the policy
  CREATE POLICY "enable_delete_access"
  ON users FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create or replace function to safely delete users
CREATE OR REPLACE FUNCTION delete_user_safe(
  target_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the user making the request is an admin
  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    -- Delete from public.users first (due to foreign key constraint)
    DELETE FROM users WHERE id = target_user_id;
    
    -- Delete from auth.users
    DELETE FROM auth.users WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;