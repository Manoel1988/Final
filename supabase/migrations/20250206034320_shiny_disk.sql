/*
  # User Management Schema

  1. New Tables
    - `users`
      - `id` (uuid, primary key) - References auth.users
      - `email` (text, unique)
      - `raw_user_meta_data` (jsonb) - Stores user role and other metadata
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `users` table
    - Add policies for:
      - Admin can manage all users
      - Users can read their own data
*/

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users,
  email text UNIQUE NOT NULL,
  raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Admin can manage all users"
  ON users
  TO authenticated
  USING (auth.jwt() ->> 'email' = 'suporte@universidadedevendas.com.br');

CREATE POLICY "Users can read their own data"
  ON users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updated_at
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to sync auth.users with users table
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

-- Create trigger for syncing users
CREATE TRIGGER sync_auth_users
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_data();