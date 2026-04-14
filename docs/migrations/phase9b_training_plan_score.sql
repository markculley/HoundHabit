-- Phase 9b — Training Plan: Three D's on steps, score on records, current step on assignments
-- Run in the Supabase SQL Editor (Dashboard → SQL Editor → New query)

-- 1. Add Distance / Duration / Distraction columns to training_plan_items.
--    Defaults match the lowest-difficulty enum values so existing rows remain valid.
ALTER TABLE training_plan_items
  ADD COLUMN IF NOT EXISTS distance    text NOT NULL DEFAULT 'arms_length',
  ADD COLUMN IF NOT EXISTS duration    text NOT NULL DEFAULT 'instant',
  ADD COLUMN IF NOT EXISTS distraction text NOT NULL DEFAULT 'none';

-- 2. Add rep score (0–5) and optional plan step link to training_records.
ALTER TABLE training_records
  ADD COLUMN IF NOT EXISTS score        integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS plan_item_id uuid    REFERENCES training_plan_items(id) ON DELETE SET NULL;

-- 3. Add current step pointer to plan_assignments (the "Memory Bank").
ALTER TABLE plan_assignments
  ADD COLUMN IF NOT EXISTS current_item_id uuid REFERENCES training_plan_items(id) ON DELETE SET NULL;

-- 4. Indexes for the new FK and score column.
CREATE INDEX IF NOT EXISTS idx_training_records_plan_item_id
  ON training_records(plan_item_id);

CREATE INDEX IF NOT EXISTS idx_plan_assignments_current_item_id
  ON plan_assignments(current_item_id);
