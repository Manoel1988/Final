-- Add is_active column to roles table
ALTER TABLE roles
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Update existing roles to be active by default
UPDATE roles
SET is_active = true
WHERE is_active IS NULL;

-- Add not null constraint after setting default values
ALTER TABLE roles
ALTER COLUMN is_active SET NOT NULL;