/*
  # Fix Team Leader Relationships

  1. Changes
    - Drop and recreate team leader foreign key constraints
    - Add proper indexes
    - Update RLS policies
    - Add helper functions for relationship management

  2. Security
    - Enable RLS
    - Add policies for team leader access
*/

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

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_companies_team_leader_a;
DROP INDEX IF EXISTS idx_companies_team_leader_b;

-- Add team leader columns to companies table
ALTER TABLE companies
ADD COLUMN IF NOT EXISTS team_leader_a_id uuid REFERENCES team_leaders(id),
ADD COLUMN IF NOT EXISTS team_leader_b_id uuid REFERENCES team_leaders(id);

-- Create indexes for better performance
CREATE INDEX idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX idx_companies_team_leader_b ON companies(team_leader_b_id);

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

-- Create helper function to check if user is team leader for a company
CREATE OR REPLACE FUNCTION is_team_leader_for_company(company_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM companies c
    JOIN team_leaders tl ON (
      tl.id = c.team_leader_a_id OR 
      tl.id = c.team_leader_b_id
    )
    WHERE c.id = company_id
    AND tl.user_id = auth.uid()
  );
$$;

-- Update policies to allow team leaders to manage their assigned companies
CREATE POLICY "team_leaders_manage_assigned_companies"
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