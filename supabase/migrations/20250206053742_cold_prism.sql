-- Drop existing trigger
DROP TRIGGER IF EXISTS on_auth_user_changes ON auth.users;

-- Update the handle_user_sync function to be more robust
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- For new users or updates
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
    COALESCE(
      NEW.raw_user_meta_data,
      jsonb_build_object('permission', 'user')
    ),
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now()
  WHERE users.id = EXCLUDED.id;

  RETURN NEW;
END;
$$;

-- Recreate the trigger with SECURITY DEFINER
CREATE TRIGGER on_auth_user_changes
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_sync();

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Update policies to ensure proper access
DROP POLICY IF EXISTS "enable_read_for_all" ON users;
DROP POLICY IF EXISTS "enable_update_for_admins_and_self" ON users;

-- Allow all authenticated users to read
CREATE POLICY "enable_read_for_all"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow admins to perform all operations
CREATE POLICY "enable_admin_all"
ON users FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Allow users to update their own records
CREATE POLICY "enable_self_update"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Grant necessary permissions to authenticated users
GRANT ALL ON users TO authenticated;