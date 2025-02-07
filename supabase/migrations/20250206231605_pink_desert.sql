-- Disable RLS for companies table
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- Drop existing policies since they won't be needed
DROP POLICY IF EXISTS "enable_read_for_all" ON companies;
DROP POLICY IF EXISTS "enable_write_for_admins_and_owners" ON companies;
DROP POLICY IF EXISTS "enable_update_for_admins_and_owners" ON companies;
DROP POLICY IF EXISTS "enable_delete_for_admins_and_owners" ON companies;

-- Grant full access to authenticated users
GRANT ALL ON companies TO authenticated;