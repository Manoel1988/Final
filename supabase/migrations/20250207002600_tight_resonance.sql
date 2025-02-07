-- Drop existing foreign key constraints if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'fk_companies_team_leader_a'
  ) THEN
    ALTER TABLE companies DROP CONSTRAINT fk_companies_team_leader_a;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'fk_companies_team_leader_b'
  ) THEN
    ALTER TABLE companies DROP CONSTRAINT fk_companies_team_leader_b;
  END IF;
END $$;

-- Add team leader columns to companies table
ALTER TABLE companies
ADD COLUMN IF NOT EXISTS team_leader_a_id uuid REFERENCES team_leaders(id),
ADD COLUMN IF NOT EXISTS team_leader_b_id uuid REFERENCES team_leaders(id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_b ON companies(team_leader_b_id);

-- Add foreign key constraints with proper ON DELETE behavior
ALTER TABLE companies
ADD CONSTRAINT fk_companies_team_leader_a
FOREIGN KEY (team_leader_a_id)
REFERENCES team_leaders(id)
ON DELETE SET NULL;

ALTER TABLE companies
ADD CONSTRAINT fk_companies_team_leader_b
FOREIGN KEY (team_leader_b_id)
REFERENCES team_leaders(id)
ON DELETE SET NULL;

-- Update policies to allow team leaders to manage their assigned companies
CREATE POLICY "team_leaders_manage_companies"
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