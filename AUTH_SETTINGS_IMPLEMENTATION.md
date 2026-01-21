# Auth + Profile Settings Implementation Summary

## Overview
Complete implementation of authentication flow with immutable roles and user preferences system.

---

## Database Changes (SQL)

**File:** `supabase_auth_preferences_patch.sql`

### Changes:
1. **Added `preferences` column** to `public.profiles` table (jsonb, default `{}`)
2. **Updated `handle_new_user` trigger** to read `role`, `full_name`, `phone` from `auth.users.raw_user_meta_data` at signup
3. **Added trigger to prevent role changes** after signup (`trg_prevent_role_change`)
4. **Updated RLS policy** to allow updates to `full_name`, `phone`, `preferences` but not `role`

### To Apply:
Run the SQL file in your Supabase SQL Editor:
```sql
-- Copy and paste contents of supabase_auth_preferences_patch.sql
```

---

## Flutter Code Changes

### New Files Created:

1. **`lib/presentation/pages/auth/signup_page.dart`**
   - Full signup form with role selection (customer/pharmacy_owner)
   - Collects: full_name, phone, email, password
   - Role is set at signup and stored in auth metadata

2. **`lib/presentation/pages/settings/settings_page.dart`**
   - Profile editing (full_name, phone)
   - Read-only display of email and role
   - Recommendation preferences:
     - Default radius (1000-20000m slider)
     - Sort mode (balanced/nearest/cheapest/most_matched)
     - Require full match toggle
     - Max results (5-50 slider)
   - Owner-only preferences:
     - Low stock threshold (1-100 slider)
     - Show low stock only toggle

3. **`lib/presentation/providers/settings_provider.dart`**
   - StateNotifier for managing settings updates
   - Handles profile + preferences updates
   - Invalidates `userProfileProvider` after save

### Modified Files:

1. **`lib/data/models/user_profile.dart`**
   - Added `preferences` field (Map<String, dynamic>)
   - Added helper getters: `defaultRadiusM`, `sortMode`, `requireFullMatch`, `maxResults`, `lowStockThreshold`, `showLowStockOnly`

2. **`lib/presentation/pages/auth/login_page.dart`**
   - Removed inline signup button
   - Added link to `/signup` page
   - Improved UI with validation

3. **`lib/config/router.dart`**
   - Added `/signup` route
   - Added `/settings` route
   - Enhanced redirect logic to block `/owner` for non-owners
   - Redirects root and auth pages based on role

4. **`lib/presentation/pages/pharmacy/pharmacy_finder_page.dart`**
   - Uses `defaultRadiusM` from preferences for RPC call
   - Applies client-side filtering (`requireFullMatch`)
   - Applies client-side sorting (`sortMode`: balanced/nearest/cheapest/most_matched)
   - Limits results to `maxResults`
   - CircleLayer radius uses user's `defaultRadiusM`

5. **`lib/presentation/pages/owner/inventory_page.dart`**
   - Filters inventory by `showLowStockOnly` preference
   - Highlights low stock items (orange warning icon) based on `lowStockThreshold`
   - Shows green check icon for items above threshold

6. **`lib/presentation/pages/home/home_page.dart`**
   - Added Settings button in AppBar actions

7. **`lib/presentation/pages/owner/owner_dashboard.dart`**
   - Added Settings button in AppBar actions

---

## Navigation Flow

### Signup Flow:
1. User visits `/login`
2. Clicks "Don't have an account? Create one" → navigates to `/signup`
3. Fills form: full_name, phone, email, password, selects role
4. Clicks "Create Account"
5. If email confirmation disabled: auto-login → router redirects to `/home` or `/owner` based on role
6. If email confirmation enabled: shows message → redirects to `/login`

### Login Flow:
1. User visits `/login`
2. Enters email + password
3. Clicks "Sign In"
4. Router checks `profile.role`:
   - `pharmacy_owner` → `/owner`
   - `customer` → `/home`

### Settings Access:
- **From HomePage**: Click Settings icon (⚙️) in AppBar → `/settings`
- **From OwnerDashboardPage**: Click Settings icon (⚙️) in AppBar → `/settings`

### Settings Page:
- **Profile Section**: Edit full_name, phone (read-only email, role)
- **Recommendation Preferences**: Adjust radius, sort mode, full match toggle, max results
- **Owner-Only Section**: Low stock threshold, show low stock only toggle (only visible if `role == 'pharmacy_owner'`)
- Click "Save Settings" → updates `profiles` table → refreshes UI

---

## Preference Application

### PharmacyFinderPage:
- **Radius**: Uses `defaultRadiusM` from preferences (default: 5000m)
- **Filtering**: If `requireFullMatch == true`, only shows pharmacies with all cart items
- **Sorting**: 
  - `balanced`: matched_items desc → distance asc → price asc
  - `nearest`: distance asc
  - `cheapest`: total_price asc
  - `most_matched`: matched_items desc
- **Limiting**: Shows max `maxResults` pharmacies (default: 20)

### InventoryPage (Owner):
- **Filtering**: If `showLowStockOnly == true`, only shows items where `stock_qty <= lowStockThreshold`
- **Visual Indicators**: 
  - Orange warning icon for low stock items
  - Green check icon for items above threshold

---

## Security Notes

1. **Role Immutability**: 
   - Database trigger prevents role changes after signup
   - RLS policy blocks role updates
   - Router blocks `/owner` route for non-owners

2. **Profile Updates**:
   - Only `full_name`, `phone`, `preferences` can be updated
   - `role` and `user_id` are immutable
   - Email is managed by Supabase Auth (read-only in app)

3. **Preferences Storage**:
   - Stored as JSONB in `profiles.preferences`
   - Defaults provided in `UserProfile` model if keys missing
   - Owner-only preferences only visible/editable for `pharmacy_owner` role

---

## Testing Checklist

- [ ] New user can sign up with role selection
- [ ] Profile row created with correct role/full_name/phone
- [ ] Role cannot be changed via UI or direct DB update
- [ ] Login routes correctly based on role
- [ ] Settings page accessible from both `/home` and `/owner`
- [ ] Settings save correctly and refresh profile
- [ ] PharmacyFinderPage uses preferences (radius, sorting, filtering)
- [ ] InventoryPage filters/highlights based on owner preferences
- [ ] Non-owners cannot access `/owner` route (redirected to `/home`)

---

## Files Changed Summary

**New Files:**
- `lib/presentation/pages/auth/signup_page.dart`
- `lib/presentation/pages/settings/settings_page.dart`
- `lib/presentation/providers/settings_provider.dart`
- `supabase_auth_preferences_patch.sql`

**Modified Files:**
- `lib/data/models/user_profile.dart`
- `lib/presentation/pages/auth/login_page.dart`
- `lib/config/router.dart`
- `lib/presentation/pages/pharmacy/pharmacy_finder_page.dart`
- `lib/presentation/pages/owner/inventory_page.dart`
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/owner/owner_dashboard.dart`

---

## Next Steps

1. **Run SQL patch** in Supabase SQL Editor
2. **Test signup flow** with both customer and pharmacy_owner roles
3. **Test settings** persistence and application
4. **Verify preferences** affect PharmacyFinderPage and InventoryPage as expected
5. **Test role immutability** by attempting to change role (should fail)
