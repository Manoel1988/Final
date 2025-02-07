/*
  # Update user permissions for admin access

  1. Changes
    - Drop existing policies
    - Create new policies for admin access
    - Add function to safely update user data

  2. Security
    - Enable RLS
    - Add policies for read and update access
    - Ensure proper permission checks for admins
*/

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "users_read_all" ON users;
  DROP POLICY IF EXISTS "users_update_own" ON users;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "enable_read_for_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_update_for_admins_and_self"
ON users FOR UPDATE
TO authenticated
USING (
  -- Allow if user is updating their own record or is an admin
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  -- Same condition for the new row
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

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