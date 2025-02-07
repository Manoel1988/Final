-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  raw_user_meta_data JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  role_id VARCHAR(36)
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  status ENUM('active', 'inactive') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create role_permissions table
CREATE TABLE IF NOT EXISTS role_permissions (
  id VARCHAR(36) PRIMARY KEY,
  role_id VARCHAR(36),
  page VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(role_id, page),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- Create team_leaders table
CREATE TABLE IF NOT EXISTS team_leaders (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  name VARCHAR(255) NOT NULL,
  status ENUM('active', 'inactive') DEFAULT 'active',
  squad_name VARCHAR(255) NOT NULL,
  bio TEXT,
  phone VARCHAR(50),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create company_statuses table
CREATE TABLE IF NOT EXISTS company_statuses (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create companies table
CREATE TABLE IF NOT EXISTS companies (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  legal_name VARCHAR(255) NOT NULL,
  contract_start DATE NOT NULL,
  contract_end DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  user_id VARCHAR(36) NOT NULL,
  status_id VARCHAR(36),
  team_leader_a_id VARCHAR(36),
  team_leader_b_id VARCHAR(36),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (status_id) REFERENCES company_statuses(id) ON DELETE SET NULL,
  FOREIGN KEY (team_leader_a_id) REFERENCES team_leaders(id) ON DELETE SET NULL,
  FOREIGN KEY (team_leader_b_id) REFERENCES team_leaders(id) ON DELETE SET NULL
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  status ENUM('active', 'inactive') DEFAULT 'active',
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role_id);
CREATE INDEX idx_companies_user ON companies(user_id);
CREATE INDEX idx_companies_status ON companies(status_id);
CREATE INDEX idx_companies_team_leader_a ON companies(team_leader_a_id);
CREATE INDEX idx_companies_team_leader_b ON companies(team_leader_b_id);
CREATE INDEX idx_team_leaders_user ON team_leaders(user_id);
CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);