-- Multi-tenant unique-constraint fix
-- Run this in Supabase SQL editor.
-- Goal:
-- 1) Different tenants can reuse same names/slugs.
-- 2) Same tenant cannot create duplicate category/collection names or slugs.

BEGIN;

-- Drop old global unique indexes (if created by previous script runs) so reruns are safe.
DROP INDEX IF EXISTS public.uq_categories_tenant_name_ci;
DROP INDEX IF EXISTS public.uq_categories_tenant_slug_ci;
DROP INDEX IF EXISTS public.uq_collections_tenant_name_ci;
DROP INDEX IF EXISTS public.uq_collections_tenant_slug_ci;

-- Drop common legacy unique constraints if present.
ALTER TABLE IF EXISTS public.categories DROP CONSTRAINT IF EXISTS categories_name_key;
ALTER TABLE IF EXISTS public.categories DROP CONSTRAINT IF EXISTS categories_slug_key;
ALTER TABLE IF EXISTS public.collections DROP CONSTRAINT IF EXISTS collections_name_key;
ALTER TABLE IF EXISTS public.collections DROP CONSTRAINT IF EXISTS collections_slug_key;
ALTER TABLE IF EXISTS public.metals DROP CONSTRAINT IF EXISTS metals_name_key;

-- Drop any other old UNIQUE constraints on name/slug for these tables.
DO $$
DECLARE
  constraint_row RECORD;
BEGIN
  FOR constraint_row IN
    SELECT
      cls.relname AS table_name,
      con.conname AS constraint_name
    FROM pg_constraint con
    JOIN pg_class cls ON cls.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = cls.relnamespace
    JOIN unnest(con.conkey) AS k(attnum) ON TRUE
    JOIN pg_attribute attr ON attr.attrelid = con.conrelid AND attr.attnum = k.attnum
    WHERE ns.nspname = 'public'
      AND con.contype = 'u'
      AND cls.relname IN ('categories', 'collections', 'metals')
      AND attr.attname IN ('name', 'slug')
  LOOP
    EXECUTE format(
      'ALTER TABLE public.%I DROP CONSTRAINT IF EXISTS %I',
      constraint_row.table_name,
      constraint_row.constraint_name
    );
  END LOOP;
END
$$;

-- -------------------------------------------------------------------------
-- Cleanup existing duplicates for collections by normalized name.
-- Keep the smallest id, repoint all foreign keys, then delete duplicates.
-- -------------------------------------------------------------------------
CREATE TEMP TABLE tmp_collection_merge AS
WITH ranked AS (
  SELECT
    id,
    first_value(id) OVER (
      PARTITION BY tenant_id, lower(btrim(name))
      ORDER BY id
    ) AS keep_id,
    row_number() OVER (
      PARTITION BY tenant_id, lower(btrim(name))
      ORDER BY id
    ) AS rn
  FROM public.collections
)
SELECT id AS duplicate_id, keep_id
FROM ranked
WHERE rn > 1;

DO $$
DECLARE
  fk RECORD;
BEGIN
  FOR fk IN
    SELECT
      ns.nspname AS schema_name,
      cls.relname AS table_name,
      att.attname AS column_name
    FROM pg_constraint con
    JOIN pg_class cls ON cls.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = cls.relnamespace
    JOIN unnest(con.conkey) WITH ORDINALITY AS ck(attnum, ord) ON TRUE
    JOIN unnest(con.confkey) WITH ORDINALITY AS fkkey(attnum, ord)
      ON fkkey.ord = ck.ord
    JOIN pg_attribute att
      ON att.attrelid = con.conrelid
     AND att.attnum = ck.attnum
    WHERE con.contype = 'f'
      AND con.confrelid = 'public.collections'::regclass
  LOOP
    EXECUTE format(
      'UPDATE %I.%I t
          SET %I = m.keep_id
         FROM tmp_collection_merge m
        WHERE t.%I = m.duplicate_id',
      fk.schema_name,
      fk.table_name,
      fk.column_name,
      fk.column_name
    );
  END LOOP;
END
$$;

DELETE FROM public.collections c
USING tmp_collection_merge m
WHERE c.id = m.duplicate_id;

-- Ensure slug uniqueness per tenant by normalizing duplicate slugs.
WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY tenant_id, lower(btrim(slug))
      ORDER BY id
    ) AS rn
  FROM public.collections
  WHERE slug IS NOT NULL
)
UPDATE public.collections c
SET slug = CASE
  WHEN btrim(coalesce(c.slug, '')) = '' THEN concat('collection-', c.id)
  ELSE concat(lower(btrim(c.slug)), '-', c.id)
END
FROM ranked r
WHERE c.id = r.id
  AND r.rn > 1;

-- -------------------------------------------------------------------------
-- Cleanup existing duplicates for categories by normalized name.
-- Keep the smallest id, repoint all foreign keys, then delete duplicates.
-- -------------------------------------------------------------------------
CREATE TEMP TABLE tmp_category_merge AS
WITH ranked AS (
  SELECT
    id,
    first_value(id) OVER (
      PARTITION BY tenant_id, lower(btrim(name))
      ORDER BY id
    ) AS keep_id,
    row_number() OVER (
      PARTITION BY tenant_id, lower(btrim(name))
      ORDER BY id
    ) AS rn
  FROM public.categories
)
SELECT id AS duplicate_id, keep_id
FROM ranked
WHERE rn > 1;

DO $$
DECLARE
  fk RECORD;
BEGIN
  FOR fk IN
    SELECT
      ns.nspname AS schema_name,
      cls.relname AS table_name,
      att.attname AS column_name
    FROM pg_constraint con
    JOIN pg_class cls ON cls.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = cls.relnamespace
    JOIN unnest(con.conkey) WITH ORDINALITY AS ck(attnum, ord) ON TRUE
    JOIN unnest(con.confkey) WITH ORDINALITY AS fkkey(attnum, ord)
      ON fkkey.ord = ck.ord
    JOIN pg_attribute att
      ON att.attrelid = con.conrelid
     AND att.attnum = ck.attnum
    WHERE con.contype = 'f'
      AND con.confrelid = 'public.categories'::regclass
  LOOP
    EXECUTE format(
      'UPDATE %I.%I t
          SET %I = m.keep_id
         FROM tmp_category_merge m
        WHERE t.%I = m.duplicate_id',
      fk.schema_name,
      fk.table_name,
      fk.column_name,
      fk.column_name
    );
  END LOOP;
END
$$;

DELETE FROM public.categories c
USING tmp_category_merge m
WHERE c.id = m.duplicate_id;

-- Ensure slug uniqueness per tenant by normalizing duplicate slugs.
WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY tenant_id, lower(btrim(slug))
      ORDER BY id
    ) AS rn
  FROM public.categories
  WHERE slug IS NOT NULL
)
UPDATE public.categories c
SET slug = CASE
  WHEN btrim(coalesce(c.slug, '')) = '' THEN concat('category-', c.id)
  ELSE concat(lower(btrim(c.slug)), '-', c.id)
END
FROM ranked r
WHERE c.id = r.id
  AND r.rn > 1;

-- -------------------------------------------------------------------------
-- Create tenant-scoped unique indexes.
-- -------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_tenant_name_ci
  ON public.categories (tenant_id, lower(btrim(name)));

CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_tenant_slug_ci
  ON public.categories (tenant_id, lower(btrim(slug)));

CREATE UNIQUE INDEX IF NOT EXISTS uq_collections_tenant_name_ci
  ON public.collections (tenant_id, lower(btrim(name)));

CREATE UNIQUE INDEX IF NOT EXISTS uq_collections_tenant_slug_ci
  ON public.collections (tenant_id, lower(btrim(slug)));

COMMIT;

-- Verify no duplicates remain:
-- collections by name
-- SELECT tenant_id, lower(btrim(name)) AS key, COUNT(*)
-- FROM public.collections
-- GROUP BY tenant_id, lower(btrim(name))
-- HAVING COUNT(*) > 1;
--
-- categories by name
-- SELECT tenant_id, lower(btrim(name)) AS key, COUNT(*)
-- FROM public.categories
-- GROUP BY tenant_id, lower(btrim(name))
-- HAVING COUNT(*) > 1;
