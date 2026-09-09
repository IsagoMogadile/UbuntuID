-- Same convention as auto_generated_official_identifiers.sql -- a Human
-- Settlements official never types a property reference, title deed
-- number, or housing application reference by hand. Sequence starts after
-- the live max property_reference (51) at the time this was applied;
-- title deed numbers and application references aren't sequential in the
-- existing seed data (format `T#####/YYYY`, `DHS-YYYY-#####`), so those
-- are random-and-retried-until-unique instead, same as VIN/number-plate
-- generation.
--
-- APPLIED live via the Supabase MCP (migration
-- `human_settlements_identifier_generators`).

create sequence public.dhs_property_seq start with 52;

create or replace function public.next_property_reference()
returns text language sql as $$
  select 'PROP-' || lpad(nextval('public.dhs_property_seq')::text, 5, '0');
$$;

create or replace function public.generate_title_deed_number()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := 'T' || lpad(floor(random()*99999)::text, 5, '0') || '/' || to_char(current_date, 'YYYY');
    exit when not exists (select 1 from title_deeds where title_deed_number = v);
  end loop;
  return v;
end;
$$;

create or replace function public.generate_housing_application_reference()
returns text language plpgsql as $$
declare
  v text;
begin
  loop
    v := 'DHS-' || to_char(current_date, 'YYYY') || '-' || lpad(floor(random()*99999)::text, 5, '0');
    exit when not exists (select 1 from housing_applications where application_reference = v);
  end loop;
  return v;
end;
$$;

grant execute on function public.next_property_reference() to authenticated;
grant execute on function public.generate_title_deed_number() to authenticated;
grant execute on function public.generate_housing_application_reference() to authenticated;
