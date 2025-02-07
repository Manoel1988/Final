-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_access" ON users;
DROP POLICY IF EXISTS "enable_admin_access" ON users;
DROP POLICY IF EXISTS "enable_self_access" ON users;

-- Create new simplified policies
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

-- Allow users to update their own metadata
CREATE POLICY "allow_self_update"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;