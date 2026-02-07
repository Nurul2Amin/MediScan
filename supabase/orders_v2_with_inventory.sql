-- =========================================================
-- ORDERS SYSTEM SCHEMA - UPDATED WITH UNIT TYPES & INVENTORY
-- Run this in Supabase SQL Editor
-- =========================================================

-- =========================================================
-- 1) ADD unit_type COLUMN TO order_items (if not exists)
-- =========================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'order_items' AND column_name = 'unit_type'
  ) THEN
    ALTER TABLE public.order_items ADD COLUMN unit_type TEXT DEFAULT 'strip';
  END IF;
END $$;

-- =========================================================
-- 2) UPDATE place_order FUNCTION TO INCLUDE unit_type
-- =========================================================
CREATE OR REPLACE FUNCTION public.place_order(
  p_pharmacy_id BIGINT,
  p_items JSONB,  -- Array of {medicine_id, quantity, unit_price, unit_type, medicine_name, medicine_form, medicine_strength}
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id BIGINT;
  v_customer_id UUID;
  v_total NUMERIC := 0;
  v_item_count INTEGER := 0;
  v_item JSONB;
BEGIN
  -- Get current user
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate pharmacy exists
  IF NOT EXISTS (SELECT 1 FROM public.pharmacies WHERE pharmacy_id = p_pharmacy_id) THEN
    RAISE EXCEPTION 'Pharmacy not found';
  END IF;

  -- Calculate totals
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_total := v_total + (COALESCE((v_item->>'unit_price')::NUMERIC, 0) * COALESCE((v_item->>'quantity')::INTEGER, 1));
    v_item_count := v_item_count + COALESCE((v_item->>'quantity')::INTEGER, 1);
  END LOOP;

  -- Create order
  INSERT INTO public.orders (
    customer_id,
    pharmacy_id,
    status,
    total_amount,
    item_count,
    customer_name,
    customer_phone,
    customer_notes
  ) VALUES (
    v_customer_id,
    p_pharmacy_id,
    'pending',
    v_total,
    v_item_count,
    p_customer_name,
    p_customer_phone,
    p_customer_notes
  )
  RETURNING order_id INTO v_order_id;

  -- Insert order items WITH unit_type
  INSERT INTO public.order_items (
    order_id,
    medicine_id,
    medicine_name,
    medicine_form,
    medicine_strength,
    quantity,
    unit_type,
    unit_price,
    subtotal
  )
  SELECT 
    v_order_id,
    (item->>'medicine_id')::BIGINT,
    item->>'medicine_name',
    item->>'medicine_form',
    item->>'medicine_strength',
    COALESCE((item->>'quantity')::INTEGER, 1),
    COALESCE(item->>'unit_type', 'strip'),  -- Default to 'strip' if not provided
    COALESCE((item->>'unit_price')::NUMERIC, 0),
    COALESCE((item->>'unit_price')::NUMERIC, 0) * COALESCE((item->>'quantity')::INTEGER, 1)
  FROM jsonb_array_elements(p_items) AS item;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'total_amount', v_total,
    'item_count', v_item_count
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- =========================================================
-- 3) FUNCTION TO DEDUCT INVENTORY WHEN ORDER IS COMPLETED
-- =========================================================
CREATE OR REPLACE FUNCTION public.deduct_inventory_for_order(p_order_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_item RECORD;
  v_pharmacy_id BIGINT;
  v_remaining_qty INTEGER;
  v_base_units_to_deduct INTEGER;
  v_batch RECORD;
  v_deduct_qty INTEGER;
  v_pm_id BIGINT;
  v_pills_per_leaflet INTEGER;
  v_leaflets_per_box INTEGER;
BEGIN
  -- Get pharmacy_id for this order
  SELECT pharmacy_id INTO v_pharmacy_id FROM public.orders WHERE order_id = p_order_id;
  
  IF v_pharmacy_id IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Loop through each order item
  FOR v_order_item IN 
    SELECT oi.medicine_id, oi.quantity, oi.unit_type 
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    -- Get pharmacy_medicine_id and packaging configuration for this medicine
    SELECT id, pills_per_leaflet, leaflets_per_box
    INTO v_pm_id, v_pills_per_leaflet, v_leaflets_per_box
    FROM public.pharmacy_medicines
    WHERE pharmacy_id = v_pharmacy_id AND medicine_id = v_order_item.medicine_id;
    
    -- Skip if medicine not found in pharmacy
    IF v_pm_id IS NULL THEN
      RAISE WARNING 'Medicine % not found in pharmacy inventory', v_order_item.medicine_id;
      CONTINUE;
    END IF;
    
    -- Log for debugging
    RAISE NOTICE 'Processing: medicine_id=%, qty=%, unit_type=%, pills_per_leaflet=%, leaflets_per_box=%', 
      v_order_item.medicine_id, v_order_item.quantity, v_order_item.unit_type, v_pills_per_leaflet, v_leaflets_per_box;
    
    -- Convert customer's ordered unit to pharmacy's base units
    v_base_units_to_deduct := v_order_item.quantity;
    
    -- Handle NULL unit_type (default to 'piece' for safety)
    CASE COALESCE(v_order_item.unit_type, 'piece')
      WHEN 'strip' THEN
        v_base_units_to_deduct := v_order_item.quantity * COALESCE(v_pills_per_leaflet, 10);
      WHEN 'box' THEN
        v_base_units_to_deduct := v_order_item.quantity * 
          COALESCE(v_pills_per_leaflet, 10) * 
          COALESCE(v_leaflets_per_box, 3);
      WHEN 'piece', 'pill', 'tablet', 'capsule' THEN
        v_base_units_to_deduct := v_order_item.quantity;
      ELSE
        -- For bottle, tube, vial, etc - treat as single units
        v_base_units_to_deduct := v_order_item.quantity;
    END CASE;
    
    RAISE NOTICE 'Deducting % base units', v_base_units_to_deduct;
    
    v_remaining_qty := v_base_units_to_deduct;

    -- Deduct from batches (FIFO - oldest expiry first)
    FOR v_batch IN 
      SELECT batch_id, qty_remaining 
      FROM public.pharmacy_medicine_batches
      WHERE pharmacy_medicine_id = v_pm_id
        AND qty_remaining > 0
      ORDER BY expiry_date ASC NULLS LAST, created_at ASC
    LOOP
      IF v_remaining_qty <= 0 THEN
        EXIT;
      END IF;
      
      v_deduct_qty := LEAST(v_remaining_qty, v_batch.qty_remaining);
      
      UPDATE public.pharmacy_medicine_batches
      SET qty_remaining = qty_remaining - v_deduct_qty
      WHERE batch_id = v_batch.batch_id;
      
      v_remaining_qty := v_remaining_qty - v_deduct_qty;
    END LOOP;
    
    IF v_remaining_qty > 0 THEN
      RAISE WARNING 'Insufficient stock for medicine_id %, short by % units', 
        v_order_item.medicine_id, v_remaining_qty;
    END IF;
  END LOOP;

  RETURN TRUE;
END;
$$;

-- =========================================================
-- 4) UPDATED update_order_status WITH AUTO INVENTORY DEDUCTION
-- =========================================================
CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id BIGINT,
  p_status TEXT,
  p_pharmacy_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_owner_id UUID;
  v_pharmacy_id BIGINT;
  v_current_status TEXT;
  v_inventory_deducted BOOLEAN;
BEGIN
  -- Get pharmacy_id, current status, and verify ownership
  SELECT o.pharmacy_id, o.status, p.owner_id 
  INTO v_pharmacy_id, v_current_status, v_owner_id
  FROM public.orders o
  JOIN public.pharmacies p ON p.pharmacy_id = o.pharmacy_id
  WHERE o.order_id = p_order_id;

  IF v_owner_id IS NULL OR v_owner_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to update this order';
  END IF;

  -- Prevent invalid status transitions
  IF v_current_status = 'completed' OR v_current_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot update a % order', v_current_status;
  END IF;

  -- Update order status
  UPDATE public.orders
  SET 
    status = p_status,
    pharmacy_notes = COALESCE(p_pharmacy_notes, pharmacy_notes),
    confirmed_at = CASE WHEN p_status = 'confirmed' AND confirmed_at IS NULL THEN NOW() ELSE confirmed_at END,
    ready_at = CASE WHEN p_status = 'ready' AND ready_at IS NULL THEN NOW() ELSE ready_at END,
    completed_at = CASE WHEN p_status = 'completed' AND completed_at IS NULL THEN NOW() ELSE completed_at END,
    cancelled_at = CASE WHEN p_status = 'cancelled' AND cancelled_at IS NULL THEN NOW() ELSE cancelled_at END
  WHERE order_id = p_order_id;

  -- AUTO-DEDUCT INVENTORY when order is marked as COMPLETED
  IF p_status = 'completed' THEN
    v_inventory_deducted := public.deduct_inventory_for_order(p_order_id);
    
    RETURN jsonb_build_object(
      'success', true, 
      'status', p_status,
      'inventory_deducted', v_inventory_deducted
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'status', p_status);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =========================================================
-- 5) HELPER VIEW: Order details with items for pharmacy
-- =========================================================
CREATE OR REPLACE VIEW public.v_order_details AS
SELECT 
  o.order_id,
  o.customer_id,
  o.pharmacy_id,
  o.status,
  o.total_amount,
  o.item_count,
  o.customer_name,
  o.customer_phone,
  o.customer_notes,
  o.pharmacy_notes,
  o.created_at,
  o.confirmed_at,
  o.ready_at,
  o.completed_at,
  oi.item_id,
  oi.medicine_id,
  oi.medicine_name,
  oi.medicine_form,
  oi.medicine_strength,
  oi.quantity,
  oi.unit_type,
  oi.unit_price,
  oi.subtotal
FROM public.orders o
JOIN public.order_items oi ON oi.order_id = o.order_id;

-- =========================================================
-- 6) NEW: Find pharmacies with STOCK AVAILABILITY CHECK
-- =========================================================
-- This function checks if pharmacies have ENOUGH stock for the customer's order
-- Accepts cart items with quantity and unit_type, converts to base units
CREATE OR REPLACE FUNCTION public.find_pharmacies_with_stock(
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
  has_full_stock boolean
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
    -- Parse cart items and convert to base units using pharmacy's packaging config
    SELECT 
      (item->>'medicine_id')::bigint as medicine_id,
      (item->>'quantity')::integer as qty,
      item->>'unit_type' as unit_type
    FROM jsonb_array_elements(cart_items) as item
  ),
  pharmacy_stock AS (
    -- For each pharmacy, calculate if they have enough stock for each cart item
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
    -- Aggregate by pharmacy - count items with sufficient stock
    SELECT
      ps.pharmacy_id,
      ps.name,
      ps.address,
      ps.latitude,
      ps.longitude,
      ps.contact_number,
      ps.dist_m,
      COUNT(DISTINCT ps.medicine_id)::integer as matched_items,
      -- Count items where pharmacy has enough stock
      COUNT(DISTINCT CASE WHEN ps.stock_base_units >= ps.required_base_units THEN ps.medicine_id END)::integer as items_with_stock,
      SUM(ps.price * ps.requested_qty) as total_price
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
    (ps.items_with_stock = v_total_items) as has_full_stock  -- TRUE if all items have sufficient stock
  FROM pharmacy_summary ps
  WHERE ps.matched_items > 0
  ORDER BY 
    (ps.items_with_stock = v_total_items) DESC,  -- Pharmacies with full stock first
    ps.matched_items DESC,
    ps.total_price ASC,
    ps.dist_m ASC;
END;
$$;

COMMENT ON FUNCTION public.find_pharmacies_with_stock IS 
'Finds pharmacies that have stock for customer cart items. Converts customer units (strip/box) to base units and checks against actual inventory. Returns has_full_stock=true if pharmacy has enough stock for ALL items.';

COMMENT ON FUNCTION public.deduct_inventory_for_order IS 
'Automatically deducts inventory from pharmacy batches when an order is completed. Uses FIFO (First Expiry First Out) method.';

COMMENT ON FUNCTION public.update_order_status IS 
'Updates order status. When status is set to "completed", automatically deducts inventory from pharmacy stock.';
