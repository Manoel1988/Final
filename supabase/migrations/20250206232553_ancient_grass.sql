/*
  # Add Products Table and Update Roles

  1. Changes
    - Remove role_statuses table
    - Add status column to roles table
    - Create products table with CRUD support

  2. New Tables
    - products
      - id (uuid, primary key)
      - name (text, required)
      - description (text, optional)
      - price (decimal, required)
      - status (text, optional)
      - created_at (timestamp)
      - updated_at (timestamp)
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

-- Create products table
CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price decimal(10,2) NOT NULL,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

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

-- Create updated_at trigger for products
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL ON products TO authenticated;