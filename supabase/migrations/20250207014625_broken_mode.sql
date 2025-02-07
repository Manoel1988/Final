-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  raw_user_meta_data jsonb DEFAULT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  role_id uuid
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create role_permissions table
CREATE TABLE IF NOT EXISTS role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid,
  page text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(role_id, page),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- Create team_leaders table
CREATE TABLE IF NOT EXISTS team_leaders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  status text DEFAULT 'active',
  squad_name text NOT NULL,
  bio text,
  phone text,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create company_statuses table
CREATE TABLE IF NOT EXISTS company_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create companies table
CREATE TABLE IF NOT EXISTS companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  legal_name text NOT NULL,
  contract_start date NOT NULL,
  contract_end date NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  user_id uuid NOT NULL,
  status_id uuid,
  team_leader_a_id uuid,
  team_leader_b_id uuid,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (status_id) REFERENCES company_statuses(id) ON DELETE SET NULL,
  FOREIGN KEY (team_leader_a_id) REFERENCES team_leaders(id) ON DELETE SET NULL,
  FOREIGN KEY (team_leader_b_id) REFERENCES team_leaders(id) ON DELETE SET NULL
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  status text DEFAULT 'active',
  price decimal(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_companies_user ON companies(user_id);
CREATE INDEX IF NOT EXISTS idx_companies_status ON companies(status_id);
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX IF NOT EXISTS idx_companies_team_leader_b ON companies(team_leader_b_id);
CREATE INDEX IF NOT EXISTS idx_team_leaders_user ON team_leaders(user_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER set_timestamp_users
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_roles
  BEFORE UPDATE ON roles
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_team_leaders
  BEFORE UPDATE ON team_leaders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_company_statuses
  BEFORE UPDATE ON company_statuses
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_companies
  BEFORE UPDATE ON companies
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_products
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();