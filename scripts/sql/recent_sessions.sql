-- Recent training sessions
-- Default: last 10. Override: make sql FILE=scripts/sql/recent_sessions.sql ARGS="-v N=25"

SELECT
    tr.recorded_at,
    p.name        AS pet,
    tr.status,
    tr.distance,
    tr.distraction,
    tr.duration,
    tr.notes,
    tr.is_shared
FROM training_records tr
JOIN pets p ON p.id = tr.pet_id
ORDER BY tr.recorded_at DESC
LIMIT :N;
