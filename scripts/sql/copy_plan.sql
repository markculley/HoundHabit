-- Duplicates a training plan (with its behaviors and items) into a new
-- lineage owned by the caller. Called from Swift via
-- `supabase.rpc("copy_plan", params: ["source_plan_id": ...])`.
--
-- Why server-side: doing the copy in plpgsql keeps plan/behavior/item
-- inserts atomic. A multi-step client-side copy could leave a half-built
-- plan if any insert failed.
--
-- Authorization: the caller must own the source plan
-- (training_plans.trainer_id = auth.uid()). RLS is bypassed by
-- security definer; the ownership check is enforced explicitly below.
--
-- Apply in the Supabase SQL editor, or via the Supabase MCP/CLI.

create or replace function public.copy_plan(source_plan_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  new_plan_id uuid;
  src_behavior record;
  new_behavior_id uuid;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if not exists (
    select 1 from training_plans
    where id = source_plan_id and trainer_id = uid
  ) then
    raise exception 'not authorized to copy this plan' using errcode = '42501';
  end if;

  -- 1. Duplicate the plan row, owned by the caller, with " (Copy)" appended.
  insert into training_plans (trainer_id, title, description)
  select uid, title || ' (Copy)', description
  from training_plans
  where id = source_plan_id
  returning id into new_plan_id;

  -- 2. Walk each source behavior, insert a duplicate, then copy its items
  --    with behavior_id remapped to the new behavior. Looping (rather than
  --    a single CTE) avoids needing a stable join key between old/new
  --    behaviors -- sort_order is not unique per plan.
  for src_behavior in
    select id, name, sort_order
    from behaviors
    where plan_id = source_plan_id
    order by sort_order, id
  loop
    insert into behaviors (plan_id, name, sort_order)
    values (new_plan_id, src_behavior.name, src_behavior.sort_order)
    returning id into new_behavior_id;

    insert into training_plan_items (
      plan_id, behavior_id, sort_order, title, description,
      distance, duration, distraction,
      distance_custom, duration_custom, distraction_custom
    )
    select
      new_plan_id, new_behavior_id, sort_order, title, description,
      distance, duration, distraction,
      distance_custom, duration_custom, distraction_custom
    from training_plan_items
    where plan_id = source_plan_id and behavior_id = src_behavior.id;
  end loop;

  -- 3. Copy any items not bound to a behavior (legacy / pre-Phase-12 plans).
  insert into training_plan_items (
    plan_id, behavior_id, sort_order, title, description,
    distance, duration, distraction,
    distance_custom, duration_custom, distraction_custom
  )
  select
    new_plan_id, null, sort_order, title, description,
    distance, duration, distraction,
    distance_custom, duration_custom, distraction_custom
  from training_plan_items
  where plan_id = source_plan_id and behavior_id is null;

  return new_plan_id;
end;
$$;

revoke all on function public.copy_plan(uuid) from public;
grant execute on function public.copy_plan(uuid) to authenticated;
