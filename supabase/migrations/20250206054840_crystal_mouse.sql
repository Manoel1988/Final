/*
  # Fix user permissions and policies

  1. Changes
    - Simplify and fix user table policies
    - Ensure proper admin access
    - Fix permission issues for user management
    - Add proper email update handling

  2. Security
    - Maintain read access for all authenticated users
    - Allow admins to manage all users
    - Allow users to update their own records
    - Ensure proper permission checks
*/

-- Drop existing policies
DROP POLICY IF EXISTS "users_read_all" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "users_admin_all" ON users;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create simplified policies
CREATE POLICY "allow_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow admins to manage all users
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
CREATE POLICY "allow_self_update"
ON users FOR UPDATE
TO authenticated
USING (
  -- Can only update own record
  auth.uid() = id
)
WITH CHECK (
  -- Can only update own record
  auth.uid() = id
);

-- Update sync function to handle permissions properly
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_permission text;
BEGIN
  -- Set default permission if not present
  v_permission := COALESCE(NEW.raw_user_meta_data->>'permission', 'user');
  
  -- Ensure raw_user_meta_data exists and has permission
  IF NEW.raw_user_meta_data IS NULL THEN
    NEW.raw_user_meta_data := jsonb_build_object('permission', v_permission);
  ELSIF NEW.raw_user_meta_data->>'permission' IS NULL THEN
    NEW.raw_user_meta_data := NEW.raw_user_meta_data || jsonb_build_object('permission', v_permission);
  END IF;

  -- Insert or update the user record
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

-- Recreate trigger
DROP TRIGGER IF EXISTS on_auth_user_changes ON auth.users;
CREATE TRIGGER on_auth_user_changes
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_sync();

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;