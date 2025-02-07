-- Create an email validation function
CREATE OR REPLACE FUNCTION is_valid_email(email text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$;

-- Update the email update function with validation
CREATE OR REPLACE FUNCTION update_user_email(
  target_user_id uuid,
  new_email text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate email format
  IF NOT is_valid_email(new_email) THEN
    RAISE EXCEPTION 'Invalid email format';
  END IF;

  -- Check if the user making the request is an admin or the target user
  IF (auth.uid() = target_user_id) OR is_admin(auth.uid()) THEN
    -- Update email in auth.users
    UPDATE auth.users
    SET email = new_email,
        email_confirmed_at = now() -- Auto-confirm email for admin updates
    WHERE id = target_user_id;
    
    -- Update email in public.users
    UPDATE users
    SET email = new_email
    WHERE id = target_user_id;
  ELSE
    RAISE EXCEPTION 'Permission denied';
  END IF;
END;
$$;