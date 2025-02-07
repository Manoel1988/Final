-- Verify and add team leader columns
DO $$ 
BEGIN
  -- Add team_leader_a_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'companies' AND column_name = 'team_leader_a_id'
  ) THEN
    ALTER TABLE companies ADD COLUMN team_leader_a_id uuid REFERENCES team_leaders(id);
  END IF;

  -- Add team_leader_b_id if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'companies' AND column_name = 'team_leader_b_id'
  ) THEN
    ALTER TABLE companies ADD COLUMN team_leader_b_id uuid REFERENCES team_leaders(id);
  END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_b ON companies(team_leader_b_id);

-- Ensure foreign key constraints exist with proper ON DELETE behavior
ALTER TABLE companies
DROP CONSTRAINT IF EXISTS companies_team_leader_a_id_fkey,
DROP CONSTRAINT IF EXISTS companies_team_leader_b_id_fkey;

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