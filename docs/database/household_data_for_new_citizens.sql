-- Extends household coverage (properties/housing_beneficiaries/
-- citizen_addresses) to the 100+38 citizens added earlier this session,
-- which previously had none at all (flagged in docs/KNOWN_LIMITATIONS.md
-- as a deliberate-at-the-time scope call). Matches the original data's own
-- conventions: married couples share a property as owner/co_owner
-- (recorded in dha_marital_records already), everyone else groups into
-- households of 1-3, and title deeds/applications cover a similar partial
-- proportion as the original 152 citizens' households did (~18%/~20%), not
-- every household.
--
-- Result: 292 citizens, 118 properties (up from 51), 292 housing_
-- beneficiaries rows (every citizen covered), 24 title deeds (up from 9),
-- 54 housing applications (up from 15).
--
-- APPLIED live via the Supabase MCP (migration
-- `household_data_for_new_citizens_v2` -- v1 failed on a column/value
-- count mismatch in the title-deeds insert and rolled back atomically, no
-- partial data left behind).

create table public._seed_households (citizen_id uuid, id_number text, rn serial);

insert into public._seed_households (citizen_id, id_number)
select c.citizen_id, c.id_number
from citizens c
where not exists (select 1 from housing_beneficiaries hb where hb.citizen_id = c.citizen_id)
order by c.id_number;

create table public._seed_new_properties (property_id uuid, housing_status text);

-- Pass 1: married couples where both spouses still need a household
do $$
declare
  r record;
  v_property_id uuid;
  v_reference text;
  v_status text;
  v_ptype text;
  v_province text;
  statuses text[] := array['occupied','occupied','occupied','allocated','vacant'];
  ptypes text[] := array['house','flat','townhouse','serviced_stand'];
  provinces text[] := array['Gauteng','Western Cape','KwaZulu-Natal','Eastern Cape','Limpopo','Mpumalanga','Free State','North West','Northern Cape'];
  munis text[] := array['City of Johannesburg','City of Cape Town','eThekwini','Buffalo City','Polokwane','Mbombela','Mangaung','Rustenburg','Sol Plaatje'];
  idx int := 0;
begin
  for r in
    select m.spouse_1_id, m.spouse_2_id,
      s1.citizen_id as c1, s2.citizen_id as c2
    from dha_marital_records m
    join _seed_households s1 on s1.id_number = m.spouse_1_id
    join _seed_households s2 on s2.id_number = m.spouse_2_id
  loop
    idx := idx + 1;
    v_reference := next_property_reference();
    v_status := statuses[1 + (idx % array_length(statuses,1))];
    v_ptype := ptypes[1 + (idx % array_length(ptypes,1))];
    v_province := provinces[1 + (idx % array_length(provinces,1))];

    insert into properties (property_reference, suburb, city, municipality, province, property_type,
      property_value, housing_status)
    values (v_reference, 'Extension ' || (1+idx%12), munis[1 + (idx % array_length(munis,1))],
      munis[1 + (idx % array_length(munis,1))], v_province, v_ptype,
      350000 + floor(random()*650000)::int, v_status)
    returning property_id into v_property_id;

    insert into _seed_new_properties (property_id, housing_status) values (v_property_id, v_status);

    insert into housing_beneficiaries (citizen_id, property_id, beneficiary_role, start_date, active)
    values (r.c1, v_property_id, 'owner', current_date - (floor(random()*2000)::int || ' days')::interval, true);
    insert into housing_beneficiaries (citizen_id, property_id, beneficiary_role, start_date, active)
    values (r.c2, v_property_id, 'co_owner', current_date - (floor(random()*2000)::int || ' days')::interval, true);

    delete from _seed_households where citizen_id in (r.c1, r.c2);

    insert into citizen_addresses (citizen_id, address_type, street_name, suburb, city, municipality, province, is_current, effective_date)
    values (r.c1, 'residential', 'Extension ' || (1+idx%12) || ' Street', munis[1 + (idx % array_length(munis,1))],
      munis[1 + (idx % array_length(munis,1))], munis[1 + (idx % array_length(munis,1))], v_province, true, current_date - interval '1 year');
    insert into citizen_addresses (citizen_id, address_type, street_name, suburb, city, municipality, province, is_current, effective_date)
    values (r.c2, 'residential', 'Extension ' || (1+idx%12) || ' Street', munis[1 + (idx % array_length(munis,1))],
      munis[1 + (idx % array_length(munis,1))], munis[1 + (idx % array_length(munis,1))], v_province, true, current_date - interval '1 year');
  end loop;
end $$;

-- Pass 2: everyone left over -- households of 1-3, first is owner
do $$
declare
  r record;
  v_property_id uuid;
  v_reference text;
  v_status text;
  v_ptype text;
  v_province text;
  v_muni text;
  v_street text;
  statuses text[] := array['occupied','occupied','allocated','vacant','completed'];
  ptypes text[] := array['house','flat','townhouse','serviced_stand','other'];
  roles text[] := array['occupant','beneficiary'];
  provinces text[] := array['Gauteng','Western Cape','KwaZulu-Natal','Eastern Cape','Limpopo','Mpumalanga','Free State','North West','Northern Cape'];
  munis text[] := array['City of Johannesburg','City of Cape Town','eThekwini','Buffalo City','Polokwane','Mbombela','Mangaung','Rustenburg','Sol Plaatje','Tshwane'];
  household_size int;
  members uuid[];
  member_id uuid;
  i int;
  idx int := 0;
begin
  while exists (select 1 from _seed_households) loop
    idx := idx + 1;
    household_size := 1 + floor(random()*3)::int; -- 1..3

    select array_agg(citizen_id) into members
    from (select citizen_id from _seed_households order by rn limit household_size) x;

    v_reference := next_property_reference();
    v_status := statuses[1 + (idx % array_length(statuses,1))];
    v_ptype := ptypes[1 + (idx % array_length(ptypes,1))];
    v_province := provinces[1 + (idx % array_length(provinces,1))];
    v_muni := munis[1 + (idx % array_length(munis,1))];
    v_street := (1+idx%12) || ' Ubuntu Street';

    insert into properties (property_reference, street_number, street_name, suburb, city, municipality, province,
      property_type, property_value, housing_status)
    values (v_reference, (100+idx)::text, 'Ubuntu Street', v_muni, v_muni, v_muni, v_province, v_ptype,
      280000 + floor(random()*520000)::int, v_status)
    returning property_id into v_property_id;

    insert into _seed_new_properties (property_id, housing_status) values (v_property_id, v_status);

    for i in 1 .. array_length(members,1) loop
      member_id := members[i];
      insert into housing_beneficiaries (citizen_id, property_id, beneficiary_role, start_date, active)
      values (member_id, v_property_id, case when i = 1 then 'owner' else roles[1 + (i % 2)] end,
        current_date - (floor(random()*2000)::int || ' days')::interval, true);

      insert into citizen_addresses (citizen_id, address_type, street_number, street_name, suburb, city, municipality, province, is_current, effective_date)
      values (member_id, 'residential', (100+idx)::text, 'Ubuntu Street', v_muni, v_muni, v_muni, v_province, true,
        current_date - interval '1 year');

      delete from _seed_households where citizen_id = member_id;
    end loop;
  end loop;
end $$;

-- Title deeds for ~18% of the new properties (matches original ~9/51 ratio)
do $$
declare
  r record;
  v_deed_num text;
  v_owner_name text;
begin
  for r in select property_id from _seed_new_properties where random() < 0.18 loop
    select c.first_name || ' ' || c.last_name into v_owner_name
    from housing_beneficiaries hb
    join citizens c on c.citizen_id = hb.citizen_id
    where hb.property_id = r.property_id and hb.beneficiary_role = 'owner'
    limit 1;
    continue when v_owner_name is null;

    v_deed_num := generate_title_deed_number();
    insert into title_deeds (property_id, title_deed_number, deed_type, registration_date,
      registered_owner_name, registration_status, deed_status, deed_issued_date)
    values (r.property_id, v_deed_num, 'title_deed', current_date - (floor(random()*1500)::int || ' days')::interval,
      v_owner_name, 'registered', 'active', current_date - (floor(random()*1500)::int || ' days')::interval);
  end loop;
end $$;

-- Housing applications for ~20% of the new citizens
do $$
declare
  r record;
  v_ref text;
  v_prog uuid;
  statuses text[] := array['submitted','under_review','approved','allocated','completed'];
begin
  for r in
    select hb.citizen_id, p.municipality, p.province
    from housing_beneficiaries hb
    join properties p on p.property_id = hb.property_id
    where hb.property_id in (select property_id from _seed_new_properties)
    and random() < 0.20
  loop
    v_ref := generate_housing_application_reference();
    select programme_id into v_prog from housing_programmes order by random() limit 1;
    insert into housing_applications (citizen_id, programme_id, application_reference, application_status,
      application_date, municipality, province, household_size, household_income)
    values (r.citizen_id, v_prog, v_ref, statuses[1 + floor(random()*array_length(statuses,1))::int],
      current_date - (floor(random()*900)::int || ' days')::interval, r.municipality, r.province,
      1 + floor(random()*4)::int, 3000 + floor(random()*15000)::int);
  end loop;
end $$;

drop table public._seed_households;
drop table public._seed_new_properties;
