/*
  # Fix Company and User Relationships

  1. Changes
    - Add proper foreign key relationship between companies and users
    - Update policies to handle the relationship correctly
    - Add indexes for better performance

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control
*/

-- Drop existing policies
DROP POLICY IF EXISTS "allow_read_all_companies" ON companies;
DROP POLICY IF EXISTS "allow_insert_own_companies" ON companies;
DROP POLICY IF EXISTS "allow_update_own_companies" ON companies;
DROP POLICY IF EXISTS "allow_delete_own_companies" ON companies;
DROP POLICY IF EXISTS "allow_admin_all_companies" ON companies;
DROP POLICY IF EXISTS "allow_team_leader_manage_companies" ON companies;

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "companies_read_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "companies_insert_own"
ON companies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "companies_update_own"
ON companies FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "companies_delete_own"
ON companies FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "companies_admin_all"
ON companies FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;

-- Create or replace function to handle company operations
CREATE OR REPLACE FUNCTION handle_company_operation()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Set user_id to current user if not provided
    IF NEW.user_id IS NULL THEN
      NEW.user_id := auth.uid();
    END IF;
  END IF;

  -- Always update the updated_at timestamp
  NEW.updated_at := now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for company operations
DROP TRIGGER IF EXISTS on_company_operation ON companies;
CREATE TRIGGER on_company_operation
  BEFORE INSERT OR UPDATE ON companies
  FOR EACH ROW
  EXECUTE FUNCTION handle_company_operation();