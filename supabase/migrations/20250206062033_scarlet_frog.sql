-- Drop existing policies
DROP POLICY IF EXISTS "enable_read_for_authenticated" ON users;
DROP POLICY IF EXISTS "enable_update_for_self_and_admin" ON users;

-- Create new policies with proper permissions
CREATE POLICY "allow_read_all_users"
ON users FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own metadata and admins to update anyone's metadata
CREATE POLICY "allow_update_user_metadata"
ON users FOR UPDATE
TO authenticated
USING (
  -- User can update their own record OR user is an admin
  auth.uid() = id OR
  EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'permission' = 'admin'
  )
)
WITH CHECK (
  -- Same condition for the check
  auth.uid() = id OR
  EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE id = auth.uid() 
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Update the sync function to handle permissions properly
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
    raw_user_meta_data = NEW.raw_user_meta_data,
    updated_at = now();

  RETURN NEW;
END;
$$;