-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_for_all" ON companies;
DROP POLICY IF EXISTS "enable_insert_for_authenticated" ON companies;
DROP POLICY IF EXISTS "enable_update_for_owners_and_admins" ON companies;
DROP POLICY IF EXISTS "enable_delete_for_owners_and_admins" ON companies;

-- Enable RLS
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Create new simplified policies
CREATE POLICY "allow_read_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "allow_write_own"
ON companies FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_update_own"
ON companies FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "allow_delete_own"
ON companies FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Create admin policies
CREATE POLICY "allow_admin_all"
ON companies FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to check database connection
CREATE OR REPLACE FUNCTION check_database_connection()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;

-- Create function to validate user permissions
CREATE OR REPLACE FUNCTION validate_user_permissions(user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'is_valid', true,
    'is_admin', (raw_user_meta_data->>'permission' = 'admin'),
    'user_id', id,
    'email', email
  )
  INTO result
  FROM auth.users
  WHERE id = user_id;
  
  RETURN COALESCE(result, jsonb_build_object('is_valid', false));
END;
$$;