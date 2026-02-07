-- Enable trigram extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create trigram index on medicines name (speeds up fuzzy search)
CREATE INDEX IF NOT EXISTS idx_medicines_name_trgm 
ON public.medicines USING gin (name gin_trgm_ops);

-- Create a function for fuzzy medicine search
-- Returns medicines sorted by similarity score
CREATE OR REPLACE FUNCTION public.search_medicines_fuzzy(
  search_query TEXT,
  result_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  medicine_id INTEGER,
  name TEXT,
  generic_name TEXT,
  form TEXT,
  strength TEXT,
  manufacturer TEXT,
  price NUMERIC,
  similarity_score REAL
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.medicine_id,
    m.name,
    m.generic_name,
    m.form,
    m.strength,
    m.manufacturer,
    m.price,
    similarity(m.name, search_query) as similarity_score
  FROM public.medicines m
  WHERE 
    -- Use trigram similarity (handles typos)
    m.name % search_query
    OR m.name ILIKE search_query || '%'  -- Prefix match
    OR m.name ILIKE '%' || search_query || '%'  -- Contains match
  ORDER BY
    -- Exact match first
    CASE WHEN LOWER(m.name) = LOWER(search_query) THEN 0 ELSE 1 END,
    -- Then prefix match
    CASE WHEN m.name ILIKE search_query || '%' THEN 0 ELSE 1 END,
    -- Then by similarity score (higher is better)
    similarity(m.name, search_query) DESC,
    -- Then by name length (shorter names first)
    LENGTH(m.name),
    -- Finally alphabetical
    m.name
  LIMIT result_limit;
END;
$$;

-- Set the similarity threshold (0.3 is default, lower = more fuzzy)
-- You can adjust this: lower value = more results but less accurate
SELECT set_limit(0.2);

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.search_medicines_fuzzy TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_medicines_fuzzy TO anon;

COMMENT ON FUNCTION public.search_medicines_fuzzy IS 
'Fuzzy search for medicines using trigram similarity. 
Handles typos like "parcetamol" → "Paracetamol".
Returns results sorted by: exact match > prefix > similarity > length > alphabetical';
