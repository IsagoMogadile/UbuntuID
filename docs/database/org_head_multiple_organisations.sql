-- org_head_multiple_organisations
--
-- A citizen may head, or work at, more than one organisation. Being
-- employed somewhere, or already heading an organisation, must not block
-- registering another one. Each organisation account is still its own
-- sign-in (its own email), so organisation_users.auth_user_id stays unique.
--
-- What changes:
--   1. Any unique rule on organisation_users that covers only id_number is
--      dropped (it made a second registration by the same citizen fail
--      with "This already exists").
--   2. In its place: a person appears at most once *per organisation*,
--      which is what request_staff already checks.
--
-- Safe to run more than once.
--
-- APPLIED 2026-10-10 via the Supabase MCP. The rule dropped was
-- organisation_users_id_number_key.

do $$
declare
  r record;
begin
  -- Unique constraints on exactly (id_number)
  for r in
    select con.conname
    from pg_constraint con
    where con.conrelid = 'public.organisation_users'::regclass
      and con.contype = 'u'
      and (select array_agg(a.attname::text order by a.attname)
           from pg_attribute a
           where a.attrelid = con.conrelid and a.attnum = any(con.conkey)) = array['id_number']
  loop
    execute format('alter table public.organisation_users drop constraint %I', r.conname);
    raise notice 'Dropped constraint %', r.conname;
  end loop;

  -- Unique indexes on exactly (id_number) not backing a constraint
  for r in
    select ic.relname as indexname
    from pg_index i
    join pg_class ic on ic.oid = i.indexrelid
    where i.indrelid = 'public.organisation_users'::regclass
      and i.indisunique and not i.indisprimary
      and not exists (select 1 from pg_constraint c where c.conindid = i.indexrelid)
      and (select array_agg(a.attname::text order by a.attname)
           from pg_attribute a
           where a.attrelid = i.indrelid and a.attnum = any(i.indkey)) = array['id_number']
  loop
    execute format('drop index public.%I', r.indexname);
    raise notice 'Dropped index %', r.indexname;
  end loop;
end $$;

create unique index if not exists organisation_users_org_id_number_key
  on public.organisation_users (organisation_id, id_number);

-- Shows the unique rules left on the organisation tables. If registration
-- still says "already exists", the clashing column is in this list.
select tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename in ('organisations', 'organisation_users', 'organisation_credential_scopes')
  and indexdef ilike '%unique%'
order by tablename, indexname;
