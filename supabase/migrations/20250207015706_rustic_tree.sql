DELIMITER //

-- Create function to check if a user has a specific permission
CREATE FUNCTION has_permission(user_id VARCHAR(36), required_page VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE has_access BOOLEAN;
  
  SELECT EXISTS (
    SELECT 1
    FROM users u
    JOIN roles r ON u.role_id = r.id
    JOIN role_permissions rp ON r.id = rp.role_id
    WHERE u.id = user_id
    AND r.status = 'active'
    AND rp.page = required_page
  ) INTO has_access;
  
  RETURN COALESCE(has_access, FALSE);
END//

-- Create procedure to safely create role with permissions
CREATE PROCEDURE create_role_with_permissions(
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_status ENUM('active', 'inactive'),
  IN p_permissions JSON,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE new_role_id VARCHAR(36);
  DECLARE i INT DEFAULT 0;
  DECLARE n_permissions INT;
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Generate UUID for new role
  SET new_role_id = UUID();
  
  -- Create role
  INSERT INTO roles (id, name, description, status)
  VALUES (new_role_id, p_name, p_description, p_status);
  
  -- Add permissions
  SET n_permissions = JSON_LENGTH(p_permissions);
  
  WHILE i < n_permissions DO
    INSERT INTO role_permissions (id, role_id, page)
    VALUES (
      UUID(),
      new_role_id,
      JSON_UNQUOTE(JSON_EXTRACT(p_permissions, CONCAT('$[', i, ']')))
    );
    SET i = i + 1;
  END WHILE;
END//

-- Create procedure to safely update role with permissions
CREATE PROCEDURE update_role_with_permissions(
  IN p_role_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_description TEXT,
  IN p_status ENUM('active', 'inactive'),
  IN p_permissions JSON,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE n_permissions INT;
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Start transaction
  START TRANSACTION;
  
  -- Update role
  UPDATE roles
  SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    status = COALESCE(p_status, status),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_role_id;
  
  -- Update permissions if provided
  IF p_permissions IS NOT NULL THEN
    -- Delete existing permissions
    DELETE FROM role_permissions WHERE role_id = p_role_id;
    
    -- Add new permissions
    SET n_permissions = JSON_LENGTH(p_permissions);
    
    WHILE i < n_permissions DO
      INSERT INTO role_permissions (id, role_id, page)
      VALUES (
        UUID(),
        p_role_id,
        JSON_UNQUOTE(JSON_EXTRACT(p_permissions, CONCAT('$[', i, ']')))
      );
      SET i = i + 1;
    END WHILE;
  END IF;
  
  -- Commit transaction
  COMMIT;
END//

-- Create procedure to safely delete role
CREATE PROCEDURE delete_role_safe(
  IN p_role_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE users_with_role INT;
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if role is assigned to any users
  SELECT COUNT(*)
  INTO users_with_role
  FROM users
  WHERE role_id = p_role_id;
  
  IF users_with_role > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot delete role: it is assigned to users';
  END IF;
  
  -- Delete role (permissions will be deleted by foreign key cascade)
  DELETE FROM roles WHERE id = p_role_id;
END//

-- Create function to get role permissions
CREATE FUNCTION get_role_permissions(role_id VARCHAR(36))
RETURNS JSON
READS SQL DATA
BEGIN
  DECLARE permissions JSON;
  
  SELECT JSON_ARRAYAGG(page)
  INTO permissions
  FROM role_permissions
  WHERE role_id = role_id;
  
  RETURN COALESCE(permissions, JSON_ARRAY());
END//

-- Create procedure to assign role to user
CREATE PROCEDURE assign_role_to_user(
  IN p_user_id VARCHAR(36),
  IN p_role_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if role exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM roles
    WHERE id = p_role_id
    AND status = 'active'
  ) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Invalid or inactive role';
  END IF;
  
  -- Update user's role
  UPDATE users
  SET role_id = p_role_id
  WHERE id = p_user_id;
END//

DELIMITER ;