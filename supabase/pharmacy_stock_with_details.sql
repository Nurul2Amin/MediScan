-- =========================================================
-- Enhanced Pharmacy Search with Per-Item Pricing Details
-- Returns pharmacy info + array of matched items with prices
-- =========================================================

CREATE OR REPLACE FUNCTION public.find_pharmacies_with_stock_details(
  user_lat double precision,
  user_lng double precision,
  cart_items JSONB,  -- Array of {medicine_id, quantity, unit_type}
  radius_m integer default 5000
)
RETURNS TABLE (
  pharmacy_id bigint,
  name text,
  address text,
  latitude double precision,
  longitude double precision,
  contact_number text,
  matched_items integer,
  total_items integer,
  total_price numeric,
  distance_m double precision,
  has_full_stock boolean,
  item_details JSONB  -- Array of per-item pricing details
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_total_items integer;
BEGIN
  -- Count total items in cart
  SELECT COUNT(*) INTO v_total_items FROM jsonb_array_elements(cart_items);
  
  RETURN QUERY
  WITH cart AS (
    -- Parse cart items
    SELECT 
      (item->>'medicine_id')::bigint as medicine_id,
      (item->>'quantity')::integer as qty,
      item->>'unit_type' as unit_type
    FROM jsonb_array_elements(cart_items) as item
  ),
  pharmacy_stock AS (
    -- For each pharmacy, calculate stock and pricing for each cart item
    SELECT
      p.pharmacy_id,
      p.name,
      p.address,
      p.latitude,
      p.longitude,
      p.contact_number,
      pm.medicine_id,
      pm.price,
      pm.pills_per_leaflet,
      pm.leaflets_per_box,
      -- Get total stock from batches (only non-expired)
      COALESCE((
        SELECT SUM(b.qty_remaining)
        FROM public.pharmacy_medicine_batches b
        WHERE b.pharmacy_medicine_id = pm.id
          AND (b.expiry_date IS NULL OR b.expiry_date > CURRENT_DATE)
      ), 0) as stock_base_units,
      c.qty as requested_qty,
      c.unit_type as requested_unit,
      -- Convert requested quantity to base units
      CASE c.unit_type
        WHEN 'strip' THEN c.qty * COALESCE(pm.pills_per_leaflet, 10)
        WHEN 'box' THEN c.qty * COALESCE(pm.pills_per_leaflet, 10) * COALESCE(pm.leaflets_per_box, 3)
        ELSE c.qty  -- piece, bottle, tube, vial, sachet = direct
      END as required_base_units,
      ST_Distance(p.location, ST_Point(user_lng, user_lat)::geography) as dist_m
    FROM public.pharmacies p
    JOIN public.pharmacy_medicines pm ON pm.pharmacy_id = p.pharmacy_id
    JOIN cart c ON c.medicine_id = pm.medicine_id
    WHERE pm.is_available = true
      AND p.location IS NOT NULL
      AND ST_DWithin(p.location, ST_Point(user_lng, user_lat)::geography, radius_m)
  ),
  pharmacy_summary AS (
    -- Aggregate by pharmacy
    SELECT
      ps.pharmacy_id,
      ps.name,
      ps.address,
      ps.latitude,
      ps.longitude,
      ps.contact_number,
      ps.dist_m,
      COUNT(DISTINCT ps.medicine_id)::integer as matched_items,
      COUNT(DISTINCT CASE WHEN ps.stock_base_units >= ps.required_base_units THEN ps.medicine_id END)::integer as items_with_stock,
      SUM(ps.price * ps.required_base_units) as total_price,
      -- Build JSON array of item details
      jsonb_agg(
        jsonb_build_object(
          'medicine_id', ps.medicine_id,
          'price_per_unit', ps.price,
          'pills_per_strip', ps.pills_per_leaflet,
          'strips_per_box', ps.leaflets_per_box,
          'requested_qty', ps.requested_qty,
          'requested_unit', ps.requested_unit,
          'required_base_units', ps.required_base_units,
          'item_total_price', ps.price * ps.required_base_units,
          'has_stock', ps.stock_base_units >= ps.required_base_units,
          'available_stock', ps.stock_base_units
        )
      ) as item_details
    FROM pharmacy_stock ps
    GROUP BY ps.pharmacy_id, ps.name, ps.address, ps.latitude, ps.longitude, ps.contact_number, ps.dist_m
  )
  SELECT
    ps.pharmacy_id,
    ps.name,
    ps.address,
    ps.latitude,
    ps.longitude,
    ps.contact_number,
    ps.matched_items,
    v_total_items as total_items,
    COALESCE(ps.total_price, 0) as total_price,
    ps.dist_m as distance_m,
    (ps.items_with_stock = v_total_items) as has_full_stock,
    ps.item_details
  FROM pharmacy_summary ps
  WHERE ps.matched_items > 0
  ORDER BY 
    (ps.items_with_stock = v_total_items) DESC,
    ps.matched_items DESC,
    ps.total_price ASC,
    ps.dist_m ASC;
END;
$$;

COMMENT ON FUNCTION public.find_pharmacies_with_stock_details IS 
'Find pharmacies with stock for cart items, including per-item pricing details.
Returns item_details JSONB array with each medicine''s:
- price_per_unit (per pill/base unit)
- pills_per_strip, strips_per_box (pharmacy config)
- item_total_price (calculated: price × base_units)
- has_stock (boolean)';
