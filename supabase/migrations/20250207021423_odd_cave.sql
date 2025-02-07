-- Drop existing tables if they exist
DROP TABLE IF EXISTS company_product_history;
DROP TABLE IF EXISTS company_products;
DROP TABLE IF EXISTS companies;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS company_statuses;
DROP TABLE IF EXISTS team_leaders;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;

-- Create users table
CREATE TABLE users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  raw_user_meta_data JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  role_id VARCHAR(36)
);

-- Create roles table
CREATE TABLE roles (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  status ENUM('active', 'inactive') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create role_permissions table
CREATE TABLE role_permissions (
  id VARCHAR(36) PRIMARY KEY,
  role_id VARCHAR(36),
  page VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(role_id, page),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- Create team_leaders table
CREATE TABLE team_leaders (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  name VARCHAR(255) NOT NULL,
  status ENUM('active', 'inactive') DEFAULT 'active',
  squad_name VARCHAR(255) NOT NULL,
  bio TEXT,
  phone VARCHAR(50),
  start_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  end_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create company_statuses table
CREATE TABLE company_statuses (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create companies table
CREATE TABLE companies (
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
CREATE TABLE products (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  status ENUM('active', 'inactive') DEFAULT 'active',
  price DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create company_products table
CREATE TABLE company_products (
  id VARCHAR(36) PRIMARY KEY,
  company_id VARCHAR(36) NOT NULL,
  product_id VARCHAR(36) NOT NULL,
  price_override DECIMAL(10,2),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE(company_id, product_id),
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Create company_product_history table
CREATE TABLE company_product_history (
  id VARCHAR(36) PRIMARY KEY,
  company_product_id VARCHAR(36) NOT NULL,
  company_id VARCHAR(36) NOT NULL,
  product_id VARCHAR(36) NOT NULL,
  price_before DECIMAL(10,2),
  price_after DECIMAL(10,2),
  status_before BOOLEAN,
  status_after BOOLEAN,
  base_price_at_time DECIMAL(10,2),
  changed_by VARCHAR(36),
  change_type ENUM('created', 'price_updated', 'status_updated', 'deleted', 'base_price_changed') NOT NULL,
  change_reason TEXT,
  metadata JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_product_id) REFERENCES company_products(id) ON DELETE CASCADE,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
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
CREATE INDEX idx_company_products_company ON company_products(company_id);
CREATE INDEX idx_company_products_product ON company_products(product_id);
CREATE INDEX idx_company_products_active ON company_products(is_active);
CREATE INDEX idx_company_product_history_company ON company_product_history(company_id);
CREATE INDEX idx_company_product_history_product ON company_product_history(product_id);
CREATE INDEX idx_company_product_history_assignment ON company_product_history(company_product_id);
CREATE INDEX idx_company_product_history_changed_by ON company_product_history(changed_by);
CREATE INDEX idx_company_product_history_created_at ON company_product_history(created_at);
CREATE INDEX idx_company_product_history_change_type ON company_product_history(change_type);

-- Create stored procedures and triggers
DELIMITER //

-- Function to generate UUID
CREATE FUNCTION generate_uuid() 
RETURNS VARCHAR(36)
DETERMINISTIC
BEGIN
  RETURN UUID();
END//

-- Function to check if user is admin
CREATE FUNCTION is_admin(user_id VARCHAR(36))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE is_admin_user BOOLEAN;
  
  SELECT JSON_UNQUOTE(JSON_EXTRACT(raw_user_meta_data, '$.permission')) = 'admin'
  INTO is_admin_user
  FROM users
  WHERE id = user_id;
  
  RETURN COALESCE(is_admin_user, FALSE);
END//

-- Function to validate email format
CREATE FUNCTION is_valid_email(email VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
  RETURN email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';
END//

-- Trigger for company product history tracking
CREATE TRIGGER track_company_product_changes_insert
AFTER INSERT ON company_products
FOR EACH ROW
BEGIN
  DECLARE base_price DECIMAL(10,2);
  
  -- Get current base price
  SELECT price INTO base_price
  FROM products
  WHERE id = NEW.product_id;
  
  -- Track creation
  INSERT INTO company_product_history (
    id,
    company_product_id,
    company_id,
    product_id,
    price_before,
    price_after,
    status_before,
    status_after,
    base_price_at_time,
    changed_by,
    change_type,
    metadata
  ) VALUES (
    generate_uuid(),
    NEW.id,
    NEW.company_id,
    NEW.product_id,
    NULL,
    NEW.price_override,
    NULL,
    NEW.is_active,
    base_price,
    @current_user_id,
    'created',
    JSON_OBJECT(
      'timestamp', NOW(),
      'base_price', base_price
    )
  );
END//

CREATE TRIGGER track_company_product_changes_update
AFTER UPDATE ON company_products
FOR EACH ROW
BEGIN
  DECLARE base_price DECIMAL(10,2);
  
  -- Get current base price
  SELECT price INTO base_price
  FROM products
  WHERE id = NEW.product_id;
  
  -- Track price changes
  IF NEW.price_override <> OLD.price_override OR 
     (NEW.price_override IS NULL AND OLD.price_override IS NOT NULL) OR
     (NEW.price_override IS NOT NULL AND OLD.price_override IS NULL) THEN
    INSERT INTO company_product_history (
      id,
      company_product_id,
      company_id,
      product_id,
      price_before,
      price_after,
      status_before,
      status_after,
      base_price_at_time,
      changed_by,
      change_type,
      metadata
    ) VALUES (
      generate_uuid(),
      NEW.id,
      NEW.company_id,
      NEW.product_id,
      OLD.price_override,
      NEW.price_override,
      NULL,
      NULL,
      base_price,
      @current_user_id,
      'price_updated',
      JSON_OBJECT(
        'timestamp', NOW(),
        'base_price', base_price,
        'price_change', CAST(
          COALESCE(NEW.price_override, base_price) - 
          COALESCE(OLD.price_override, base_price) 
          AS DECIMAL(10,2)
        )
      )
    );
  END IF;
  
  -- Track status changes
  IF NEW.is_active <> OLD.is_active THEN
    INSERT INTO company_product_history (
      id,
      company_product_id,
      company_id,
      product_id,
      price_before,
      price_after,
      status_before,
      status_after,
      base_price_at_time,
      changed_by,
      change_type,
      metadata
    ) VALUES (
      generate_uuid(),
      NEW.id,
      NEW.company_id,
      NEW.product_id,
      NULL,
      NULL,
      OLD.is_active,
      NEW.is_active,
      base_price,
      @current_user_id,
      'status_updated',
      JSON_OBJECT(
        'timestamp', NOW(),
        'base_price', base_price
      )
    );
  END IF;
END//

CREATE TRIGGER track_company_product_changes_delete
BEFORE DELETE ON company_products
FOR EACH ROW
BEGIN
  DECLARE base_price DECIMAL(10,2);
  
  -- Get current base price
  SELECT price INTO base_price
  FROM products
  WHERE id = OLD.product_id;
  
  -- Track deletion
  INSERT INTO company_product_history (
    id,
    company_product_id,
    company_id,
    product_id,
    price_before,
    price_after,
    status_before,
    status_after,
    base_price_at_time,
    changed_by,
    change_type,
    metadata
  ) VALUES (
    generate_uuid(),
    OLD.id,
    OLD.company_id,
    OLD.product_id,
    OLD.price_override,
    NULL,
    OLD.is_active,
    NULL,
    base_price,
    @current_user_id,
    'deleted',
    JSON_OBJECT(
      'timestamp', NOW(),
      'base_price', base_price
    )
  );
END//

DELIMITER ;