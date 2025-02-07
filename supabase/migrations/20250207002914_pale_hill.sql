/*
  # Fix Team Leader Relationships

  1. Changes
    - Drop and recreate team leader foreign key constraints with correct names
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
    WHERE constraint_name = 'companies_team_leader_a_id_fkey'
  ) THEN
    ALTER TABLE companies DROP CONSTRAINT companies_team_leader_a_id_fkey;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'companies_team_leader_b_id_fkey'
  ) THEN
    ALTER TABLE companies DROP CONSTRAINT companies_team_leader_b_id_fkey;
  END IF;
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

-- Add foreign key constraints with proper ON DELETE behavior
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

-- Drop existing policies
DROP POLICY IF EXISTS "team_leaders_manage_assigned_companies" ON companies;
DROP POLICY IF EXISTS "team_leaders_manage_companies" ON companies;

-- Create policy for team leaders to manage their assigned companies
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

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;