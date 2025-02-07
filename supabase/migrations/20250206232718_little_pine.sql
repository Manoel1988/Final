/*
  # Update Roles and Products Schema

  1. Changes
    - Remove role_statuses table
    - Add status column to roles table
    - Update products table schema if needed

  2. Security
    - Maintain RLS policies for products table
*/

-- Drop role_statuses table and related foreign key
ALTER TABLE roles DROP COLUMN IF EXISTS status_id;
DROP TABLE IF EXISTS role_statuses;

-- Add status column to roles
ALTER TABLE roles 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';

-- Update existing roles to have 'active' status
UPDATE roles 
SET status = 'active' 
WHERE status IS NULL;

-- Update products table schema if needed
DO $$ 
BEGIN
  -- Add price column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'price'
  ) THEN
    ALTER TABLE products ADD COLUMN price decimal(10,2) NOT NULL DEFAULT 0;
  END IF;

  -- Add status column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'status'
  ) THEN
    ALTER TABLE products ADD COLUMN status text DEFAULT 'active';
  END IF;

  -- Add description column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'description'
  ) THEN
    ALTER TABLE products ADD COLUMN description text;
  END IF;
END $$;

-- Ensure RLS is enabled
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Products are viewable by authenticated users" ON products;
  DROP POLICY IF EXISTS "Products can be managed by admins" ON products;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Create policies for products
CREATE POLICY "Products are viewable by authenticated users"
  ON products
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Products can be managed by admins"
  ON products
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );

-- Create updated_at trigger if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_products_updated_at'
  ) THEN
    CREATE TRIGGER update_products_updated_at
      BEFORE UPDATE ON products
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

-- Grant necessary permissions
GRANT ALL ON products TO authenticated;