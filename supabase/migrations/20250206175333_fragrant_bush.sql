-- Drop existing policies
DROP POLICY IF EXISTS "companies_read_all" ON companies;
DROP POLICY IF EXISTS "companies_insert_own" ON companies;
DROP POLICY IF EXISTS "companies_update_own" ON companies;
DROP POLICY IF EXISTS "companies_delete_own" ON companies;
DROP POLICY IF EXISTS "companies_admin_all" ON companies;
DROP POLICY IF EXISTS "Team leaders can manage their companies" ON companies;

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "allow_read_all_companies"
ON companies FOR SELECT
TO authenticated
USING (true);

-- Allow users to manage their own companies
CREATE POLICY "allow_insert_own_companies"
ON companies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_update_own_companies"
ON companies FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_delete_own_companies"
ON companies FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Allow admins to manage all companies
CREATE POLICY "allow_admin_all_companies"
ON companies FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Allow team leaders to manage their assigned companies
CREATE POLICY "allow_team_leader_manage_companies"
ON companies FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM team_leaders
    WHERE user_id = auth.uid()
    AND id = companies.team_leader_id
  )
);

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;