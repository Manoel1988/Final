/*
  # Users Management Schema Update

  1. Tables
    - Ensure users table exists with proper structure
    - Add necessary columns and constraints

  2. Security
    - Enable RLS
    - Update policies for better access control

  3. Functions and Triggers
    - Add/update timestamp management
    - Sync with auth.users
*/

-- Create users table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    CREATE TABLE users (
      id uuid PRIMARY KEY REFERENCES auth.users,
      email text UNIQUE NOT NULL,
      raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );
  END IF;
END $$;

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
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

-- Create or replace function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing trigger if it exists
DO $$ 
BEGIN
  DROP TRIGGER IF EXISTS update_users_updated_at ON users;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create trigger for updated_at
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Create or replace function to sync auth.users with users table
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.users (id, email, raw_user_meta_data)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data);
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.users
    SET email = NEW.email,
        raw_user_meta_data = NEW.raw_user_meta_data
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing trigger if it exists
DO $$ 
BEGIN
  DROP TRIGGER IF EXISTS sync_auth_users ON auth.users;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

-- Create trigger for syncing users
CREATE TRIGGER sync_auth_users
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_data();