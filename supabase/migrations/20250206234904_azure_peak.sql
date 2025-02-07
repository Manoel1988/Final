-- Drop role_statuses table and related foreign key if they exist
DO $$ 
BEGIN
  -- Remove foreign key from roles table
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'roles_status_id_fkey'
  ) THEN
    ALTER TABLE roles DROP CONSTRAINT roles_status_id_fkey;
  END IF;

  -- Drop status_id column from roles
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'roles' AND column_name = 'status_id'
  ) THEN
    ALTER TABLE roles DROP COLUMN status_id;
  END IF;

  -- Drop role_statuses table
  DROP TABLE IF EXISTS role_statuses;
END $$;

-- Add status column to roles if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'roles' AND column_name = 'status'
  ) THEN
    ALTER TABLE roles ADD COLUMN status text DEFAULT 'active';
  END IF;
END $$;

-- Update existing roles to have 'active' status
UPDATE roles 
SET status = 'active' 
WHERE status IS NULL;

-- Update products table schema
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