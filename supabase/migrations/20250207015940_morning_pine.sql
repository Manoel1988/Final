-- Create function to get product statistics
CREATE OR REPLACE FUNCTION get_product_statistics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_products', COUNT(*),
    'active_products', COUNT(*) FILTER (WHERE status = 'active'),
    'inactive_products', COUNT(*) FILTER (WHERE status = 'inactive'),
    'avg_price', ROUND(AVG(price)::numeric, 2),
    'min_price', MIN(price),
    'max_price', MAX(price)
  )
  INTO stats
  FROM products;
  
  RETURN stats;
END;
$$;

-- Create function to get product categories
CREATE OR REPLACE FUNCTION get_product_price_categories()
RETURNS TABLE (
  category text,
  product_count bigint,
  price_range text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH ranges AS (
    SELECT
      CASE
        WHEN price < 100 THEN 'Low'
        WHEN price >= 100 AND price < 500 THEN 'Medium'
        ELSE 'High'
      END as category,
      COUNT(*) as product_count,
      MIN(price) as min_price,
      MAX(price) as max_price
    FROM products
    WHERE status = 'active'
    GROUP BY 
      CASE
        WHEN price < 100 THEN 'Low'
        WHEN price >= 100 AND price < 500 THEN 'Medium'
        ELSE 'High'
      END
  )
  SELECT 
    category,
    product_count,
    format('$%s - $%s', 
      ROUND(min_price::numeric, 2)::text,
      ROUND(max_price::numeric, 2)::text
    ) as price_range
  FROM ranges
  ORDER BY 
    CASE category
      WHEN 'Low' THEN 1
      WHEN 'Medium' THEN 2
      WHEN 'High' THEN 3
    END;
$$;

-- Create function to get product change history
CREATE OR REPLACE FUNCTION get_product_changes()
RETURNS TABLE (
  change_type text,
  product_name text,
  changed_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT 
    CASE 
      WHEN updated_at = created_at THEN 'Created'
      ELSE 'Updated'
    END as change_type,
    name as product_name,
    CASE 
      WHEN updated_at = created_at THEN created_at
      ELSE updated_at
    END as changed_at
  FROM products
  ORDER BY 
    CASE 
      WHEN updated_at = created_at THEN created_at
      ELSE updated_at
    END DESC
  LIMIT 50;
$$;

-- Create function to bulk update product status
CREATE OR REPLACE FUNCTION bulk_update_product_status(
  product_ids uuid[],
  new_status text
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate status
  IF new_status NOT IN ('active', 'inactive') THEN
    RAISE EXCEPTION 'Invalid status. Must be either active or inactive';
  END IF;

  -- Update products and return their IDs
  RETURN QUERY
  UPDATE products
  SET 
    status = new_status,
    updated_at = now()
  WHERE id = ANY(product_ids)
  RETURNING id;
END;
$$;

-- Create function to bulk update product prices
CREATE OR REPLACE FUNCTION bulk_update_product_prices(
  price_updates jsonb
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  product_id uuid;
  new_price numeric;
BEGIN
  -- Iterate through the price updates
  FOR product_id, new_price IN
    SELECT 
      (jsonb_each_text.key)::uuid,
      (jsonb_each_text.value)::numeric
    FROM jsonb_each_text(price_updates)
  LOOP
    -- Validate price
    IF new_price < 0 THEN
      RAISE EXCEPTION 'Price cannot be negative for product %', product_id;
    END IF;

    -- Update product price
    UPDATE products
    SET 
      price = new_price,
      updated_at = now()
    WHERE id = product_id
    RETURNING id;
  END LOOP;

  -- Return updated product IDs
  RETURN QUERY
  SELECT (jsonb_each_text.key)::uuid
  FROM jsonb_each_text(price_updates);
END;
$$;

-- Create function to get similar products
CREATE OR REPLACE FUNCTION get_similar_products(
  product_id uuid,
  price_range_percent numeric DEFAULT 20,
  limit_count integer DEFAULT 5
)
RETURNS SETOF products
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  target_price numeric;
BEGIN
  -- Get the target product's price
  SELECT price INTO target_price
  FROM products
  WHERE id = product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Calculate price range
  RETURN QUERY
  SELECT *
  FROM products
  WHERE id != product_id
    AND status = 'active'
    AND price BETWEEN target_price * (1 - price_range_percent/100)
                 AND target_price * (1 + price_range_percent/100)
  ORDER BY 
    ABS(price - target_price),
    name
  LIMIT limit_count;
END;
$$;

-- Create function to get product price history statistics
CREATE OR REPLACE FUNCTION get_product_price_stats(
  product_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'current_price', price,
    'name', name,
    'status', status,
    'created_at', created_at,
    'last_updated', updated_at,
    'days_since_update', EXTRACT(DAY FROM now() - updated_at)::integer
  )
  INTO stats
  FROM products
  WHERE id = product_id;

  IF stats IS NULL THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  RETURN stats;
END;
$$;