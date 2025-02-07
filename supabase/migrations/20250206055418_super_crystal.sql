-- Drop existing policies
DROP POLICY IF EXISTS "users_select" ON users;
DROP POLICY IF EXISTS "users_update_admin" ON users;
DROP POLICY IF EXISTS "users_update_self" ON users;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create simplified policies
CREATE POLICY "allow_select_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_update_all"
ON users FOR UPDATE
TO authenticated
USING (
  -- Allow if user is admin or updating their own record
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (
      raw_user_meta_data->>'permission' = 'admin'
      OR id = users.id
    )
  )
);

-- Update sync function to be more robust
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
    raw_user_meta_data = NEW.raw_user_meta_data,
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