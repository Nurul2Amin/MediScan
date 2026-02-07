-- =========================================================
-- MediScan: Inventory View Update for Pack Display
-- Adds pills_per_leaflet and leaflets_per_box to v_pharmacy_inventory_summary
-- Run this in Supabase SQL Editor
-- =========================================================

-- Drop and recreate the view with pack configuration columns
DROP VIEW IF EXISTS public.v_pharmacy_inventory_summary;

CREATE OR REPLACE VIEW public.v_pharmacy_inventory_summary AS
SELECT 
  p.pharmacy_id,
  pm.id AS pharmacy_medicine_id,
  m.medicine_id,
  m.name AS medicine_name,
  m.form,
  m.strength,
  pm.unit_type,
  pm.stock_qty AS total_base_units,
  pm.reorder_level,
  pm.is_available,
  -- Pack configuration for display formatting
  pm.pills_per_leaflet,
  pm.leaflets_per_box,
  -- Expiry and batch info
  MIN(b.expiry_date) FILTER (WHERE b.qty_remaining > 0) AS next_expiry_date,
  COUNT(b.batch_id) FILTER (WHERE b.qty_remaining > 0) AS active_batch_count,
  COALESCE(SUM(b.qty_remaining) FILTER (WHERE b.expiry_date < CURRENT_DATE), 0) AS expired_qty
FROM public.pharmacies p
JOIN public.pharmacy_medicines pm ON pm.pharmacy_id = p.pharmacy_id
JOIN public.medicines m ON m.medicine_id = pm.medicine_id
LEFT JOIN public.pharmacy_medicine_batches b ON b.pharmacy_medicine_id = pm.id
GROUP BY p.pharmacy_id, pm.id, m.medicine_id, m.name, m.form, m.strength, 
         pm.unit_type, pm.stock_qty, pm.reorder_level, pm.is_available,
         pm.pills_per_leaflet, pm.leaflets_per_box;

-- Enable security invoker for RLS
ALTER VIEW public.v_pharmacy_inventory_summary SET (security_invoker = true);

-- =========================================================
-- Summary of changes:
-- 1. Added pills_per_leaflet column from pharmacy_medicines
-- 2. Added leaflets_per_box column from pharmacy_medicines
-- 3. These allow Flutter app to format stock display as:
--    "2 boxes + 3 leaflets + 7 pills"
-- =========================================================
