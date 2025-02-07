/*
  # Final Users Table Fix

  1. Changes
    - Simplify RLS policies to basic operations
    - Fix user synchronization
    - Remove recursive policy checks
    - Add proper security definer functions
  
  2. Security
    - Maintain proper access control
    - Allow user self-management
    - Enable admin capabilities
    - Prevent unauthorized access
*/

-- Drop existing policies
DROP POLICY IF EXISTS "users_read_access" ON users;
DROP POLICY IF EXISTS "users_insert_access" ON users;
DROP POLICY IF EXISTS "users_update_access" ON users;
DROP POLICY IF EXISTS "users_delete_access" ON users;

-- Create basic read policy
CREATE POLICY "allow_read_users"
ON users FOR SELECT
TO authenticated
USING (true);

-- Create basic insert policy
CREATE POLICY "allow_insert_users"
ON users FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = id
);

-- Create basic update policy
CREATE POLICY "allow_update_users"
ON users FOR UPDATE
TO authenticated
USING (
  -- Can update own record
  auth.uid() = id
)
WITH CHECK (
  -- Ensure email matches auth.users
  email = (SELECT email FROM auth.users WHERE id = auth.uid())
);

-- Create basic delete policy
CREATE POLICY "allow_delete_users"
ON users FOR DELETE
TO authenticated
USING (
  -- Can only delete own record
  auth.uid() = id
);

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  );
$$;

-- Create admin policies using the is_admin function
CREATE POLICY "admin_manage_users"
ON users
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Update sync function to be more robust
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  default_meta jsonb;
BEGIN
  -- Set default metadata
  default_meta := jsonb_build_object('permission', 'user');
  
  -- Ensure raw_user_meta_data has required fields
  NEW.raw_user_meta_data := COALESCE(NEW.raw_user_meta_data, default_meta);
  
  IF NEW.raw_user_meta_data->>'permission' IS NULL THEN
    NEW.raw_user_meta_data := jsonb_set(NEW.raw_user_meta_data, '{permission}', '"user"');
  END IF;

  -- Handle insert or update
  INSERT INTO public.users (
    id,
    email,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data,
    COALESCE(NEW.created_at, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();

  RETURN NEW;
END;
$$;