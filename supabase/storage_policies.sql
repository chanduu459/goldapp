-- Run this in Supabase SQL editor after creating bucket `goldJEWELLERY`.

-- Public read for product images.
DROP POLICY IF EXISTS "Public read gold jewelry images" ON storage.objects;
CREATE POLICY "Public read gold jewelry images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'goldJEWELLERY');

-- Authenticated users can upload product images.
DROP POLICY IF EXISTS "Authenticated upload gold jewelry images" ON storage.objects;
CREATE POLICY "Authenticated upload gold jewelry images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'goldJEWELLERY');

-- Authenticated users can update and delete their own uploaded images.
DROP POLICY IF EXISTS "Authenticated update own gold jewelry images" ON storage.objects;
CREATE POLICY "Authenticated update own gold jewelry images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'goldJEWELLERY' AND owner = auth.uid())
WITH CHECK (bucket_id = 'goldJEWELLERY' AND owner = auth.uid());

DROP POLICY IF EXISTS "Authenticated delete own gold jewelry images" ON storage.objects;
CREATE POLICY "Authenticated delete own gold jewelry images"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'goldJEWELLERY' AND owner = auth.uid());
