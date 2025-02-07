DELIMITER //

-- Create procedure to safely create team leader
CREATE PROCEDURE create_team_leader(
  IN p_user_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_squad_name VARCHAR(255),
  IN p_bio TEXT,
  IN p_phone VARCHAR(50),
  IN p_start_date DATE,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE new_leader_id VARCHAR(36);
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'User not found';
  END IF;
  
  -- Check if user is already a team leader
  IF EXISTS (SELECT 1 FROM team_leaders WHERE user_id = p_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'User is already a team leader';
  END IF;
  
  -- Generate UUID for new team leader
  SET new_leader_id = UUID();
  
  -- Create team leader
  INSERT INTO team_leaders (
    id, user_id, name, status, squad_name, 
    bio, phone, start_date
  )
  VALUES (
    new_leader_id,
    p_user_id,
    p_name,
    'active',
    p_squad_name,
    p_bio,
    p_phone,
    COALESCE(p_start_date, CURRENT_DATE)
  );
END//

-- Create procedure to safely update team leader
CREATE PROCEDURE update_team_leader(
  IN p_leader_id VARCHAR(36),
  IN p_name VARCHAR(255),
  IN p_status ENUM('active', 'inactive'),
  IN p_squad_name VARCHAR(255),
  IN p_bio TEXT,
  IN p_phone VARCHAR(50),
  IN p_start_date DATE,
  IN p_end_date DATE,
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Validate dates
  IF p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'End date cannot be before start date';
  END IF;
  
  -- Update team leader
  UPDATE team_leaders
  SET
    name = COALESCE(p_name, name),
    status = COALESCE(p_status, status),
    squad_name = COALESCE(p_squad_name, squad_name),
    bio = COALESCE(p_bio, bio),
    phone = COALESCE(p_phone, phone),
    start_date = COALESCE(p_start_date, start_date),
    end_date = p_end_date,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_leader_id;
END//

-- Create procedure to safely delete team leader
CREATE PROCEDURE delete_team_leader_safe(
  IN p_leader_id VARCHAR(36),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  DECLARE companies_with_leader INT;
  
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if team leader has active companies
  SELECT COUNT(*)
  INTO companies_with_leader
  FROM companies c
  JOIN company_statuses cs ON c.status_id = cs.id
  WHERE cs.is_active = TRUE
  AND (c.team_leader_a_id = p_leader_id OR c.team_leader_b_id = p_leader_id);
  
  IF companies_with_leader > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot delete team leader: they have active companies assigned';
  END IF;
  
  -- Delete team leader
  DELETE FROM team_leaders WHERE id = p_leader_id;
END//

-- Create function to get team leader details with company count
CREATE FUNCTION get_team_leader_details(leader_id VARCHAR(36))
RETURNS JSON
READS SQL DATA
BEGIN
  DECLARE result JSON;
  
  SELECT JSON_OBJECT(
    'id', tl.id,
    'name', tl.name,
    'status', tl.status,
    'squad_name', tl.squad_name,
    'bio', tl.bio,
    'phone', tl.phone,
    'start_date', tl.start_date,
    'end_date', tl.end_date,
    'active_companies', get_team_leader_active_companies_count(tl.id),
    'user', JSON_OBJECT(
      'id', u.id,
      'email', u.email,
      'role', r.name
    )
  )
  INTO result
  FROM team_leaders tl
  JOIN users u ON tl.user_id = u.id
  LEFT JOIN roles r ON u.role_id = r.id
  WHERE tl.id = leader_id;
  
  RETURN result;
END//

-- Create procedure to assign company to team leader
CREATE PROCEDURE assign_company_to_team_leader(
  IN p_company_id VARCHAR(36),
  IN p_leader_id VARCHAR(36),
  IN p_position ENUM('A', 'B'),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Check if team leader exists and is active
  IF NOT EXISTS (
    SELECT 1 FROM team_leaders
    WHERE id = p_leader_id
    AND status = 'active'
  ) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Invalid or inactive team leader';
  END IF;
  
  -- Update company
  IF p_position = 'A' THEN
    UPDATE companies
    SET team_leader_a_id = p_leader_id
    WHERE id = p_company_id;
  ELSE
    UPDATE companies
    SET team_leader_b_id = p_leader_id
    WHERE id = p_company_id;
  END IF;
END//

-- Create procedure to unassign company from team leader
CREATE PROCEDURE unassign_company_from_team_leader(
  IN p_company_id VARCHAR(36),
  IN p_position ENUM('A', 'B'),
  IN p_current_user_id VARCHAR(36)
)
BEGIN
  -- Check if current user is admin
  IF NOT is_admin(p_current_user_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Permission denied';
  END IF;
  
  -- Update company
  IF p_position = 'A' THEN
    UPDATE companies
    SET team_leader_a_id = NULL
    WHERE id = p_company_id;
  ELSE
    UPDATE companies
    SET team_leader_b_id = NULL
    WHERE id = p_company_id;
  END IF;
END//

DELIMITER ;