/*
  # Fix user permissions and policies

  1. Changes
    - Drop existing policies
    - Create new simplified policies for user management
    - Add function to safely update user email
    - Add function to update user metadata

  2. Security
    - Enable RLS
    - Add policies for read, update, and admin access
    - Ensure proper permission checks
*/

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "users_read" ON users;
  DROP POLICY IF EXISTS "users_update" ON users;
  DROP POLICY IF EXISTS "users_admin" ON users;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new simplified policies
CREATE POLICY "users_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "users_update_own"
ON users FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to safely update user email
CREATE OR REPLACE FUNCTION update_user_email_safe(
  target_user_id uuid,
  new_email text
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

    -- Update email in auth.users
    UPDATE auth.users
    SET email = new_email,
        email_confirmed_at = now()
    WHERE id = target_user_id;
    
    -- Update email in public.users
    UPDATE users
    SET email = new_email,
        updated_at = now()
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;

-- Create function to update user metadata
CREATE OR REPLACE FUNCTION update_user_metadata_safe(
  target_user_id uuid,
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
    -- Update metadata in auth.users
    UPDATE auth.users
    SET raw_user_meta_data = new_metadata
    WHERE id = target_user_id;
    
    -- Update metadata in public.users
    UPDATE users
    SET raw_user_meta_data = new_metadata,
        updated_at = now()
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;