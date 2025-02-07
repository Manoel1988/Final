-- Drop existing foreign key constraints if they exist
DO $$ 
BEGIN
  ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_team_leader_a_id_fkey;
  ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_team_leader_b_id_fkey;
  ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_team_leader_a_fkey;
  ALTER TABLE companies DROP CONSTRAINT IF EXISTS companies_team_leader_b_fkey;
END $$;

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_companies_team_leader_a;
DROP INDEX IF EXISTS idx_companies_team_leader_b;

-- Add team leader columns to companies table if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'companies' AND column_name = 'team_leader_a_id'
  ) THEN
    ALTER TABLE companies ADD COLUMN team_leader_a_id uuid;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'companies' AND column_name = 'team_leader_b_id'
  ) THEN
    ALTER TABLE companies ADD COLUMN team_leader_b_id uuid;
  END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX idx_companies_team_leader_b ON companies(team_leader_b_id);

-- Add foreign key constraints with proper names that match Supabase's expectations
ALTER TABLE companies
ADD CONSTRAINT companies_team_leader_a_id_fkey
FOREIGN KEY (team_leader_a_id)
REFERENCES team_leaders(id)
ON DELETE SET NULL;

ALTER TABLE companies
ADD CONSTRAINT companies_team_leader_b_id_fkey
FOREIGN KEY (team_leader_b_id)
REFERENCES team_leaders(id)
ON DELETE SET NULL;

-- Create function to get active companies count for a team leader
CREATE OR REPLACE FUNCTION get_team_leader_active_companies_count(team_leader_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT COUNT(DISTINCT c.id)::integer
  FROM companies c
  JOIN company_statuses cs ON c.status_id = cs.id
  WHERE cs.is_active = true
  AND (
    c.team_leader_a_id = team_leader_id OR
    c.team_leader_b_id = team_leader_id
  );
$$;

-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "team_leaders_manage_companies" ON companies;
DROP POLICY IF EXISTS "team_leaders_manage_assigned_companies" ON companies;
DROP POLICY IF EXISTS "team_leader_company_access" ON companies;

-- Create new policy for team leaders to manage their assigned companies
CREATE POLICY "enable_team_leader_access"
ON companies
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM team_leaders
    WHERE user_id = auth.uid()
    AND (
      id = companies.team_leader_a_id OR
      id = companies.team_leader_b_id
    )
  )
);

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;