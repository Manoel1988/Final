DELIMITER //

-- Create procedure to safely create company status
CREATE PROCEDURE create_company_status(
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_is_active BOOLEAN,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE new_status_id VARCHAR(36);
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if name is already in use
  IF EXISTS (SELECT 1 FROM company_statuses WHERE name = p_name) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Status name already exists';
  END IF;
  
  -- Generate UUID for new status
  SET new_status_id = UUID();
  
  -- Create status
  INSERT INTO company_statuses (id, name, description, is_active)
  VALUES (new_status_id, p_name, p_description, COALESCE(p_is_active, TRUE));
END//

-- Create procedure to safely update company status
CREATE PROCEDURE update_company_status(
  IN p_status_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_is_active BOOLEAN,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if name is already in use by another status
  IF p_name IS NOT NULL AND EXISTS (
    SELECT 1 FROM company_statuses 
    WHERE name = p_name AND id != p_status_id
  ) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Status name already exists';
  END IF;
  
  -- Update status
  UPDATE company_statuses
  SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_status_id;
END//

-- Create procedure to safely delete company status
CREATE PROCEDURE delete_company_status_safe(
  IN p_status_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE companies_with_status INT;
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if status is used by any companies
  SELECT COUNT(*)
  INTO companies_with_status
  FROM companies
  WHERE status_id = p_status_id;
  
  IF companies_with_status > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot delete status: it is assigned to companies';
  END IF;
  
  -- Delete status
  DELETE FROM company_statuses WHERE id = p_status_id;
END//

-- Create procedure to safely create product
CREATE PROCEDURE create_product(
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_status ENUM('active', 'inactive'),
  IN p_price DECIMAL(10,2),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE new_product_id VARCHAR(36);
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if name is already in use
  IF EXISTS (SELECT 1 FROM products WHERE name = p_name) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Product name already exists';
  END IF;
  
  -- Validate price
  IF p_price < 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Price cannot be negative';
  END IF;
  
  -- Generate UUID for new product
  SET new_product_id = UUID();
  
  -- Create product
  INSERT INTO products (id, name, description, status, price)
  VALUES (
    new_product_id,
    p_name,
    p_description,
    COALESCE(p_status, 'active'),
    COALESCE(p_price, 0)
  );
END//

-- Create procedure to safely update product
CREATE PROCEDURE update_product(
  IN p_product_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_status ENUM('active', 'inactive'),
  IN p_price DECIMAL(10,2),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if name is already in use by another product
  IF p_name IS NOT NULL AND EXISTS (
    SELECT 1 FROM products 
    WHERE name = p_name AND id != p_product_id
  ) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Product name already exists';
  END IF;
  
  -- Validate price
  IF p_price < 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Price cannot be negative';
  END IF;
  
  -- Update product
  UPDATE products
  SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    status = COALESCE(p_status, status),
    price = COALESCE(p_price, price),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_product_id;
END//

-- Create procedure to safely delete product
CREATE PROCEDURE delete_product_safe(
  IN p_product_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Delete product
  DELETE FROM products WHERE id = p_product_id;
END//

DELIMITER ;