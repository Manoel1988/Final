-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_for_all" ON users;
DROP POLICY IF EXISTS "enable_update_for_own_record" ON users;

-- Create new policies
CREATE POLICY "enable_read_for_all"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own records and admins to update any record
CREATE POLICY "enable_update_for_admins_and_self"
ON users FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR 
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  auth.uid() = id OR 
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);