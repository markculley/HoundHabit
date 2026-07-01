-- Allows trainers to add custom, free-text behaviors alongside the 12 standard
-- presets. Previously `behaviors.name` was locked to the 12 standard labels by
-- the `behaviors_name_valid_type` CHECK constraint; this swaps that closed list
-- for a sanity bound (non-empty, length-capped) so any trainer-typed name is
-- accepted while still keeping junk out.
--
-- The Swift `BehaviorType` enum now decodes any string: known labels map to
-- `.standard`, everything else to `.custom`. No data migration is needed —
-- existing rows hold valid standard names that still parse as `.standard`.
--
-- Apply in the Supabase SQL editor, or via the Supabase MCP/CLI.

alter table public.behaviors
    drop constraint if exists behaviors_name_valid_type;

alter table public.behaviors
    add constraint behaviors_name_nonempty
    check (char_length(btrim(name)) between 1 and 40);
