/*
  # Fix Companies and Users Relationship

  1. Changes
    - Add proper foreign key relationship between companies and users tables
    - Update companies table to reference users table correctly
    - Add index for better query performance

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing foreign key if it exists
ALTER TABLE companies 
DROP CONSTRAINT IF EXISTS companies_user_id_fkey;

-- Add proper foreign key constraint
ALTER TABLE companies
ADD CONSTRAINT companies_user_id_fkey 
FOREIGN KEY (user_id) 
REFERENCES auth.users(id)
ON DELETE CASCADE;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_companies_user_id 
ON companies(user_id);