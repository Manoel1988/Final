-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "enable_read_for_all" ON users;
DROP POLICY IF EXISTS "enable_admin_all" ON users;
DROP POLICY IF EXISTS "enable_self_update" ON users;

-- Create a function to check admin status without recursion
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = user_id
    AND raw_user_meta_data->>'permission' = 'admin'
  );
$$;

-- Create simplified policies using the non-recursive function
CREATE POLICY "allow_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_admin_all"
ON users FOR ALL
TO authenticated
USING (is_admin(auth.uid()));

CREATE POLICY "allow_self_update"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Update the sync function to be more efficient
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
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
    COALESCE(NEW.raw_user_meta_data, jsonb_build_object('permission', 'user')),
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();
  
  RETURN NEW;
END;
$$;

-- Ensure the trigger is properly set
DROP TRIGGER IF EXISTS on_auth_user_changes ON auth.users;
CREATE TRIGGER on_auth_user_changes
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_sync();