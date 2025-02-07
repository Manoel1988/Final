-- Create functions and procedures for product management

-- Create function to check if product exists
CREATE OR REPLACE FUNCTION product_exists(product_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM products WHERE id = product_id
  );
$$;

-- Create function to get product details
CREATE OR REPLACE FUNCTION get_product_details(product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  product_data jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', id,
    'name', name,
    'description', description,
    'status', status,
    'price', price,
    'created_at', created_at,
    'updated_at', updated_at
  )
  INTO product_data
  FROM products
  WHERE id = product_id;
  
  RETURN product_data;
END;
$$;

-- Create function to validate product data
CREATE OR REPLACE FUNCTION validate_product_data(
  product_name text,
  product_price numeric
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Check name length
  IF length(product_name) < 2 THEN
    RAISE EXCEPTION 'Product name must be at least 2 characters long';
  END IF;

  -- Check price
  IF product_price < 0 THEN
    RAISE EXCEPTION 'Product price cannot be negative';
  END IF;

  RETURN true;
END;
$$;

-- Create function to safely create product
CREATE OR REPLACE FUNCTION create_product_safe(
  name text,
  description text,
  price numeric,
  status text DEFAULT 'active'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_product_id uuid;
BEGIN
  -- Validate product data
  PERFORM validate_product_data(name, price);

  -- Check if product name already exists
  IF EXISTS (SELECT 1 FROM products WHERE products.name = create_product_safe.name) THEN
    RAISE EXCEPTION 'Product with this name already exists';
  END IF;

  -- Create new product
  INSERT INTO products (
    id,
    name,
    description,
    price,
    status,
    created_at,
    updated_at
  )
  VALUES (
    gen_random_uuid(),
    name,
    description,
    price,
    status,
    now(),
    now()
  )
  RETURNING id INTO new_product_id;

  RETURN new_product_id;
END;
$$;

-- Create function to safely update product
CREATE OR REPLACE FUNCTION update_product_safe(
  product_id uuid,
  new_name text DEFAULT NULL,
  new_description text DEFAULT NULL,
  new_price numeric DEFAULT NULL,
  new_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_product jsonb;
BEGIN
  -- Check if product exists
  IF NOT product_exists(product_id) THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Validate new data if provided
  IF new_name IS NOT NULL OR new_price IS NOT NULL THEN
    PERFORM validate_product_data(
      COALESCE(new_name, (SELECT name FROM products WHERE id = product_id)),
      COALESCE(new_price, (SELECT price FROM products WHERE id = product_id))
    );
  END IF;

  -- Check if new name conflicts with existing products
  IF new_name IS NOT NULL AND EXISTS (
    SELECT 1 FROM products 
    WHERE name = new_name AND id != product_id
  ) THEN
    RAISE EXCEPTION 'Product with this name already exists';
  END IF;

  -- Update product
  UPDATE products
  SET
    name = COALESCE(new_name, name),
    description = COALESCE(new_description, description),
    price = COALESCE(new_price, price),
    status = COALESCE(new_status, status),
    updated_at = now()
  WHERE id = product_id
  RETURNING jsonb_build_object(
    'id', id,
    'name', name,
    'description', description,
    'status', status,
    'price', price,
    'updated_at', updated_at
  ) INTO updated_product;

  RETURN updated_product;
END;
$$;

-- Create function to safely delete product
CREATE OR REPLACE FUNCTION delete_product_safe(product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if product exists
  IF NOT product_exists(product_id) THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Delete product
  DELETE FROM products WHERE id = product_id;
  RETURN true;
END;
$$;

-- Create function to get active products
CREATE OR REPLACE FUNCTION get_active_products()
RETURNS SETOF products
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM products
  WHERE status = 'active'
  ORDER BY name;
$$;

-- Create function to search products
CREATE OR REPLACE FUNCTION search_products(search_term text)
RETURNS SETOF products
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM products
  WHERE 
    name ILIKE '%' || search_term || '%'
    OR description ILIKE '%' || search_term || '%'
  ORDER BY name;
$$;

-- Create function to get products by price range
CREATE OR REPLACE FUNCTION get_products_by_price_range(
  min_price numeric,
  max_price numeric
)
RETURNS SETOF products
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT * FROM products
  WHERE price BETWEEN min_price AND max_price
  ORDER BY price;
$$;