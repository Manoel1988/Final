-- Ensure RLS is enabled
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "allow_read_all" ON companies;
DROP POLICY IF EXISTS "allow_write_own" ON companies;
DROP POLICY IF EXISTS "allow_update_own" ON companies;
DROP POLICY IF EXISTS "allow_delete_own" ON companies;
DROP POLICY IF EXISTS "allow_admin_all" ON companies;

-- Create new policies with proper admin checks
CREATE POLICY "enable_read_for_all"
ON companies FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_write_for_admins_and_owners"
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

CREATE POLICY "enable_update_for_admins_and_owners"
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

CREATE POLICY "enable_delete_for_admins_and_owners"
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

-- Create helper function to check admin status
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  );
$$;

-- Create helper function to validate company access
CREATE OR REPLACE FUNCTION can_access_company(company_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM companies c
    WHERE c.id = company_id
    AND (
      c.user_id = auth.uid() OR
      EXISTS (
        SELECT 1 FROM auth.users
        WHERE id = auth.uid()
        AND raw_user_meta_data->>'permission' = 'admin'
      )
    )
  );
END;
$$;