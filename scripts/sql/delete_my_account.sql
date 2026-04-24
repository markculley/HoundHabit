-- Apple Guideline 5.1.1(v): users must be able to initiate account deletion
-- from within the app. This function is called from Swift via
-- `supabase.rpc("delete_my_account")` and runs with elevated privileges so it
-- can touch auth.users.
--
-- Storage objects (pet photos, resource images, avatars) are intentionally
-- left behind — they live in private buckets keyed by user UUID and are
-- unreadable once the owning auth.user is gone. A periodic cleanup job can
-- sweep orphans later.
--
-- Apply in the Supabase SQL editor, or via `psql "$DB_URL" -f this_file.sql`.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- Child rows that reference the user. Explicit deletes (not relying on
  -- ON DELETE CASCADE) because not every FK in the schema cascades.
  delete from public.comments where author_id = uid;
  delete from public.plan_assignments where guardian_id = uid;
  delete from public.training_plan_items
    where plan_id in (select id from public.training_plans where trainer_id = uid);
  delete from public.training_plans where trainer_id = uid;
  delete from public.training_records where guardian_id = uid;
  delete from public.resources
    where owner_id = uid or added_by_id = uid or guardian_id = uid;
  delete from public.pets where guardian_id = uid;
  delete from public.trainer_guardian_links
    where trainer_id = uid or guardian_id = uid;
  delete from public.invites where trainer_id = uid;
  delete from public.badges where user_id = uid;
  delete from public.profiles where id = uid;

  -- Finally remove the auth row. This invalidates all sessions.
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
