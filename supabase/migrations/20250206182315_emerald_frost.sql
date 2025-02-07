/*
  # Add Products Management

  1. New Tables
    - `products`
      - `id` (uuid, primary key)
      - `name` (text, not null)
      - `description` (text)
      - `is_active` (boolean, default true)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on products table
    - Add policies for authenticated users
*/

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Create policies
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

-- Create updated_at trigger
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();