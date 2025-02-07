-- Create company_products table
CREATE TABLE IF NOT EXISTS company_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  price_override decimal(10,2),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(company_id, product_id)
);

-- Enable RLS
ALTER TABLE company_products ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX idx_company_products_company ON company_products(company_id);
CREATE INDEX idx_company_products_product ON company_products(product_id);
CREATE INDEX idx_company_products_active ON company_products(is_active);

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
ON company_products FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable write access for admins"
ON company_products FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to get company products with details
CREATE OR REPLACE FUNCTION get_company_products(company_id uuid)
RETURNS TABLE (
  id uuid,
  product_id uuid,
  product_name text,
  product_description text,
  base_price decimal(10,2),
  price_override decimal(10,2),
  effective_price decimal(10,2),
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    cp.id,
    p.id as product_id,
    p.name as product_name,
    p.description as product_description,
    p.price as base_price,
    cp.price_override,
    COALESCE(cp.price_override, p.price) as effective_price,
    cp.is_active,
    cp.created_at,
    cp.updated_at
  FROM company_products cp
  JOIN products p ON cp.product_id = p.id
  WHERE cp.company_id = get_company_products.company_id
  ORDER BY p.name;
$$;

-- Create function to assign product to company
CREATE OR REPLACE FUNCTION assign_product_to_company(
  company_id uuid,
  product_id uuid,
  price_override decimal(10,2) DEFAULT NULL,
  is_active boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_assignment_id uuid;
BEGIN
  -- Check if user has permission
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Insert new assignment
  INSERT INTO company_products (
    company_id,
    product_id,
    price_override,
    is_active
  )
  VALUES (
    assign_product_to_company.company_id,
    assign_product_to_company.product_id,
    assign_product_to_company.price_override,
    assign_product_to_company.is_active
  )
  RETURNING id INTO new_assignment_id;

  RETURN new_assignment_id;
END;
$$;

-- Create function to update company product
CREATE OR REPLACE FUNCTION update_company_product(
  assignment_id uuid,
  price_override decimal(10,2) DEFAULT NULL,
  is_active boolean DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user has permission
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Update assignment
  UPDATE company_products
  SET
    price_override = COALESCE(update_company_product.price_override, price_override),
    is_active = COALESCE(update_company_product.is_active, is_active),
    updated_at = now()
  WHERE id = update_company_product.assignment_id;

  RETURN FOUND;
END;
$$;

-- Create function to remove product from company
CREATE OR REPLACE FUNCTION remove_product_from_company(
  company_id uuid,
  product_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user has permission
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Delete assignment
  DELETE FROM company_products
  WHERE company_id = remove_product_from_company.company_id
  AND product_id = remove_product_from_company.product_id;

  RETURN FOUND;
END;
$$;

-- Create updated_at trigger
CREATE TRIGGER set_timestamp
  BEFORE UPDATE ON company_products
  FOR EACH ROW
  EXECUTE FUNCTION trigger_set_timestamp();