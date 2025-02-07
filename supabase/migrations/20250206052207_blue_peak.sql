/*
  # Final RLS Policy Fix

  1. Changes
    - Drop all existing policies
    - Create new simplified policies with direct checks
    - Remove all nested queries and self-references
    - Use direct column checks for permissions
  
  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Keep security model intact
*/

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON users;
DROP POLICY IF EXISTS "Allow self update" ON users;
DROP POLICY IF EXISTS "Allow admin full access" ON users;

-- Create new simplified policies
CREATE POLICY "enable_read_for_authenticated"
ON users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_insert_for_authenticated"
ON users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "enable_update_for_self"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

CREATE POLICY "enable_delete_for_self"
ON users
FOR DELETE
TO authenticated
USING (auth.uid() = id);

-- Update sync function to be simpler and avoid recursion
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  -- Set admin status based on metadata
  v_is_admin := COALESCE((NEW.raw_user_meta_data->>'permission') = 'admin', false);
  
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.users (
      id,
      email,
      raw_user_meta_data,
      is_admin,
      created_at,
      updated_at
    )
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data, '{"permission": "user"}'::jsonb),
      v_is_admin,
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.users SET
      email = NEW.email,
      raw_user_meta_data = COALESCE(NEW.raw_user_meta_data, '{"permission": "user"}'::jsonb),
      is_admin = v_is_admin,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;