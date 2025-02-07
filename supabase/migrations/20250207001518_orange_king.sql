-- Add team leader columns to companies table
ALTER TABLE companies
ADD COLUMN IF NOT EXISTS team_leader_a_id uuid REFERENCES team_leaders(id),
ADD COLUMN IF NOT EXISTS team_leader_b_id uuid REFERENCES team_leaders(id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_b ON companies(team_leader_b_id);

-- Add foreign key constraints
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