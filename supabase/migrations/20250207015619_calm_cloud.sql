-- Create function to check if a user is an admin
DELIMITER //

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

-- Create function to validate email format
CREATE FUNCTION is_valid_email(email VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
  RETURN email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END//

-- Create procedure to safely update user data
CREATE PROCEDURE update_user_data(
  IN p_user_id VARCHAR(36),
  IN p_email VARCHAR(255),
  IN p_role_id VARCHAR(36),
  IN p_metadata JSON,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE is_admin_user BOOLEAN;
  DECLARE email_exists BOOLEAN;
  
  -- Check if current user is admin or updating their own record
  SET is_admin_user = is_admin(p_current_user_id);
  
  IF NOT (is_admin_user OR p_current_user_id = p_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if email is valid
  IF p_email IS NOT NULL AND NOT is_valid_email(p_email) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Invalid email format';
  END IF;
  
  -- Check if email is already in use by another user
  IF p_email IS NOT NULL THEN
    SELECT COUNT(*) > 0
    INTO email_exists
    FROM users
    WHERE email = p_email AND id != p_user_id;
    
    IF email_exists THEN
      SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Email already in use';
    END IF;
  END IF;
  
  -- Update user data
  UPDATE users
  SET
    email = COALESCE(p_email, email),
    role_id = COALESCE(p_role_id, role_id),
    raw_user_meta_data = COALESCE(p_metadata, raw_user_meta_data),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;
END//

-- Create procedure to safely delete user
CREATE PROCEDURE delete_user_safe(
  IN p_user_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE is_admin_user BOOLEAN;
  
  -- Check if current user is admin
  SET is_admin_user = is_admin(p_current_user_id);
  
  IF NOT is_admin_user THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Delete user
  DELETE FROM users WHERE id = p_user_id;
END//

-- Create function to get active companies count for a team leader
CREATE FUNCTION get_team_leader_active_companies_count(team_leader_id VARCHAR(36))
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE company_count INT;
  
  SELECT COUNT(DISTINCT c.id)
  INTO company_count
  FROM companies c
  JOIN company_statuses cs ON c.status_id = cs.id
  WHERE cs.is_active = TRUE
  AND (c.team_leader_a_id = team_leader_id OR c.team_leader_b_id = team_leader_id);
  
  RETURN COALESCE(company_count, 0);
END//

-- Create procedure to safely update company data
CREATE PROCEDURE update_company_data(
  IN p_company_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_legal_name VARCHAR(255),
  IN p_contract_start DATE,
  IN p_contract_end DATE,
  IN p_status_id VARCHAR(36),
  IN p_team_leader_a_id VARCHAR(36),
  IN p_team_leader_b_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE is_admin_user BOOLEAN;
  DECLARE is_owner BOOLEAN;
  DECLARE is_team_leader BOOLEAN;
  
  -- Check permissions
  SET is_admin_user = is_admin(p_current_user_id);
  
  SELECT user_id = p_current_user_id
  INTO is_owner
  FROM companies
  WHERE id = p_company_id;
  
  SELECT EXISTS (
    SELECT 1 FROM team_leaders
    WHERE user_id = p_current_user_id
    AND id IN (
      SELECT team_leader_a_id FROM companies WHERE id = p_company_id
      UNION
      SELECT team_leader_b_id FROM companies WHERE id = p_company_id
    )
  ) INTO is_team_leader;
  
  IF NOT (is_admin_user OR is_owner OR is_team_leader) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Update company data
  UPDATE companies
  SET
    name = COALESCE(p_name, name),
    legal_name = COALESCE(p_legal_name, legal_name),
    contract_start = COALESCE(p_contract_start, contract_start),
    contract_end = COALESCE(p_contract_end, contract_end),
    status_id = COALESCE(p_status_id, status_id),
    team_leader_a_id = COALESCE(p_team_leader_a_id, team_leader_a_id),
    team_leader_b_id = COALESCE(p_team_leader_b_id, team_leader_b_id),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_company_id;
END//

DELIMITER ;