-- =========================================================
-- MediScan: Auth + Profile Settings with Immutable Roles
-- SQL Patch (Idempotent - safe to re-run)
-- =========================================================

-- ---------- 1) Add preferences column to profiles ----------
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS preferences jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Add index for common preference queries (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_preferences ON public.profiles USING gin (preferences);

-- ---------- 2) Update handle_new_user trigger to read metadata ----------
-- This trigger reads role, full_name, phone from auth.users.raw_user_meta_data
-- at signup time and inserts into profiles.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role text;
  user_full_name text;
  user_phone text;
BEGIN
  -- Extract metadata from auth.users.raw_user_meta_data
  user_role := COALESCE(new.raw_user_meta_data->>'role', 'customer');
  user_full_name := new.raw_user_meta_data->>'full_name';
  user_phone := new.raw_user_meta_data->>'phone';
  
  -- Insert profile with role, full_name, phone from metadata
  INSERT INTO public.profiles (user_id, role, full_name, phone, preferences)
  VALUES (
    new.id,
    user_role,
    user_full_name,
    user_phone,
    '{}'::jsonb
  )
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN new;
END;
$$;

-- Ensure trigger exists (idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ---------- 3) Revoke update on role column (immutable after signup) ----------
-- Drop existing update policy that allows role changes
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;

-- Create new update policy that explicitly excludes role
CREATE POLICY "Users update own profile"
ON public.profiles FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (
  user_id = auth.uid()
  AND (
    -- Explicitly prevent role updates by checking old role = new role
    -- This is enforced by RLS + application logic, but we add DB-level check
    role = (SELECT role FROM public.profiles WHERE user_id = auth.uid())
  )
);

-- Alternative: Use a trigger to prevent role changes (more robust)
CREATE OR REPLACE FUNCTION public.prevent_role_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- If role is being changed, raise error
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    RAISE EXCEPTION 'Role cannot be changed after signup. Current role: %', OLD.role;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_role_change ON public.profiles;
CREATE TRIGGER trg_prevent_role_change
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_role_change();

-- ---------- 4) Ensure preferences can be updated ----------
-- The existing "Users update own profile" policy already allows
-- updates to full_name, phone, and preferences (since they're not restricted).
-- No additional policy needed.

-- =========================================================
-- Summary of changes:
-- 1. Added preferences jsonb column with default {}
-- 2. Updated handle_new_user to read role/full_name/phone from metadata
-- 3. Added trigger to prevent role changes after signup
-- 4. Update policy allows full_name, phone, preferences (not role)
-- =========================================================
