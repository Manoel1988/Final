-- Create company_products junction table
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
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND raw_user_meta_data->>'permission' = 'admin'
  )
);

-- Create function to assign product to company
CREATE OR REPLACE FUNCTION assign_product_to_company(
  company_id uuid,
  product_id uuid,
  price_override decimal(10,2) DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_assignment_id uuid;
BEGIN
  -- Validate company exists
  IF NOT EXISTS (SELECT 1 FROM companies WHERE id = company_id) THEN
    RAISE EXCEPTION 'Company not found';
  END IF;

  -- Validate product exists and is active
  IF NOT EXISTS (SELECT 1 FROM products WHERE id = product_id AND status = 'active') THEN
    RAISE EXCEPTION 'Product not found or inactive';
  END IF;

  -- Create assignment
  INSERT INTO company_products (
    company_id,
    product_id,
    price_override
  )
  VALUES (
    company_id,
    product_id,
    price_override
  )
  RETURNING id INTO new_assignment_id;

  RETURN new_assignment_id;
END;
$$;

-- Create function to update company product assignment
CREATE OR REPLACE FUNCTION update_company_product(
  assignment_id uuid,
  new_price_override decimal(10,2) DEFAULT NULL,
  new_is_active boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_assignment jsonb;
BEGIN
  -- Update assignment
  UPDATE company_products
  SET
    price_override = COALESCE(new_price_override, price_override),
    is_active = COALESCE(new_is_active, is_active),
    updated_at = now()
  WHERE id = assignment_id
  RETURNING jsonb_build_object(
    'id', id,
    'company_id', company_id,
    'product_id', product_id,
    'price_override', price_override,
    'is_active', is_active,
    'updated_at', updated_at
  ) INTO updated_assignment;

  IF updated_assignment IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;

  RETURN updated_assignment;
END;
$$;

-- Create function to get company products
CREATE OR REPLACE FUNCTION get_company_products(company_id uuid)
RETURNS TABLE (
  assignment_id uuid,
  product_id uuid,
  product_name text,
  base_price decimal(10,2),
  override_price decimal(10,2),
  effective_price decimal(10,2),
  is_active boolean,
  product_status text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    cp.id as assignment_id,
    p.id as product_id,
    p.name as product_name,
    p.price as base_price,
    cp.price_override as override_price,
    COALESCE(cp.price_override, p.price) as effective_price,
    cp.is_active,
    p.status as product_status
  FROM company_products cp
  JOIN products p ON cp.product_id = p.id
  WHERE cp.company_id = company_id
  ORDER BY p.name;
$$;

-- Create function to get company product summary
CREATE OR REPLACE FUNCTION get_company_product_summary(company_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  summary jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_products', COUNT(*),
    'active_products', COUNT(*) FILTER (WHERE cp.is_active AND p.status = 'active'),
    'total_value', SUM(COALESCE(cp.price_override, p.price)),
    'custom_prices', COUNT(*) FILTER (WHERE cp.price_override IS NOT NULL),
    'products', jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'effective_price', COALESCE(cp.price_override, p.price),
        'is_custom_price', cp.price_override IS NOT NULL,
        'is_active', cp.is_active AND p.status = 'active'
      )
    )
  )
  INTO summary
  FROM company_products cp
  JOIN products p ON cp.product_id = p.id
  WHERE cp.company_id = company_id;

  RETURN COALESCE(summary, jsonb_build_object(
    'total_products', 0,
    'active_products', 0,
    'total_value', 0,
    'custom_prices', 0,
    'products', '[]'::jsonb
  ));
END;
$$;

-- Create function to bulk assign products to company
CREATE OR REPLACE FUNCTION bulk_assign_products(
  company_id uuid,
  product_ids uuid[]
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate company exists
  IF NOT EXISTS (SELECT 1 FROM companies WHERE id = company_id) THEN
    RAISE EXCEPTION 'Company not found';
  END IF;

  -- Insert assignments and return IDs
  RETURN QUERY
  INSERT INTO company_products (company_id, product_id)
  SELECT company_id, p.id
  FROM unnest(product_ids) pid
  JOIN products p ON p.id = pid
  WHERE p.status = 'active'
  ON CONFLICT (company_id, product_id) DO NOTHING
  RETURNING id;
END;
$$;

-- Create function to bulk update company product status
CREATE OR REPLACE FUNCTION bulk_update_company_product_status(
  company_id uuid,
  product_ids uuid[],
  new_status boolean
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE company_products
  SET 
    is_active = new_status,
    updated_at = now()
  WHERE company_id = bulk_update_company_product_status.company_id
    AND product_id = ANY(product_ids)
  RETURNING id;
END;
$$;