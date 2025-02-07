/*
  # Fix users table policies

  1. Changes
    - Drop existing policies
    - Create new policies that allow:
      - All authenticated users to read all users
      - Users to update their own data
      - Users to delete their own data
      - Admin users to manage all users

  2. Security
    - Enable RLS
    - Policies ensure proper access control
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can read their own data" ON users;
  DROP POLICY IF EXISTS "Admin can manage all users" ON users;
  DROP POLICY IF EXISTS "Users can read all users" ON users;
  DROP POLICY IF EXISTS "Users can update their own data" ON users;
  DROP POLICY IF EXISTS "Users can delete their own data" ON users;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create new policies
CREATE POLICY "Users can read all users"
  ON users
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own data"
  ON users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can delete their own data"
  ON users
  FOR DELETE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admin can manage all users"
  ON users
  FOR ALL
  TO authenticated
  USING (
    COALESCE((auth.jwt() ->> 'role')::text, 'authenticated') = 'admin'
  );