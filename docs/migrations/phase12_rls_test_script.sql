-- Phase 12 — RLS Verification Test Script
-- Run these queries in the Supabase SQL Editor while impersonating real users,
-- OR use the Supabase Dashboard → Auth → Users → "Impersonate" feature.
--
-- The SQL Editor runs as service_role (bypasses RLS).
-- These tests must be run with an actual user JWT to be meaningful.
-- Recommended: sign in with two guardian accounts and a trainer account in the
-- iOS app, capture their UUIDs from the `profiles` table, then use Postman or
-- the Supabase client with their JWTs to execute these queries.
--
-- ── Section 1: Guardian A cannot read Guardian B's data ────────────────────────
--
-- Run as Guardian A:
--
--   SELECT * FROM training_records WHERE guardian_id = '<guardian_B_uuid>';
--   -- Expected: 0 rows (RLS blocks cross-guardian reads)
--
--   SELECT * FROM pets WHERE guardian_id = '<guardian_B_uuid>';
--   -- Expected: 0 rows
--
--   SELECT * FROM resources WHERE guardian_id = '<guardian_B_uuid>';
--   -- Expected: 0 rows
--
-- ── Section 2: Unlinked trainer cannot read guardian data ──────────────────────
--
-- Run as Trainer (NOT linked to Guardian A):
--
--   SELECT * FROM training_records WHERE guardian_id = '<guardian_A_uuid>';
--   -- Expected: 0 rows (no active trainer_guardian_link)
--
--   SELECT * FROM pets WHERE guardian_id = '<guardian_A_uuid>';
--   -- Expected: 0 rows
--
-- ── Section 3: Linked trainer CAN read shared records ──────────────────────────
--
-- Run as Trainer (linked to Guardian A, with at least one is_shared=true record):
--
--   SELECT * FROM training_records WHERE guardian_id = '<guardian_A_uuid>';
--   -- Expected: rows where is_shared = true only
--
--   SELECT * FROM pets WHERE guardian_id = '<guardian_A_uuid>';
--   -- Expected: all of Guardian A's pets
--
-- ── Section 4: Guardian cannot write to another guardian's data ────────────────
--
-- Run as Guardian A:
--
--   INSERT INTO pets (guardian_id, name) VALUES ('<guardian_B_uuid>', 'Hack');
--   -- Expected: error (RLS WITH CHECK blocks inserting for another guardian)
--
--   UPDATE training_records SET notes = 'pwned'
--   WHERE guardian_id = '<guardian_B_uuid>';
--   -- Expected: 0 rows affected (no matching rows visible through RLS)
--
-- ── Section 5: Guardian reads assigned plan data ───────────────────────────────
--
-- Run as Guardian A (with an assigned plan):
--
--   SELECT * FROM training_plans;
--   -- Expected: only plans assigned to Guardian A
--
--   SELECT * FROM behaviors;
--   -- Expected: only behaviors belonging to plans assigned to Guardian A
--
--   SELECT * FROM training_plan_items;
--   -- Expected: only items in plans assigned to Guardian A
--
-- ── Section 6: Guardian cannot read unassigned plan data ──────────────────────
--
-- Run as Guardian A (plan P is NOT assigned to Guardian A):
--
--   SELECT * FROM training_plans WHERE id = '<plan_P_uuid>';
--   -- Expected: 0 rows
--
--   SELECT * FROM behaviors WHERE plan_id = '<plan_P_uuid>';
--   -- Expected: 0 rows
--
-- ── Section 7: Trainer cannot read another trainer's plans ────────────────────
--
-- Run as Trainer B:
--
--   SELECT * FROM training_plans WHERE trainer_id = '<trainer_A_uuid>';
--   -- Expected: 0 rows
--
-- ── Section 8: Guardian cannot advance another guardian's plan ─────────────────
--
-- Run as Guardian A:
--
--   UPDATE plan_assignments
--   SET current_item_id = '<some_item_uuid>'
--   WHERE guardian_id = '<guardian_B_uuid>';
--   -- Expected: 0 rows affected (no visible rows to update)
--
-- ── Known Limitation ────────────────────────────────────────────────────────────
--
-- invites_select_by_code uses qual=TRUE, meaning any authenticated user can
-- SELECT all rows from the `invites` table (exposing trainer emails and codes).
-- This is intentional for the "enter invite code" guardian flow but is a
-- data exposure risk. Mitigation for post-MVP: replace the direct table read
-- with a SECURITY DEFINER Postgres function that accepts a code and returns
-- only the matching invite row.
--
-- ── Service-role structural checks (safe to run in SQL Editor) ─────────────────

-- All tables must have RLS enabled:
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
-- Expected: rowsecurity = true for all 12 tables

-- No policy should use {public} role on sensitive tables:
SELECT tablename, policyname, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND roles = '{public}'
ORDER BY tablename;
-- Expected: 0 rows

-- All expected indexes exist:
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
-- Expected indexes present:
--   badges:              idx_badges_user_id
--   behaviors:           idx_behaviors_plan_id
--   comments:            idx_comments_training_record_id
--   invites:             idx_invites_code, idx_invites_trainer_id
--   pets:                idx_pets_guardian_id
--   plan_assignments:    idx_plan_assignments_current_item_id,
--                        idx_plan_assignments_guardian_id,
--                        idx_plan_assignments_plan_id
--   resources:           idx_materials_guardian_id
--   trainer_guardian_links: idx_tgl_guardian_id, idx_tgl_trainer_id
--   training_plan_items: idx_training_plan_items_behavior_id,
--                        idx_training_plan_items_plan_id
--   training_plans:      idx_training_plans_trainer_id
--   training_records:    idx_training_records_guardian_id,
--                        idx_training_records_pet_id,
--                        idx_training_records_plan_item_id,
--                        idx_training_records_recorded_at
