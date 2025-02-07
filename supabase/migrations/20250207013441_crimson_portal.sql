-- Disable RLS temporarily to allow all operations
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_for_all" ON companies;
DROP POLICY IF EXISTS "enable_write_for_admins_and_owners" ON companies;
DROP POLICY IF EXISTS "enable_update_for_admins_and_owners" ON companies;
DROP POLICY IF EXISTS "enable_delete_for_admins_and_owners" ON companies;
DROP POLICY IF EXISTS "team_leaders_manage_companies" ON companies;
DROP POLICY IF EXISTS "team_leaders_manage_assigned_companies" ON companies;
DROP POLICY IF EXISTS "team_leader_company_access" ON companies;
DROP POLICY IF EXISTS "enable_team_leader_access" ON companies;

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;