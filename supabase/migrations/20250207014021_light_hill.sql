-- Disable all foreign key constraints for companies table
ALTER TABLE companies 
NOCHECK CONSTRAINT ALL;

-- Drop existing foreign key constraints
ALTER TABLE companies
DROP CONSTRAINT IF EXISTS companies_team_leader_a_id_fkey,
DROP CONSTRAINT IF EXISTS companies_team_leader_b_id_fkey,
DROP CONSTRAINT IF EXISTS companies_team_leader_a_fkey,
DROP CONSTRAINT IF EXISTS companies_team_leader_b_fkey,
DROP CONSTRAINT IF EXISTS companies_user_id_fkey,
DROP CONSTRAINT IF EXISTS companies_status_id_fkey;

-- Disable RLS
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- Grant full access to authenticated users
GRANT ALL ON companies TO authenticated;