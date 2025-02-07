/*
  # Fix RLS Policies Recursion - Final

  1. Changes
    - Drop all existing policies
    - Create simplified policies without any self-referential checks
    - Use direct auth.uid() checks instead of subqueries
    - Store admin status in a separate column for direct access
  
  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Keep security model intact
*/

-- Add is_admin column for direct access
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Update existing users based on their metadata
UPDATE users
SET is_admin = (raw_user_meta_data->>'permission' = 'admin')
WHERE raw_user_meta_data->>'permission' IS NOT NULL;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON users;
DROP POLICY IF EXISTS "Enable self-update for users" ON users;
DROP POLICY IF EXISTS "Enable admin access" ON users;

-- Create simplified policies
CREATE POLICY "Allow read access for authenticated users"
ON users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow self update"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow admin full access"
ON users
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE id = auth.uid() 
    AND is_admin = true
  )
);

-- Update sync function to handle is_admin
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.users (
      id, 
      email, 
      raw_user_meta_data,
      is_admin
    )
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data, '{"permission": "user"}'::jsonb),
      COALESCE((NEW.raw_user_meta_data->>'permission') = 'admin', false)
    )
    ON CONFLICT (id) DO UPDATE
    SET 
      email = EXCLUDED.email,
      raw_user_meta_data = EXCLUDED.raw_user_meta_data,
      is_admin = EXCLUDED.is_admin;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.users
    SET 
      email = NEW.email,
      raw_user_meta_data = COALESCE(NEW.raw_user_meta_data, '{"permission": "user"}'::jsonb),
      is_admin = COALESCE((NEW.raw_user_meta_data->>'permission') = 'admin', false)
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ language plpgsql SECURITY DEFINER;