-- Active sessions with last sign-in time
-- Useful for confirming sign in/out worked and session is persisted

SELECT
    u.email,
    u.last_sign_in_at,
    s.created_at  AS session_created,
    s.updated_at  AS session_updated
FROM auth.users u
LEFT JOIN auth.sessions s ON s.user_id = u.id
ORDER BY s.updated_at DESC;
