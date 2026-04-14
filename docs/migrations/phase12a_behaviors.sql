-- Phase 12a — Behaviors: add Behavior layer between Training Plans and Steps
-- Run in the Supabase SQL Editor (Dashboard → SQL Editor → New query)

-- 1. Create behaviors table
CREATE TABLE IF NOT EXISTS behaviors (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id     uuid        NOT NULL REFERENCES training_plans(id) ON DELETE CASCADE,
    name        text        NOT NULL,
    sort_order  integer     NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- 2. Add behavior_id FK to training_plan_items (nullable — existing rows have no behavior)
ALTER TABLE training_plan_items
    ADD COLUMN IF NOT EXISTS behavior_id uuid REFERENCES behaviors(id) ON DELETE CASCADE;

-- 3. Add custom value columns to training_plan_items for Three D's
ALTER TABLE training_plan_items
    ADD COLUMN IF NOT EXISTS distance_custom    text,
    ADD COLUMN IF NOT EXISTS duration_custom    text,
    ADD COLUMN IF NOT EXISTS distraction_custom text;

-- 4. Add custom value columns to training_records for Three D's
ALTER TABLE training_records
    ADD COLUMN IF NOT EXISTS distance_custom    text,
    ADD COLUMN IF NOT EXISTS duration_custom    text,
    ADD COLUMN IF NOT EXISTS distraction_custom text;

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_behaviors_plan_id
    ON behaviors(plan_id);

CREATE INDEX IF NOT EXISTS idx_training_plan_items_behavior_id
    ON training_plan_items(behavior_id);

-- 6. RLS on behaviors
ALTER TABLE behaviors ENABLE ROW LEVEL SECURITY;

-- Trainer: full access to behaviors belonging to their own plans
CREATE POLICY "Trainer full access to own plan behaviors"
    ON behaviors
    USING (
        plan_id IN (
            SELECT id FROM training_plans WHERE trainer_id = auth.uid()
        )
    )
    WITH CHECK (
        plan_id IN (
            SELECT id FROM training_plans WHERE trainer_id = auth.uid()
        )
    );

-- Guardian: read-only access to behaviors in plans assigned to them
CREATE POLICY "Guardian can read assigned plan behaviors"
    ON behaviors
    FOR SELECT
    USING (
        plan_id IN (
            SELECT plan_id FROM plan_assignments WHERE guardian_id = auth.uid()
        )
    );
