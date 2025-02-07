/*
  # Fix User Permissions

  1. Changes
    - Simplify user table policies
    - Add proper sync trigger
    - Fix permission issues
  
  2. Security
    - Enable proper user synchronization
    - Maintain data integrity
    - Ensure proper access control
*/

-- Drop existing policies and triggers
DROP POLICY IF EXISTS "allow_read_users" ON users;
DROP POLICY IF EXISTS "allow_insert_users" ON users;
DROP POLICY IF EXISTS "allow_update_users" ON users;
DROP POLICY IF EXISTS "allow_delete_users" ON users;
DROP POLICY IF EXISTS "admin_manage_users" ON users;
DROP TRIGGER IF EXISTS sync_auth_users ON auth.users;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;

-- Basic policies for all authenticated users
CREATE POLICY "enable_read_for_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_update_for_own_record"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Create trigger function for user sync
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, email, raw_user_meta_data, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data, jsonb_build_object('permission', 'user')),
    NEW.created_at,
    NEW.updated_at
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();
  
  RETURN NEW;
END;
$$;

-- Create trigger for auth user changes
CREATE TRIGGER on_auth_user_changes
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_sync();