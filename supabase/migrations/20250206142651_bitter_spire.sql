/*
  # Team Leaders Schema

  1. New Tables
    - `team_leaders`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references users)
      - `name` (text)
      - `status` (text) - 'active' or 'inactive'
      - `squad_name` (text)
      - `bio` (text)
      - `phone` (text)
      - `start_date` (date)
      - `end_date` (date, nullable)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS
    - Policies for authenticated users
    - Special policies for admins
*/

-- Create team_leaders table
CREATE TABLE IF NOT EXISTS team_leaders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  name text NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
  squad_name text NOT NULL,
  bio text,
  phone text,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE team_leaders ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Team leaders are viewable by authenticated users"
  ON team_leaders
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Team leaders can be managed by admins"
  ON team_leaders
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
CREATE OR REPLACE FUNCTION update_team_leaders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER update_team_leaders_updated_at
  BEFORE UPDATE ON team_leaders
  FOR EACH ROW
  EXECUTE FUNCTION update_team_leaders_updated_at();