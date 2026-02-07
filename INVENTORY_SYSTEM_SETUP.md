# Pharmacy Inventory System V2 - Setup Guide

## Overview
Complete inventory management system with batches, expiry tracking, unit conversions, and ledger. All Gemini AI calls moved to Supabase Edge Functions.

---

## Database Setup

### 1. Run SQL Migrations

Execute these files in order in your Supabase SQL Editor:

1. `supabase/migrations/001_inventory_batches.sql`
   - Creates `pharmacy_medicine_batches` table
   - Adds `unit_type` to `pharmacy_medicines`
   - Creates sync trigger for `stock_qty`
   - Adds `reorder_level` and `active_batch_id`
   - Creates views: `v_pharmacy_inventory_summary`, `v_pharmacy_expiring_batches`
   - Sets up RLS policies

2. `supabase/migrations/002_inventory_rpc_functions.sql`
   - Creates `inventory_stock_in()` RPC
   - Creates `inventory_stock_out()` RPC (FEFO)
   - Creates `inventory_move_between_batches()` RPC

3. `supabase/migrations/003_inventory_ledger_and_conversions.sql`
   - Creates `inventory_ledger` and `inventory_ledger_allocations` tables
   - Creates `pharmacy_unit_conversions` table
   - Updates stock_in/out functions to write ledger
   - Creates trigger to sync unit conversions from legacy fields

**Important**: All migrations are idempotent (safe to re-run).

---

## Edge Functions Setup

### 1. Install Supabase CLI

```bash
npm install -g supabase
```

### 2. Login to Supabase

```bash
supabase login
```

### 3. Link Your Project

```bash
supabase link --project-ref your-project-ref
```

### 4. Set Gemini API Key Secret

```bash
supabase secrets set GEMINI_API_KEY=your_actual_gemini_api_key_here
```

### 5. Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy ai_extract_medicines
supabase functions deploy ai_parse_stock_text
supabase functions deploy ai_extract_pack_hint
```

### 6. Test Functions Locally (Optional)

```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve ai_extract_medicines --env-file .env.local
```

---

## Flutter App Setup

### 1. Update Dependencies

No new dependencies required. Uses existing:
- `supabase_flutter`
- `flutter_riverpod`

### 2. Code Changes Applied

✅ **EdgeFunctionGeminiService** replaces direct Gemini calls
✅ **InventoryRepository** added with Riverpod provider
✅ **New models**: `InventoryBatch`, `InventorySummary`, `UnitConversion`
✅ **Providers updated** to use Edge Function service

### 3. Remove Gemini Key from Client

The `lib/config/env.dart` file no longer needs `geminiApiKey` (already removed).

### 4. New UI Screens (To Be Created)

The following screens need to be built:
- `InventoryV2ListPage` - Main inventory list
- `InventoryV2DetailPage` - Batch details and conversions
- `StockInPage` - Add stock with expiry/batch
- `QuickStockOutPage` - Quick stock removal
- `ExpiryDashboardPage` - Expiring/expired batches

---

## Migration Path

### Existing Data

- **Legacy `pharmacy_medicines`**: Existing records will work
- **Unit conversions**: Automatically synced from `pills_per_leaflet`/`leaflets_per_box` via trigger
- **Stock**: `stock_qty` remains the "surface" value used by customer RPC

### Backward Compatibility

✅ Customer flow (`find_best_pharmacies`) unchanged
✅ Existing `pharmacy_medicines` table structure preserved
✅ Old `InventoryPage` still works (keep until V2 stable)

---

## Testing Checklist

- [ ] Run all 3 SQL migrations successfully
- [ ] Deploy all 3 Edge Functions
- [ ] Set `GEMINI_API_KEY` secret
- [ ] Test prescription scanning (should use Edge Function)
- [ ] Test stock in with expiry date
- [ ] Test stock out (verify FEFO)
- [ ] Test batch merging (same batch_no + expiry)
- [ ] Test unit conversions sync from legacy fields
- [ ] Verify `stock_qty` syncs from batches
- [ ] Test ledger entries are created

---

## API Reference

### RPC Functions

#### `inventory_stock_in(pm_id, qty_base_units, expiry_date, batch_no?, buy_price?, notes?)`
- Returns: `batch_id`
- Merges if batch_no+expiry exists, else creates new batch
- Writes ledger entry

#### `inventory_stock_out(pm_id, qty_base_units, preferred_batch_id?, use_active_batch?, notes?)`
- Returns: `jsonb` allocation array
- Priority: preferred > active > FEFO
- Atomic with `FOR UPDATE SKIP LOCKED`
- Writes ledger + allocations

#### `inventory_move_between_batches(from_batch_id, to_batch_id, qty)`
- Moves qty between batches (correction tool)
- Verifies same medicine

### Edge Functions

#### `ai_extract_medicines`
- Input: `{image_base64, mime_type}`
- Output: `{medicines: [{name, generic_name, strength, form}]}`

#### `ai_parse_stock_text`
- Input: `{raw_text}`
- Output: `{items: [{name_raw, qty, unit_label, expiry_date, batch_no, buy_price_bdt, notes, confidence}]}`

#### `ai_extract_pack_hint`
- Input: `{image_base64, mime_type}`
- Output: `{unit_type, conversions: [{unit_label, multiplier_to_base}]}`

---

## Security Notes

- ✅ All RPCs use `SECURITY DEFINER` with ownership checks
- ✅ RLS policies enforce owner-only access
- ✅ Gemini API key stored server-side (never exposed to client)
- ✅ Edge Functions require Supabase auth (automatic)

---

## Next Steps

1. **Run migrations** in Supabase SQL Editor
2. **Deploy Edge Functions** via Supabase CLI
3. **Set GEMINI_API_KEY** secret
4. **Test prescription scanning** (should work via Edge Function)
5. **Build new UI screens** (see TODO in code)
6. **Gradually migrate** from old InventoryPage to V2

---

## Troubleshooting

### Edge Function Errors
- Check `GEMINI_API_KEY` is set: `supabase secrets list`
- Verify function deployed: `supabase functions list`
- Check logs: `supabase functions logs ai_extract_medicines`

### Database Errors
- Verify migrations ran: Check tables exist in Supabase dashboard
- Check RLS policies: Ensure owner can access their data
- Verify triggers: `stock_qty` should update when batches change

### Flutter Errors
- Ensure `EdgeFunctionGeminiService` is used (not `GeminiService`)
- Check Supabase client is initialized in `main.dart`
- Verify Edge Functions are deployed and accessible
