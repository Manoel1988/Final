-- Create company_product_history table
CREATE TABLE IF NOT EXISTS company_product_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_product_id uuid NOT NULL REFERENCES company_products(id) ON DELETE CASCADE,
  company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  price_before decimal(10,2),
  price_after decimal(10,2),
  status_before boolean,
  status_after boolean,
  changed_by uuid REFERENCES auth.users(id),
  change_type text NOT NULL CHECK (change_type IN ('created', 'price_updated', 'status_updated', 'deleted')),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE company_product_history ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX idx_company_product_history_company ON company_product_history(company_id);
CREATE INDEX idx_company_product_history_product ON company_product_history(product_id);
CREATE INDEX idx_company_product_history_assignment ON company_product_history(company_product_id);
CREATE INDEX idx_company_product_history_changed_by ON company_product_history(changed_by);
CREATE INDEX idx_company_product_history_created_at ON company_product_history(created_at);

-- Create policies
CREATE POLICY "Enable read access for authenticated users"
ON company_product_history FOR SELECT
TO authenticated
USING (true);

-- Create trigger function to track changes
CREATE OR REPLACE FUNCTION track_company_product_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Track creation
    INSERT INTO company_product_history (
      company_product_id,
      company_id,
      product_id,
      price_before,
      price_after,
      status_before,
      status_after,
      changed_by,
      change_type
    ) VALUES (
      NEW.id,
      NEW.company_id,
      NEW.product_id,
      NULL,
      NEW.price_override,
      NULL,
      NEW.is_active,
      auth.uid(),
      'created'
    );
    
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Track price changes
    IF NEW.price_override IS DISTINCT FROM OLD.price_override THEN
      INSERT INTO company_product_history (
        company_product_id,
        company_id,
        product_id,
        price_before,
        price_after,
        status_before,
        status_after,
        changed_by,
        change_type
      ) VALUES (
        NEW.id,
        NEW.company_id,
        NEW.product_id,
        OLD.price_override,
        NEW.price_override,
        NULL,
        NULL,
        auth.uid(),
        'price_updated'
      );
    END IF;

    -- Track status changes
    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      INSERT INTO company_product_history (
        company_product_id,
        company_id,
        product_id,
        price_before,
        price_after,
        status_before,
        status_after,
        changed_by,
        change_type
      ) VALUES (
        NEW.id,
        NEW.company_id,
        NEW.product_id,
        NULL,
        NULL,
        OLD.is_active,
        NEW.is_active,
        auth.uid(),
        'status_updated'
      );
    END IF;
    
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Track deletion
    INSERT INTO company_product_history (
      company_product_id,
      company_id,
      product_id,
      price_before,
      price_after,
      status_before,
      status_after,
      changed_by,
      change_type
    ) VALUES (
      OLD.id,
      OLD.company_id,
      OLD.product_id,
      OLD.price_override,
      NULL,
      OLD.is_active,
      NULL,
      auth.uid(),
      'deleted'
    );
    
    RETURN OLD;
  END IF;
  
  RETURN NULL;
END;
$$;

-- Create triggers
CREATE TRIGGER track_company_product_changes_insert
  AFTER INSERT ON company_products
  FOR EACH ROW
  EXECUTE FUNCTION track_company_product_changes();

CREATE TRIGGER track_company_product_changes_update
  AFTER UPDATE ON company_products
  FOR EACH ROW
  EXECUTE FUNCTION track_company_product_changes();

CREATE TRIGGER track_company_product_changes_delete
  BEFORE DELETE ON company_products
  FOR EACH ROW
  EXECUTE FUNCTION track_company_product_changes();

-- Create function to get company product history
CREATE OR REPLACE FUNCTION get_company_product_history(
  company_id uuid,
  product_id uuid DEFAULT NULL,
  from_date timestamptz DEFAULT NULL,
  to_date timestamptz DEFAULT NULL
)
RETURNS TABLE (
  change_id uuid,
  assignment_id uuid,
  product_name text,
  price_before decimal(10,2),
  price_after decimal(10,2),
  status_before boolean,
  status_after boolean,
  changed_by_email text,
  change_type text,
  changed_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    h.id as change_id,
    h.company_product_id as assignment_id,
    p.name as product_name,
    h.price_before,
    h.price_after,
    h.status_before,
    h.status_after,
    u.email as changed_by_email,
    h.change_type,
    h.created_at as changed_at
  FROM company_product_history h
  JOIN products p ON h.product_id = p.id
  LEFT JOIN auth.users u ON h.changed_by = u.id
  WHERE h.company_id = get_company_product_history.company_id
    AND (get_company_product_history.product_id IS NULL OR h.product_id = get_company_product_history.product_id)
    AND (get_company_product_history.from_date IS NULL OR h.created_at >= get_company_product_history.from_date)
    AND (get_company_product_history.to_date IS NULL OR h.created_at <= get_company_product_history.to_date)
  ORDER BY h.created_at DESC;
$$;

-- Create function to get company product change summary
CREATE OR REPLACE FUNCTION get_company_product_change_summary(
  company_id uuid,
  from_date timestamptz DEFAULT NULL
)
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
    'total_changes', COUNT(*),
    'price_changes', COUNT(*) FILTER (WHERE change_type = 'price_updated'),
    'status_changes', COUNT(*) FILTER (WHERE change_type = 'status_updated'),
    'products_added', COUNT(*) FILTER (WHERE change_type = 'created'),
    'products_removed', COUNT(*) FILTER (WHERE change_type = 'deleted'),
    'changes_by_user', jsonb_object_agg(
      u.email,
      COUNT(*)
    ),
    'recent_changes', jsonb_agg(
      jsonb_build_object(
        'product_name', p.name,
        'change_type', h.change_type,
        'changed_at', h.created_at,
        'changed_by', u.email
      )
      ORDER BY h.created_at DESC
      LIMIT 5
    )
  )
  INTO summary
  FROM company_product_history h
  JOIN products p ON h.product_id = p.id
  LEFT JOIN auth.users u ON h.changed_by = u.id
  WHERE h.company_id = get_company_product_change_summary.company_id
    AND (get_company_product_change_summary.from_date IS NULL 
         OR h.created_at >= get_company_product_change_summary.from_date)
  GROUP BY h.company_id;

  RETURN COALESCE(summary, jsonb_build_object(
    'total_changes', 0,
    'price_changes', 0,
    'status_changes', 0,
    'products_added', 0,
    'products_removed', 0,
    'changes_by_user', '{}'::jsonb,
    'recent_changes', '[]'::jsonb
  ));
END;
$$;