/*
  # Add roles and permissions management

  1. New Tables
    - `roles`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `description` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `role_permissions`
      - `id` (uuid, primary key)
      - `role_id` (uuid, references roles)
      - `page` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for admin access
*/

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create role_permissions table
CREATE TABLE IF NOT EXISTS role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid REFERENCES roles(id) ON DELETE CASCADE,
  page text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(role_id, page)
);

-- Enable RLS
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

-- Create policies for roles table
CREATE POLICY "Roles are viewable by authenticated users"
  ON roles
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Roles can be managed by admins"
  ON roles
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );

-- Create policies for role_permissions table
CREATE POLICY "Role permissions are viewable by authenticated users"
  ON role_permissions
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Role permissions can be managed by admins"
  ON role_permissions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );

-- Add role_id to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS role_id uuid REFERENCES roles(id);

-- Create updated_at trigger for roles
CREATE OR REPLACE FUNCTION update_roles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER update_roles_updated_at
  BEFORE UPDATE ON roles
  FOR EACH ROW
  EXECUTE FUNCTION update_roles_updated_at();