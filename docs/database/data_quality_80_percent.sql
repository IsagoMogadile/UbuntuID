-- data_quality_80_percent
--
-- Demo data split: 80% of citizens fully valid, 20% deliberately invalid.
-- Backup taken first: backups/<timestamp>_before_80pct/ (local, gitignored).
--
-- VALID (80%): chosen in priority order -- officials and administrators
-- (they are also citizens, matched by id_number), then citizens who
-- already have a login, then everyone else with the fewest problems;
-- deceased citizens are never chosen. For each:
--   * citizen active, email + phone filled in
--   * an activated login (email confirmed, password lower(firstname)@123,
--     the project's demo convention). Officials/admins keep their existing
--     staff login: linking it to their citizen row would make the app log
--     them in as a citizen (RoleService checks `citizens` first).
--   * licence Valid / passport Active (expiry pushed out if due within 6
--     months), clearance Clear, tax Compliant, SASSA Suspended -> Active,
--     and their credentials mirrored to 'active' with matching expiry.
--     Genuinely in-progress states are left alone (SASSA Pending, tertiary
--     Enrolled), and a Labour record's employment status is kept as is.
--
-- INVALID (20%): everyone else -- no login, and at least one clear
-- problem: if they have none already, their licence (or passport) is
-- expired, else tax Non-Compliant, else clearance Record Found, else the
-- citizen is suspended.

begin;

-- Rows that already break the age triggers (e.g. a licence issued before
-- age 17) can't be updated at all; they're skipped and left as they are.
create or replace function pg_temp._age_ok(p_id text, p_on date, p_min int) returns boolean
language sql stable as $$
  select coalesce((select extract(year from age(coalesce(p_on, current_date), date_of_birth)) >= p_min
                   from citizens where id_number = p_id), true);
$$;

create temp table _staff on commit drop as
  select id_number from department_officials where id_number is not null
  union select id_number from ubuntuid_administrators where id_number is not null;

create temp table _bad_cred on commit drop as
  select citizen_id, count(*) n
  from credentials
  where status in ('expired', 'suspended', 'revoked') or expiry_date < current_date
  group by 1;

create temp table _plan on commit drop as
with ranked as (
  select c.citizen_id,
         c.id_number in (select id_number from _staff) as is_staff,
         row_number() over (
           order by
             (c.current_status = 'deceased'),
             (c.id_number in (select id_number from _staff)) desc,
             (c.auth_user_id is not null) desc,
             exists (select 1 from credentials cr where cr.citizen_id = c.citizen_id) desc,
             coalesce((select n from _bad_cred b where b.citizen_id = c.citizen_id), 0),
             md5(c.citizen_id::text)
         ) as rn,
         count(*) over () as total
  from citizens c
)
select citizen_id, is_staff, case when rn <= round(total * 0.8) then 'valid' else 'invalid' end as grp
from ranked;

-- ---------------------------------------------------------------- VALID

update citizens c set current_status = 'active', is_active = true
from _plan p where p.citizen_id = c.citizen_id and p.grp = 'valid'
  and (c.current_status <> 'active' or not c.is_active);

with need as (
  select c.citizen_id,
         lower(regexp_replace(split_part(c.first_name, ' ', 1), '[^A-Za-z]', '', 'g')) as fn,
         lower(regexp_replace(c.last_name, '[^A-Za-z]', '', 'g')) as ln,
         row_number() over (order by c.citizen_id) as n
  from citizens c join _plan p using (citizen_id)
  where p.grp = 'valid' and c.email is null
)
update citizens c set email = need.fn || '.' || need.ln || need.n || '@gmail.com'
from need where need.citizen_id = c.citizen_id;

update citizens c set phone_number = '07' || lpad((abs(hashtext(c.citizen_id::text)) % 100000000)::text, 8, '0')
from _plan p where p.citizen_id = c.citizen_id and p.grp = 'valid' and c.phone_number is null;

create temp table _valid_ids on commit drop as
  select c.id_number from citizens c join _plan p using (citizen_id) where p.grp = 'valid';

update dot_driver_licences set status = 'Valid',
  expiry_date = case when expiry_date is null or expiry_date < current_date + 180
                     then current_date + 365 * (2 + abs(hashtext(licence_number)) % 4) else expiry_date end
where national_id_number in (select id_number from _valid_ids)
  and pg_temp._age_ok(national_id_number, issue_date, 17)
  and (status <> 'Valid' or expiry_date is null or expiry_date < current_date + 180);

update dha_passports set status = 'Active',
  expiry_date = case when expiry_date is null or expiry_date < current_date + 180
                     then current_date + 365 * (3 + abs(hashtext(passport_number)) % 7) else expiry_date end
where national_id_number in (select id_number from _valid_ids)
  and (status <> 'Active' or expiry_date is null or expiry_date < current_date + 180);

update saps_clearance_certificates set status = 'Clear'
where national_id_number in (select id_number from _valid_ids) and status <> 'Clear';

update sars_taxpayers set tax_compliance_status = 'Compliant'
where national_id_number in (select id_number from _valid_ids)
  and pg_temp._age_ok(national_id_number, registered_date, 18) and tax_compliance_status <> 'Compliant';

update sassa_grants set status = 'Active'
where national_id_number in (select id_number from _valid_ids) and status = 'Suspended'
  and (grant_type <> 'Old Age' or pg_temp._age_ok(national_id_number, current_date, 60));

-- Mirror credentials: active, with licence/passport expiry from the record.
update credentials cr set status = 'active'
from _plan p, credential_types ct
where p.citizen_id = cr.citizen_id and p.grp = 'valid' and ct.credential_type_id = cr.credential_type_id
  and cr.status in ('expired', 'suspended', 'revoked');

update credentials cr set expiry_date = d.expiry_date
from _plan p, credential_types ct, citizens c,
     lateral (select expiry_date from dot_driver_licences x where x.national_id_number = c.id_number
              order by created_at desc limit 1) d
where p.citizen_id = cr.citizen_id and p.grp = 'valid' and c.citizen_id = cr.citizen_id
  and ct.credential_type_id = cr.credential_type_id and ct.type_code = 'DRIVERS_LICENCE'
  and cr.expiry_date is distinct from d.expiry_date;

update credentials cr set expiry_date = d.expiry_date
from _plan p, credential_types ct, citizens c,
     lateral (select expiry_date from dha_passports x where x.national_id_number = c.id_number
              order by created_at desc limit 1) d
where p.citizen_id = cr.citizen_id and p.grp = 'valid' and c.citizen_id = cr.citizen_id
  and ct.credential_type_id = cr.credential_type_id and ct.type_code = 'PASSPORT'
  and cr.expiry_date is distinct from d.expiry_date;

update credentials cr set expiry_date = current_date + 730
from _plan p where p.citizen_id = cr.citizen_id and p.grp = 'valid' and cr.expiry_date < current_date + 180;

-- Activated logins for valid, non-staff citizens without one.
update citizens c set auth_user_id = _provision_auth_user(
  c.email,
  lower(regexp_replace(split_part(c.first_name, ' ', 1), '[^A-Za-z]', '', 'g')) || '@123',
  c.first_name || ' ' || c.last_name
)
from _plan p
where p.citizen_id = c.citizen_id and p.grp = 'valid' and not p.is_staff and c.auth_user_id is null;

-- -------------------------------------------------------------- INVALID

create temp table _fix on commit drop as
  select c.citizen_id, c.id_number,
    case
      when exists (select 1 from dot_driver_licences d where d.national_id_number = c.id_number) then 'licence'
      when exists (select 1 from dha_passports d where d.national_id_number = c.id_number) then 'passport'
      when exists (select 1 from sars_taxpayers d where d.national_id_number = c.id_number) then 'tax'
      when exists (select 1 from saps_clearance_certificates d where d.national_id_number = c.id_number) then 'clearance'
      else 'citizen'
    end as action
  from citizens c join _plan p using (citizen_id)
  where p.grp = 'invalid'
    and c.current_status = 'active'
    and not exists (select 1 from _bad_cred b where b.citizen_id = c.citizen_id);

update dot_driver_licences d set status = 'Expired',
  expiry_date = current_date - (30 + abs(hashtext(d.licence_number)) % 700)
from _fix f where f.action = 'licence' and d.national_id_number = f.id_number
  and pg_temp._age_ok(d.national_id_number, d.issue_date, 17);

update dha_passports d set status = 'Expired',
  expiry_date = current_date - (30 + abs(hashtext(d.passport_number)) % 700)
from _fix f where f.action = 'passport' and d.national_id_number = f.id_number;

update sars_taxpayers d set tax_compliance_status = 'Non-Compliant'
from _fix f where f.action = 'tax' and d.national_id_number = f.id_number
  and pg_temp._age_ok(d.national_id_number, d.registered_date, 18);

update saps_clearance_certificates d set status = 'Record Found'
from _fix f where f.action = 'clearance' and d.national_id_number = f.id_number;

update citizens c set current_status = 'suspended'
from _fix f where f.action = 'citizen' and c.citizen_id = f.citizen_id;

update credentials cr set
  status = case when f.action in ('licence', 'passport') then 'expired' else 'suspended' end,
  expiry_date = case f.action
    when 'licence' then (select expiry_date from dot_driver_licences d where d.national_id_number = f.id_number
                         order by created_at desc limit 1)
    when 'passport' then (select expiry_date from dha_passports d where d.national_id_number = f.id_number
                          order by created_at desc limit 1)
    else cr.expiry_date end
from _fix f, credential_types ct
where cr.citizen_id = f.citizen_id and ct.credential_type_id = cr.credential_type_id
  and ct.type_code = case f.action when 'licence' then 'DRIVERS_LICENCE' when 'passport' then 'PASSPORT'
                                   when 'tax' then 'TAX_COMPLIANCE' when 'clearance' then 'CRIMINAL_CLEARANCE' end;

commit;
