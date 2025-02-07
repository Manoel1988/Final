/*
  # Update user policies for email editing

  1. Changes
    - Allow admins to update any user's email
    - Allow users to update their own records
    - Maintain read access for all authenticated users

  2. Security
    - Only admins can update other users' emails
    - Users can update their own records
    - All authenticated users can read user data
*/

-- Drop existing policies
DROP POLICY IF EXISTS "users_read_all" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "users_admin_all" ON users;

-- Create new policies with email update support
CREATE POLICY "users_read_all"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own records
CREATE POLICY "users_update_own"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Allow admins full access to manage all users
CREATE POLICY "users_admin_all"
ON users FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);