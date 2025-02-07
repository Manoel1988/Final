/*
  # Update database schema for user permissions and companies

  1. Changes
    - Add permission field to users table
    - Update companies table structure
    - Add appropriate policies

  2. Security
    - Enable RLS on all tables
    - Add policies for user access control
*/

-- Add permission field to auth.users metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, raw_user_meta_data)
  VALUES (
    NEW.id,
    NEW.email,
    CASE 
      WHEN NEW.raw_user_meta_data->>'permission' IS NULL 
      THEN jsonb_set(COALESCE(NEW.raw_user_meta_data, '{}'::jsonb), '{permission}', '"user"')
      ELSE NEW.raw_user_meta_data
    END
  );
  RETURN NEW;
END;
$$ language plpgsql security definer;

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update existing users to have default permission if not set
UPDATE auth.users
SET raw_user_meta_data = 
  CASE 
    WHEN raw_user_meta_data->>'permission' IS NULL 
    THEN jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{permission}', '"user"')
    ELSE raw_user_meta_data
  END
WHERE raw_user_meta_data->>'permission' IS NULL;

-- Update companies table policies
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- Allow users to view all companies
CREATE POLICY "Users can view all companies"
ON public.companies
FOR SELECT
TO authenticated
USING (true);

-- Allow users to manage their own companies
CREATE POLICY "Users can insert their own companies"
ON public.companies
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own companies"
ON public.companies
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own companies"
ON public.companies
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Allow admins to manage all companies
CREATE POLICY "Admins can manage all companies"
ON public.companies
FOR ALL
TO authenticated
USING (
  (SELECT (raw_user_meta_data->>'permission')::text = 'admin' 
   FROM auth.users 
   WHERE id = auth.uid())
);