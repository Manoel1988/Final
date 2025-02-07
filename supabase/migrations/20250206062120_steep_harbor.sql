-- Drop existing policies
DROP POLICY IF EXISTS "allow_read_all_users" ON users;
DROP POLICY IF EXISTS "allow_update_user_metadata" ON users;

-- Create a security definer function to check if a user is an admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = user_id
    AND raw_user_meta_data->>'permission' = 'admin'
  );
$$;

-- Create a security definer function to update user metadata
CREATE OR REPLACE FUNCTION update_user_metadata(
  target_user_id uuid,
  new_metadata jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (auth.uid() = target_user_id) OR is_admin(auth.uid()) THEN
    UPDATE auth.users
    SET raw_user_meta_data = new_metadata
    WHERE id = target_user_id;
    
    UPDATE users
    SET raw_user_meta_data = new_metadata
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;

-- Create basic policies
CREATE POLICY "enable_read_access"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_update_access"
ON users FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR is_admin(auth.uid())
)
WITH CHECK (
  auth.uid() = id OR is_admin(auth.uid())
);