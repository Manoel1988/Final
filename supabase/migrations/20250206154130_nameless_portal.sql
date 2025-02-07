/*
  # Fix user permissions and policies

  1. Changes
    - Drop existing policies safely
    - Create new simplified policies for user management
    - Update user sync function to handle roles properly

  2. Security
    - Enable RLS
    - Add policies for read, update, and admin access
    - Ensure proper permission checks
*/

-- Safely drop existing policies
DO $$ 
BEGIN
  -- Drop all existing policies on users table
  DROP POLICY IF EXISTS "users_select" ON users;
  DROP POLICY IF EXISTS "users_update_admin" ON users;
  DROP POLICY IF EXISTS "users_update_self" ON users;
  DROP POLICY IF EXISTS "allow_select_all" ON users;
  DROP POLICY IF EXISTS "allow_update_all" ON users;
  DROP POLICY IF EXISTS "enable_read_access" ON users;
  DROP POLICY IF EXISTS "enable_insert_access" ON users;
  DROP POLICY IF EXISTS "enable_update_access" ON users;
  DROP POLICY IF EXISTS "enable_delete_access" ON users;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new simplified policies
CREATE POLICY "users_read"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "users_update"
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

CREATE POLICY "users_admin"
ON users FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Update sync function to handle roles properly
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Ensure raw_user_meta_data exists and has permission
  IF NEW.raw_user_meta_data IS NULL OR NEW.raw_user_meta_data->>'permission' IS NULL THEN
    NEW.raw_user_meta_data := jsonb_build_object('permission', 'user');
  END IF;

  -- Insert or update the user record
  INSERT INTO public.users (
    id,
    email,
    raw_user_meta_data,
    role_id,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data,
    NULL, -- role_id will be set separately
    COALESCE(NEW.created_at, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = NEW.raw_user_meta_data,
    updated_at = now();

  RETURN NEW;
END;
$$;