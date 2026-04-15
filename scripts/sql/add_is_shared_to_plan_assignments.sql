-- Adds the is_shared flag to plan_assignments.
-- true  = guardian shares session records with the trainer (default for trainer-assigned plans)
-- false = guardian has opted out (default for self-assigned plans)
--
-- Run once in Supabase SQL editor.

ALTER TABLE plan_assignments
    ADD COLUMN IF NOT EXISTS is_shared boolean NOT NULL DEFAULT true;

-- Backfill: self-assigned rows (trainer_id = guardian_id) should default to false
UPDATE plan_assignments
    SET is_shared = false
    WHERE trainer_id = guardian_id;
