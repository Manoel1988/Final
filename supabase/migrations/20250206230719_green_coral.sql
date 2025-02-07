-- Drop existing policies
DROP POLICY IF EXISTS "companies_read_all" ON companies;
DROP POLICY IF EXISTS "companies_insert_own" ON companies;
DROP POLICY IF EXISTS "companies_update_own" ON companies;
DROP POLICY IF EXISTS "companies_delete_own" ON companies;
DROP POLICY IF EXISTS "companies_admin_all" ON companies;

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Create new policies for companies
CREATE POLICY "enable_read_for_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_insert_for_authenticated"
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

CREATE POLICY "enable_update_for_owners_and_admins"
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

CREATE POLICY "enable_delete_for_owners_and_admins"
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
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
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
$$;

-- Create trigger for company operations
DROP TRIGGER IF EXISTS on_company_operation ON companies;
CREATE TRIGGER on_company_operation
  BEFORE INSERT OR UPDATE ON companies
  FOR EACH ROW
  EXECUTE FUNCTION handle_company_operation();

-- Grant necessary permissions
GRANT ALL ON companies TO authenticated;

-- Create function to safely manage company data
CREATE OR REPLACE FUNCTION manage_company(
  operation text,
  company_id uuid DEFAULT NULL,
  company_data jsonb DEFAULT NULL
)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  result jsonb;
  is_admin boolean;
  current_user_id uuid;
BEGIN
  -- Get current user ID
  current_user_id := auth.uid();
  
  -- Check if user is admin
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = current_user_id
    AND raw_user_meta_data->>'permission' = 'admin'
  ) INTO is_admin;

  -- Handle different operations
  CASE operation
    WHEN 'CREATE' THEN
      IF company_data IS NULL THEN
        RAISE EXCEPTION 'Company data is required for creation';
      END IF;

      INSERT INTO companies (
        name,
        legal_name,
        contract_start,
        contract_end,
        user_id
      )
      VALUES (
        company_data->>'name',
        company_data->>'legal_name',
        (company_data->>'contract_start')::date,
        (company_data->>'contract_end')::date,
        current_user_id
      )
      RETURNING to_jsonb(companies.*) INTO result;

    WHEN 'UPDATE' THEN
      IF company_id IS NULL OR company_data IS NULL THEN
        RAISE EXCEPTION 'Company ID and data are required for update';
      END IF;

      -- Check if user has permission to update
      IF NOT is_admin AND NOT EXISTS (
        SELECT 1 FROM companies
        WHERE id = company_id
        AND user_id = current_user_id
      ) THEN
        RAISE EXCEPTION 'Permission denied';
      END IF;

      UPDATE companies
      SET
        name = COALESCE(company_data->>'name', name),
        legal_name = COALESCE(company_data->>'legal_name', legal_name),
        contract_start = COALESCE((company_data->>'contract_start')::date, contract_start),
        contract_end = COALESCE((company_data->>'contract_end')::date, contract_end),
        updated_at = now()
      WHERE id = company_id
      RETURNING to_jsonb(companies.*) INTO result;

    WHEN 'DELETE' THEN
      IF company_id IS NULL THEN
        RAISE EXCEPTION 'Company ID is required for deletion';
      END IF;

      -- Check if user has permission to delete
      IF NOT is_admin AND NOT EXISTS (
        SELECT 1 FROM companies
        WHERE id = company_id
        AND user_id = current_user_id
      ) THEN
        RAISE EXCEPTION 'Permission denied';
      END IF;

      DELETE FROM companies
      WHERE id = company_id
      RETURNING to_jsonb(companies.*) INTO result;

    ELSE
      RAISE EXCEPTION 'Invalid operation';
  END CASE;

  RETURN result;
END;
$$;