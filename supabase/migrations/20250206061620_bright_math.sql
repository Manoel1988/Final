-- Re-enable RLS for both tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "users_read_all" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "users_admin_all" ON users;

-- Create new policies for users table
CREATE POLICY "enable_read_for_authenticated"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_update_for_self_and_admin"
ON users FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Recreate companies policies
CREATE POLICY "enable_read_companies"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_insert_own_companies"
ON companies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "enable_update_own_companies"
ON companies FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);