/*
  # Fix Users Table RLS Policies

  1. Changes
    - Drop existing policies
    - Add new policies for proper user management
    - Allow users to view all users
    - Allow users to update their own data
    - Allow admins to manage all users
  
  2. Security
    - Enable RLS on users table
    - Add policies for different permission levels
    - Ensure proper access control
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable insert access for service role only" ON users;
DROP POLICY IF EXISTS "Enable update for users based on id" ON users;

-- Create new policies
CREATE POLICY "Users can view all users"
ON users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can update their own metadata"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  -- Only allow updating raw_user_meta_data
  -- Prevent changing id and email
  id = auth.uid() AND
  email = (SELECT email FROM users WHERE id = auth.uid())
);

CREATE POLICY "Admins can manage all users"
ON users
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Update the sync_user_data function to handle permissions properly
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.users (id, email, raw_user_meta_data)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data, jsonb_build_object('permission', 'user'))
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.users
    SET email = NEW.email,
        raw_user_meta_data = COALESCE(NEW.raw_user_meta_data, jsonb_build_object('permission', 'user'))
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ language plpgsql SECURITY DEFINER;