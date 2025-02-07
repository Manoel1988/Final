/*
  # Add Team Leaders to Companies Relationship

  1. Changes
    - Add team_leader_id to companies table
    - Create foreign key relationship
    - Update policies
*/

-- Add team_leader_id to companies table
ALTER TABLE companies
ADD COLUMN IF NOT EXISTS team_leader_id uuid REFERENCES team_leaders(id);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_id ON companies(team_leader_id);

-- Update companies policies to allow team leaders to manage their companies
CREATE POLICY "Team leaders can manage their companies"
ON companies
FOR ALL
TO authenticated
USING (
  auth.uid() IN (
    SELECT user_id 
    FROM team_leaders 
    WHERE id = companies.team_leader_id
  )
);