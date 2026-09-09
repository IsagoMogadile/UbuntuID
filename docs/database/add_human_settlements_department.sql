-- Human Settlements existed only as data (properties/housing_beneficiaries/
-- title_deeds/housing_applications/human_settlements_records), explicitly
-- documented as having no department or official ("housing/property data
-- exists purely to model realistic citizen households... not as a
-- departmental workflow" -- docs/PROJECT_SCOPE.md §5, docs/
-- KNOWN_LIMITATIONS.md).
--
-- RLS on all 5 tables already gated writes on
-- `current_official_department_code() = 'DHS'` (from an earlier session
-- that anticipated this department -- `department_category.dart`'s doc
-- comment already listed 'housing' among confirmed live `departments
-- .category` values) -- the `departments` row with that code was simply
-- never created, and no Flutter screen read/wrote these tables as an
-- official. This migration is that one row; everything else (dashboard
-- category, record types, identifier generators) is `lib/features/
-- department_official/` code + docs/database/
-- human_settlements_identifier_generators.sql.
--
-- APPLIED live via the Supabase MCP (migration
-- `add_human_settlements_department`).

insert into departments (department_code, department_name, category, active)
values ('DHS', 'Department of Human Settlements', 'housing', true);
