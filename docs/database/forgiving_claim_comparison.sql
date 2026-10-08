-- forgiving_claim_comparison
--
-- The organisation verification check (`_compare_credential_claim`) used to
-- match a claimed value only after lower()/trim(), so harmless formatting
-- differences counted as mismatches: 'Code B' vs 'B' (department records
-- store both styles), 'Non-Compliant' vs 'non compliant', 'Self Employed'
-- vs 'Self-Employed'. Organisations now pick most claims from dropdowns, and
-- this makes the comparison itself forgiving too:
--
--   * `_normalise_claim_value` lower-cases, drops a leading "code ", and
--     strips everything that isn't a letter or digit before comparing.
--   * qualification_name (still typed) also matches when either value
--     contains the other, e.g. 'Information Technology' vs
--     'National Diploma: Information Technology' (min 4 characters).
--   * result_status 'Graduated' also matches a final result of Pass, Merit
--     or Distinction -- a graduate's academic record holds the result, not
--     the word "graduated".
--   * SASSA's grant_type lookup uses the same normalisation.
--
-- Everything else in the function is unchanged.

create or replace function public._normalise_claim_value(p_value text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    regexp_replace(lower(trim(coalesce(p_value, ''))), '^code\s+', ''),
    '[^a-z0-9]', '', 'g'
  );
$$;

create or replace function public._claim_field_matches(p_field text, p_claimed text, p_verified text)
returns boolean
language plpgsql
immutable
as $$
declare
  c text := _normalise_claim_value(p_claimed);
  v text := _normalise_claim_value(p_verified);
begin
  if c = '' or v = '' then
    return false;
  end if;
  if c = v then
    return true;
  end if;
  if p_field = 'qualification_name' and length(c) >= 4 and length(v) >= 4
     and (position(c in v) > 0 or position(v in c) > 0) then
    return true;
  end if;
  if p_field = 'result_status' and c = 'graduated' and v in ('pass', 'merit', 'distinction') then
    return true;
  end if;
  return false;
end;
$$;

CREATE OR REPLACE FUNCTION public._compare_credential_claim(p_type_code text, p_national_id_number text, p_claimed jsonb, OUT p_verified jsonb, OUT p_match_status text)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row record;
  v_fields text[];
  v_matched int := 0;
  v_total int := 0;
  v_field text;
begin
  p_verified := null;
  p_match_status := 'not_found';

  case p_type_code
    when 'NSC' then
      select year, overall_pass_status into v_row
      from dbe_nsc_results where national_id_number = p_national_id_number
      order by year desc limit 1;
      if found then
        p_verified := jsonb_build_object('year', v_row.year, 'overall_pass_status', v_row.overall_pass_status);
      end if;

    when 'TERTIARY_QUALIFICATION' then
      select qualification_name, institution_code, final_result as result_status into v_row
      from dhet_academic_records where national_id_number = p_national_id_number
      order by year desc limit 1;
      if found then
        p_verified := jsonb_build_object(
          'qualification_name', v_row.qualification_name,
          'institution_code', v_row.institution_code,
          'result_status', v_row.result_status
        );
      else
        select qualification_name, institution_code, completion_status as result_status into v_row
        from dhet_student_enrollment where national_id_number = p_national_id_number
        order by created_at desc limit 1;
        if found then
          p_verified := jsonb_build_object(
            'qualification_name', v_row.qualification_name,
            'institution_code', v_row.institution_code,
            'result_status', v_row.result_status
          );
        end if;
      end if;

    when 'DRIVERS_LICENCE' then
      select licence_code, status into v_row
      from dot_driver_licences where national_id_number = p_national_id_number
      order by created_at desc limit 1;
      if found then
        p_verified := jsonb_build_object('licence_code', v_row.licence_code, 'status', v_row.status);
      end if;

    when 'PASSPORT' then
      select status into v_row
      from dha_passports where national_id_number = p_national_id_number
      order by created_at desc limit 1;
      if found then
        p_verified := jsonb_build_object('status', v_row.status);
      end if;

    when 'TAX_COMPLIANCE' then
      select tax_compliance_status into v_row
      from sars_taxpayers where national_id_number = p_national_id_number
      limit 1;
      if found then
        p_verified := jsonb_build_object('tax_compliance_status', v_row.tax_compliance_status);
      end if;

    when 'CRIMINAL_CLEARANCE' then
      select status into v_row
      from saps_clearance_certificates where national_id_number = p_national_id_number
      order by created_at desc limit 1;
      if found then
        p_verified := jsonb_build_object('status', v_row.status);
      end if;

    when 'LABOUR_STATUS' then
      select employment_status into v_row
      from labour_employment_records where national_id_number = p_national_id_number
      order by created_at desc limit 1;
      if found then
        p_verified := jsonb_build_object('employment_status', v_row.employment_status);
      end if;

    when 'SASSA_STATUS' then
      select grant_type, status into v_row
      from sassa_grants
      where national_id_number = p_national_id_number
        and _normalise_claim_value(grant_type) = _normalise_claim_value(p_claimed->>'grant_type')
      order by created_at desc limit 1;
      if found then
        p_verified := jsonb_build_object('grant_type', v_row.grant_type, 'status', v_row.status);
      end if;

    else
      p_verified := null;
  end case;

  if p_verified is null then
    p_match_status := 'not_found';
    return;
  end if;

  v_fields := array(select jsonb_object_keys(coalesce(p_claimed, '{}'::jsonb)));
  foreach v_field in array v_fields loop
    v_total := v_total + 1;
    if _claim_field_matches(v_field, p_claimed->>v_field, p_verified->>v_field) then
      v_matched := v_matched + 1;
    end if;
  end loop;

  p_match_status := case
    when v_total = 0 then 'not_found'
    when v_matched = v_total then 'exact_match'
    when v_matched = 0 then 'no_match'
    else 'partial_match'
  end;
end;
$function$;
