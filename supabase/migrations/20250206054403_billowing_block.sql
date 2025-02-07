-- Drop existing policies
DROP POLICY IF EXISTS "allow_read_all" ON users;
DROP POLICY IF EXISTS "allow_admin_all" ON users;
DROP POLICY IF EXISTS "allow_self_update" ON users;
DROP POLICY IF EXISTS "Users can view all companies" ON companies;
DROP POLICY IF EXISTS "Users can insert their own companies" ON companies;
DROP POLICY IF EXISTS "Users can update their own companies" ON companies;
DROP POLICY IF EXISTS "Users can delete their own companies" ON companies;
DROP POLICY IF EXISTS "Admins can manage all companies" ON companies;

-- Enable RLS for both tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "users_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "users_update_own"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "users_admin_all"
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

-- Companies table policies
CREATE POLICY "companies_read_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "companies_insert_own"
ON companies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "companies_update_own"
ON companies FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "companies_delete_own"
ON companies FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "companies_admin_all"
ON companies FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;
GRANT ALL ON companies TO authenticated;