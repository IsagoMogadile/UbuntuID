-- rls_initplan_performance
--
-- Row-level security policies called helper functions such as is_official(),
-- is_admin(), current_official_department_id() and auth.uid() directly, so
-- Postgres ran them once per row: counting 1,800 credentials as a
-- department official took ~3 s, and a dashboard firing several such counts
-- at once could pass the 8 s statement timeout ("dashboard refuses to load").
-- Wrapping each call as (select fn()) makes it an InitPlan, evaluated once
-- per query. The helpers are all STABLE with no arguments, so results are
-- identical -- only faster. Generated from pg_policies on 2026-10-09.

begin;

alter policy "appeals_select" on public."appeals"
  using (((citizen_id = (select current_citizen_id())) OR (department_id = (select current_official_department_id())) OR (select is_admin())));

alter policy "appeals_write" on public."appeals"
  using (((department_id = (select current_official_department_id())) OR (select is_admin())))
  with check (((department_id = (select current_official_department_id())) OR (select is_admin())));

alter policy "audit_select" on public."audit_logs"
  using ((select is_admin()));

alter policy "addr_select" on public."citizen_addresses"
  using (((citizen_id = (select current_citizen_id())) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())));

alter policy "addr_write" on public."citizen_addresses"
  using ((((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())));

alter policy "citizen_feedback_select_admin" on public."citizen_feedback"
  using ((select is_admin()));

alter policy "citizen_feedback_select_own" on public."citizen_feedback"
  using ((citizen_id = (select current_citizen_id())));

alter policy "citizens_insert" on public."citizens"
  with check ((((select is_official()) AND ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)) OR (select is_admin())));

alter policy "citizens_select" on public."citizens"
  using (((auth_user_id = (select auth.uid())) OR (select is_official()) OR (select is_admin())));

alter policy "citizens_select_organisation" on public."citizens"
  using (((select current_org_user_organisation_id()) IS NOT NULL));

alter policy "citizens_update" on public."citizens"
  using ((((select is_official()) AND ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)) OR (select is_admin())))
  with check ((((select is_official()) AND ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)) OR (select is_admin())));

alter policy "compliance_all" on public."compliance_audits"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "cg_select" on public."consent_grants"
  using (((citizen_id = (select current_citizen_id())) OR (organisation_id = (select current_org_id())) OR (select is_admin())));

alter policy "cg_write" on public."consent_grants"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "consent_grants_insert_organisation" on public."consent_grants"
  with check ((organisation_id = (select current_org_user_organisation_id())));

alter policy "credential_types_select" on public."credential_types"
  using ((((select auth.uid()) IS NOT NULL) OR (active = true)));

alter policy "credential_types_write" on public."credential_types"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "credentials_select" on public."credentials"
  using (((citizen_id = (select current_citizen_id())) OR (issuing_department_id = (select current_official_department_id())) OR (select is_admin())));

alter policy "credentials_select_organisation" on public."credentials"
  using ((((select current_org_user_organisation_id()) IS NOT NULL) AND (credential_type_id IN ( SELECT organisation_credential_scopes.credential_type_id
   FROM organisation_credential_scopes
  WHERE (organisation_credential_scopes.organisation_id = (select current_org_user_organisation_id()))))));

alter policy "credentials_write" on public."credentials"
  using (((issuing_department_id = (select current_official_department_id())) OR (select is_admin())))
  with check (((issuing_department_id = (select current_official_department_id())) OR (select is_admin())));

alter policy "dbe_nsc_results_select" on public."dbe_nsc_results"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'DBE'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dbe_nsc_results_select_organisation" on public."dbe_nsc_results"
  using ((((select current_org_user_organisation_id()) IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (organisation_credential_scopes ocs
     JOIN credential_types ct ON ((ct.credential_type_id = ocs.credential_type_id)))
  WHERE ((ocs.organisation_id = (select current_org_user_organisation_id())) AND (ct.type_code = 'NSC'::text))))));

alter policy "dbe_nsc_results_write" on public."dbe_nsc_results"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'DBE'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%basic education%'::text)));

alter policy "department_officials_select_colleagues" on public."department_officials"
  using ((department_id = (select current_official_department_id())));

alter policy "officials_select" on public."department_officials"
  using (((auth_user_id = (select auth.uid())) OR (select is_admin())));

alter policy "officials_write" on public."department_officials"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "departments_write" on public."departments"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "dha_death_records_select" on public."dha_death_records"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dha_death_records_write" on public."dha_death_records"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text)));

alter policy "dha_immigration_records_select" on public."dha_immigration_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dha_immigration_records_write" on public."dha_immigration_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)))
  with check (((select is_admin()) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)));

alter policy "dha_marital_records_select" on public."dha_marital_records"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text) OR (spouse_1_id = (select current_citizen_id_number())) OR (spouse_2_id = (select current_citizen_id_number()))));

alter policy "dha_marital_records_write" on public."dha_marital_records"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text)));

alter policy "dha_passports_select" on public."dha_passports"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dha_passports_write" on public."dha_passports"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%home affairs%'::text)));

alter policy "dhet_academic_records_select" on public."dhet_academic_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'DHET'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dhet_academic_records_select_organisation" on public."dhet_academic_records"
  using ((((select current_org_user_organisation_id()) IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (organisation_credential_scopes ocs
     JOIN credential_types ct ON ((ct.credential_type_id = ocs.credential_type_id)))
  WHERE ((ocs.organisation_id = (select current_org_user_organisation_id())) AND (ct.type_code = 'TERTIARY_QUALIFICATION'::text))))));

alter policy "dhet_academic_records_write" on public."dhet_academic_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'DHET'::text)))
  with check (((select is_admin()) OR ((select current_official_department_code()) = 'DHET'::text)));

alter policy "dhet_institutions_select" on public."dhet_institutions"
  using (((select auth.uid()) IS NOT NULL));

alter policy "dhet_institutions_write" on public."dhet_institutions"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'DHET'::text)))
  with check (((select is_admin()) OR ((select current_official_department_code()) = 'DHET'::text)));

alter policy "dhet_nsfas_funding_select" on public."dhet_nsfas_funding"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dhet_nsfas_funding_write" on public."dhet_nsfas_funding"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text)));

alter policy "dhet_student_enrollment_select" on public."dhet_student_enrollment"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dhet_student_enrollment_write" on public."dhet_student_enrollment"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%higher education%'::text)));

alter policy "docs_select" on public."documents"
  using (((citizen_id = (select current_citizen_id())) OR ((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())));

alter policy "docs_write" on public."documents"
  using ((((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'HOME_AFFAIRS'::text) OR (select is_admin())));

alter policy "dot_driver_licences_select" on public."dot_driver_licences"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'TRANSPORT'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "dot_driver_licences_write" on public."dot_driver_licences"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'TRANSPORT'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%transport%'::text)));

alter policy "dot_vehicles_select" on public."dot_vehicles"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%transport%'::text) OR (owner_id = (select current_citizen_id_number()))));

alter policy "dot_vehicles_write" on public."dot_vehicles"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%transport%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%transport%'::text)));

alter policy "flagged_records_delete" on public."flagged_records"
  using ((select is_admin()));

alter policy "flagged_records_insert" on public."flagged_records"
  with check ((select is_admin()));

alter policy "flagged_records_select" on public."flagged_records"
  using ((select is_admin()));

alter policy "flagged_records_update_admin" on public."flagged_records"
  using ((select is_admin()))
  with check (((select is_admin()) AND ((assigned_admin_id IS NULL) OR (EXISTS ( SELECT 1
   FROM ubuntuid_administrators a
  WHERE (a.admin_id = flagged_records.assigned_admin_id))))));

alter policy "ha_select" on public."housing_applications"
  using (((citizen_id = (select current_citizen_id())) OR ((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "ha_write" on public."housing_applications"
  using ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "hb_select" on public."housing_beneficiaries"
  using (((citizen_id = (select current_citizen_id())) OR ((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "hb_write" on public."housing_beneficiaries"
  using ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "housing_programmes_write" on public."housing_programmes"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "hs_data_defs_write" on public."human_settlement_data_definitions"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "hsr_select" on public."human_settlements_records"
  using (((citizen_id = (select current_citizen_id())) OR ((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "hsr_write" on public."human_settlements_records"
  using ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "labour_employment_records_select" on public."labour_employment_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'LABOUR'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "labour_employment_records_write" on public."labour_employment_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'LABOUR'::text)))
  with check (((select is_admin()) OR ((select current_official_department_code()) = 'LABOUR'::text)));

alter policy "notif_select" on public."notifications"
  using (((citizen_id = (select current_citizen_id())) OR (select is_admin())));

alter policy "notif_write" on public."notifications"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "organisation_credential_scopes_select" on public."organisation_credential_scopes"
  using (((select is_admin()) OR (organisation_id = (select current_org_user_organisation_id()))));

alter policy "organisation_employees_select" on public."organisation_employees"
  using (((select is_admin()) OR (organisation_id = (select current_org_user_organisation_id())) OR (citizen_id = (select current_citizen_id()))));

alter policy "organisation_employees_write" on public."organisation_employees"
  using (((select is_admin()) OR (organisation_id = (select current_org_user_organisation_id()))))
  with check (((select is_admin()) OR (organisation_id = (select current_org_user_organisation_id()))));

alter policy "ou_select" on public."organisation_users"
  using (((organisation_id = (select current_org_id())) OR (select is_admin())));

alter policy "ou_write" on public."organisation_users"
  using ((((organisation_id = (select current_org_id())) AND (select is_org_admin())) OR (select is_admin())))
  with check ((((organisation_id = (select current_org_id())) AND (select is_org_admin())) OR (select is_admin())));

alter policy "orgver_select" on public."organisation_verifications"
  using (((organisation_id = (select current_org_id())) OR (select is_admin())));

alter policy "orgver_write" on public."organisation_verifications"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "orgs_delete" on public."organisations"
  using ((select is_admin()));

alter policy "orgs_insert" on public."organisations"
  with check ((select is_admin()));

alter policy "orgs_select" on public."organisations"
  using (((organisation_id = (select current_org_id())) OR (select is_admin())));

alter policy "orgs_update" on public."organisations"
  using ((((organisation_id = (select current_org_id())) AND (select is_org_admin())) OR (select is_admin())))
  with check ((((organisation_id = (select current_org_id())) AND (select is_org_admin())) OR (select is_admin())));

alter policy "properties_select" on public."properties"
  using (((EXISTS ( SELECT 1
   FROM housing_beneficiaries hb
  WHERE ((hb.property_id = properties.property_id) AND (hb.citizen_id = (select current_citizen_id()))))) OR ((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "properties_write" on public."properties"
  using ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "saps_clearance_certificates_select" on public."saps_clearance_certificates"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%police%'::text) OR ((select current_official_department_name()) ~~* '%saps%'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "saps_clearance_certificates_write" on public."saps_clearance_certificates"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%police%'::text) OR ((select current_official_department_name()) ~~* '%saps%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%police%'::text) OR ((select current_official_department_name()) ~~* '%saps%'::text)));

alter policy "saps_criminal_records_select" on public."saps_criminal_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SAPS'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "saps_criminal_records_write" on public."saps_criminal_records"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SAPS'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%police%'::text) OR ((select current_official_department_name()) ~~* '%saps%'::text)));

alter policy "saps_wanted_persons_select" on public."saps_wanted_persons"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SAPS'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "saps_wanted_persons_write" on public."saps_wanted_persons"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SAPS'::text)))
  with check (((select is_admin()) OR ((select current_official_department_code()) = 'SAPS'::text)));

alter policy "sars_tax_returns_select" on public."sars_tax_returns"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%sars%'::text) OR ((tax_number)::text IN ( SELECT sars_taxpayers.tax_number
   FROM sars_taxpayers
  WHERE (sars_taxpayers.national_id_number = (select current_citizen_id_number()))))));

alter policy "sars_tax_returns_write" on public."sars_tax_returns"
  using (((select is_admin()) OR ((select current_official_department_name()) ~~* '%sars%'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%sars%'::text)));

alter policy "sars_taxpayers_select" on public."sars_taxpayers"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SARS'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "sars_taxpayers_write" on public."sars_taxpayers"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SARS'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%sars%'::text)));

alter policy "sassa_grants_select" on public."sassa_grants"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SASSA'::text) OR (national_id_number = (select current_citizen_id_number()))));

alter policy "sassa_grants_write" on public."sassa_grants"
  using (((select is_admin()) OR ((select current_official_department_code()) = 'SASSA'::text)))
  with check (((select is_admin()) OR ((select current_official_department_name()) ~~* '%sassa%'::text)));

alter policy "td_select" on public."title_deeds"
  using (((EXISTS ( SELECT 1
   FROM housing_beneficiaries hb
  WHERE ((hb.property_id = title_deeds.property_id) AND (hb.citizen_id = (select current_citizen_id()))))) OR ((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "td_write" on public."title_deeds"
  using ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())))
  with check ((((select current_official_department_code()) = 'DHS'::text) OR (select is_admin())));

alter policy "admins_select" on public."ubuntuid_administrators"
  using (((auth_user_id = (select auth.uid())) OR (select is_admin())));

alter policy "admins_write" on public."ubuntuid_administrators"
  using ((select is_admin()))
  with check ((select is_admin()));

alter policy "verification_requests_insert_org" on public."verification_requests"
  with check ((organisation_id = (select current_org_user_organisation_id())));

alter policy "verification_requests_select_admin" on public."verification_requests"
  using ((select is_admin()));

alter policy "verification_requests_select_citizen" on public."verification_requests"
  using ((citizen_id = (select current_citizen_id())));

alter policy "verification_requests_select_org" on public."verification_requests"
  using ((organisation_id = (select current_org_user_organisation_id())));

alter policy "verification_results_insert_org" on public."verification_results"
  with check ((EXISTS ( SELECT 1
   FROM verification_requests vr
  WHERE ((vr.request_id = verification_results.request_id) AND (vr.organisation_id = (select current_org_user_organisation_id()))))));

commit;
