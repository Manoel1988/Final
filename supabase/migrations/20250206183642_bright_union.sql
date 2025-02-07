-- Drop existing policies
DROP POLICY IF EXISTS "companies_read_all" ON companies;
DROP POLICY IF EXISTS "companies_insert_own" ON companies;
DROP POLICY IF EXISTS "companies_update_own" ON companies;
DROP POLICY IF EXISTS "companies_delete_own" ON companies;
DROP POLICY IF EXISTS "companies_admin_all" ON companies;

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Create new policies with proper permissions
CREATE POLICY "companies_read_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "companies_insert_own"
ON companies FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

CREATE POLICY "companies_update_own"
ON companies FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

CREATE POLICY "companies_delete_own"
ON companies FOR DELETE
TO authenticated
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to handle company operations
CREATE OR REPLACE FUNCTION handle_company_operation()
RETURNS TRIGGER AS $$
BEGIN
  -- For new companies
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

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;