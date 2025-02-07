/*
  # Fix user management and permissions

  1. Changes
    - Drop existing policies
    - Create new simplified policies
    - Add proper user sync function
    - Fix user creation and update functions

  2. Security
    - Enable RLS
    - Add proper permission checks
    - Fix email validation
*/

-- Drop existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "enable_read_access" ON users;
  DROP POLICY IF EXISTS "enable_update_access" ON users;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "enable_read_access"
ON users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "enable_update_access"
ON users FOR UPDATE
TO authenticated
USING (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to validate email
CREATE OR REPLACE FUNCTION is_valid_email(email text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$;

-- Create function to safely update user data
CREATE OR REPLACE FUNCTION update_user_data(
  target_user_id uuid,
  new_email text,
  new_role_id uuid,
  new_metadata jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate email format
  IF NOT is_valid_email(new_email) THEN
    RAISE EXCEPTION 'Invalid email format';
  END IF;

  -- Check if the user making the request is an admin or the target user
  IF (auth.uid() = target_user_id) OR EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    -- Check if email is already in use
    IF EXISTS (
      SELECT 1 FROM auth.users
      WHERE email = new_email
      AND id != target_user_id
    ) THEN
      RAISE EXCEPTION 'Email already in use';
    END IF;

    -- Update auth.users
    UPDATE auth.users
    SET 
      email = new_email,
      raw_user_meta_data = new_metadata,
      email_confirmed_at = now()
    WHERE id = target_user_id;
    
    -- Update public.users
    UPDATE users
    SET 
      email = new_email,
      raw_user_meta_data = new_metadata,
      role_id = new_role_id,
      updated_at = now()
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;

-- Update the sync function to handle new users properly
CREATE OR REPLACE FUNCTION handle_user_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Ensure raw_user_meta_data exists and has permission
  IF NEW.raw_user_meta_data IS NULL OR NEW.raw_user_meta_data->>'permission' IS NULL THEN
    NEW.raw_user_meta_data := jsonb_build_object('permission', 'user');
  END IF;

  -- Insert or update the user record
  INSERT INTO public.users (
    id,
    email,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data,
    COALESCE(NEW.created_at, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error details if needed
    RAISE NOTICE 'Error in handle_user_sync: %', SQLERRM;
    RETURN NEW;
END;
$$;