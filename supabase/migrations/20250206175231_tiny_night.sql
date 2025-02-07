-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_access" ON users;
DROP POLICY IF EXISTS "enable_update_access" ON users;
DROP POLICY IF EXISTS "enable_delete_access" ON users;

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "allow_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow admins to perform all operations
CREATE POLICY "allow_admin_all"
ON users FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Allow users to update their own records
CREATE POLICY "allow_update_own"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;

-- Create function to safely update user data
CREATE OR REPLACE FUNCTION update_user_data(
  target_user_id uuid,
  new_email text,
  new_role_id uuid,
  new_metadata jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the user making the request is an admin or the target user
  IF (auth.uid() = target_user_id) OR EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    -- Check if email is already in use
    IF EXISTS (
      SELECT 1 FROM auth.users
      WHERE email = new_email
      AND id != target_user_id
    ) THEN
      RAISE EXCEPTION 'Email already in use';
    END IF;

    -- Update auth.users
    UPDATE auth.users
    SET 
      email = new_email,
      raw_user_meta_data = new_metadata,
      email_confirmed_at = now()
    WHERE id = target_user_id;
    
    -- Update public.users
    UPDATE users
    SET 
      email = new_email,
      raw_user_meta_data = new_metadata,
      role_id = new_role_id,
      updated_at = now()
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;