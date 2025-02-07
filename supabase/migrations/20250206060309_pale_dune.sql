/*
  # Disable RLS for users and companies tables
  
  1. Changes
    - Disable RLS on users table
    - Disable RLS on companies table
*/

ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;