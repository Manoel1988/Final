/*
  # Add status management for companies and roles

  1. New Tables
    - `company_statuses`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `description` (text)
      - `is_active` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `role_statuses`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `description` (text)
      - `is_active` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Changes
    - Add status_id to companies table
    - Add status_id to roles table
    
  3. Security
    - Enable RLS on new tables
    - Add policies for admin management
*/

-- Create company_statuses table
CREATE TABLE company_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create role_statuses table
CREATE TABLE role_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add status_id to companies table
ALTER TABLE companies 
ADD COLUMN status_id uuid REFERENCES company_statuses(id);

-- Add status_id to roles table
ALTER TABLE roles 
ADD COLUMN status_id uuid REFERENCES role_statuses(id);

-- Enable RLS
ALTER TABLE company_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_statuses ENABLE ROW LEVEL SECURITY;

-- Create policies for company_statuses
CREATE POLICY "Company statuses are viewable by authenticated users"
  ON company_statuses
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Company statuses can be managed by admins"
  ON company_statuses
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );

-- Create policies for role_statuses
CREATE POLICY "Role statuses are viewable by authenticated users"
  ON role_statuses
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Role statuses can be managed by admins"
  ON role_statuses
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND raw_user_meta_data->>'permission' = 'admin'
    )
  );

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER update_company_statuses_updated_at
  BEFORE UPDATE ON company_statuses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_role_statuses_updated_at
  BEFORE UPDATE ON role_statuses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();