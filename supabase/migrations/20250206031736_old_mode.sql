/*
  # Create companies table and policies

  1. New Tables
    - `companies`
      - `id` (uuid, primary key)
      - `name` (text, company name)
      - `legal_name` (text, legal/business name)
      - `contract_start` (date, contract start date)
      - `contract_end` (date, contract end date)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
      - `user_id` (uuid, references auth.users)

  2. Security
    - Enable RLS on `companies` table
    - Add policies for CRUD operations
*/

-- Create companies table if it doesn't exist
CREATE TABLE IF NOT EXISTS companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  legal_name text NOT NULL,
  contract_start date NOT NULL,
  contract_end date NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  user_id uuid REFERENCES auth.users NOT NULL
);

-- Enable RLS
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'companies' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Create policies if they don't exist
DO $$ 
BEGIN
  -- Select policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Users can view their companies'
  ) THEN
    CREATE POLICY "Users can view their companies"
      ON companies
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- Insert policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Users can create companies'
  ) THEN
    CREATE POLICY "Users can create companies"
      ON companies
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  -- Update policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Users can update their companies'
  ) THEN
    CREATE POLICY "Users can update their companies"
      ON companies
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- Delete policy
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Users can delete their companies'
  ) THEN
    CREATE POLICY "Users can delete their companies"
      ON companies
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- Create function to update updated_at timestamp if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_companies_updated_at'
  ) THEN
    CREATE TRIGGER update_companies_updated_at
      BEFORE UPDATE ON companies
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;