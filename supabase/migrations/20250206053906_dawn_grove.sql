-- Drop existing sync function and recreate with better error handling
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
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error details if needed
  RAISE NOTICE 'Error in handle_user_sync: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Recreate trigger with proper timing
DROP TRIGGER IF EXISTS on_auth_user_changes ON auth.users;
CREATE TRIGGER on_auth_user_changes
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_sync();

-- Update policies to ensure proper access
DROP POLICY IF EXISTS "allow_read_all" ON users;
DROP POLICY IF EXISTS "allow_admin_all" ON users;
DROP POLICY IF EXISTS "allow_self_update" ON users;

-- Create simplified policies
CREATE POLICY "enable_read_access"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_admin_access"
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

CREATE POLICY "enable_self_access"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);