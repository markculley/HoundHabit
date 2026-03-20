-- Files in Supabase Storage buckets
-- Shows bucket, path, size, and upload time for all stored files

SELECT
    bucket_id,
    name                                    AS path,
    ROUND((metadata->>'size')::numeric / 1024, 1) AS size_kb,
    created_at
FROM storage.objects
ORDER BY bucket_id, created_at DESC;
