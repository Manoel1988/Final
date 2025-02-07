/*
  # Final RLS and User Sync Fix

  1. Changes
    - Simplify RLS policies to basic CRUD operations
    - Fix user synchronization
    - Add proper admin role handling
    - Ensure proper data consistency
  
  2. Security
    - Maintain proper access control
    - Allow user self-management
    - Enable admin capabilities
    - Prevent unauthorized access
*/

-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_for_authenticated" ON users;
DROP POLICY IF EXISTS "enable_insert_for_authenticated" ON users;
DROP POLICY IF EXISTS "enable_update_for_self" ON users;
DROP POLICY IF EXISTS "enable_delete_for_self" ON users;

-- Create new simplified policies
CREATE POLICY "users_read_access"
ON users
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "users_insert_access"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow insert only if the user is an admin or inserting their own record
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (auth.users.raw_user_meta_data->>'permission')::text = 'admin'
  )
);

CREATE POLICY "users_update_access"
ON users
FOR UPDATE
TO authenticated
USING (
  -- Allow update only if the user is an admin or updating their own record
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (auth.users.raw_user_meta_data->>'permission')::text = 'admin'
  )
)
WITH CHECK (
  -- Same condition for the new row
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (auth.users.raw_user_meta_data->>'permission')::text = 'admin'
  )
);

CREATE POLICY "users_delete_access"
ON users
FOR DELETE
TO authenticated
USING (
  -- Allow delete only if the user is an admin or deleting their own record
  auth.uid() = id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE auth.users.id = auth.uid()
    AND (auth.users.raw_user_meta_data->>'permission')::text = 'admin'
  )
);

-- Update the sync function to handle permissions properly
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
  -- For inserts and updates, ensure we have the proper metadata
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    -- Ensure we have proper metadata with permission
    IF NEW.raw_user_meta_data IS NULL OR NEW.raw_user_meta_data->>'permission' IS NULL THEN
      NEW.raw_user_meta_data := jsonb_set(
        COALESCE(NEW.raw_user_meta_data, '{}'::jsonb),
        '{permission}',
        '"user"'
      );
    END IF;

    -- Perform the upsert with proper permission handling
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
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;