import 'package:flutter/material.dart' show IconData, Icons;

import '../../../core/utils/age_utils.dart';
import '../../../core/utils/sa_id_generator.dart';
import '../../shared/domain/citizen_lookup_result.dart';
import '../data/department_repository.dart';

/// Resolves a [RecordTypeConfig.icon] name string to the real [IconData] --
/// shared by the record-list UI (department_citizen_records_screen.dart)
/// and `DepartmentRepository.getServices()`, which builds the Department
/// Services list directly from these record types rather than from
/// `credential_types` (previously every department showed at most one
/// service tile, since most departments only have one verifiable
/// credential type -- see docs/KNOWN_LIMITATIONS.md).
const recordTypeIconByName = <String, IconData>{
  'favorite_outline': Icons.favorite_outline,
  'event_busy_outlined': Icons.event_busy_outlined,
  'menu_book_outlined': Icons.menu_book_outlined,
  'badge_outlined': Icons.badge_outlined,
  'directions_car_outlined': Icons.directions_car_outlined,
  'account_balance_outlined': Icons.account_balance_outlined,
  'receipt_long_outlined': Icons.receipt_long_outlined,
  'gavel_outlined': Icons.gavel_outlined,
  'verified_outlined': Icons.verified_outlined,
  'school_outlined': Icons.school_outlined,
  'payments_outlined': Icons.payments_outlined,
  'volunteer_activism_outlined': Icons.volunteer_activism_outlined,
  'work_outline': Icons.work_outline,
  'flight_land_outlined': Icons.flight_land_outlined,
  'workspace_premium_outlined': Icons.workspace_premium_outlined,
  'home_work_outlined': Icons.home_work_outlined,
  'home_outlined': Icons.home_outlined,
  'description_outlined': Icons.description_outlined,
  'assignment_outlined': Icons.assignment_outlined,
};

enum RecordFieldType { text, number, date, dropdown, boolean }

class RecordField {
  const RecordField({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.optional = false,
  });

  final String key;
  final String label;
  final RecordFieldType type;
  final List<String>? options;

  /// When true, this field's form control isn't required -- used for the
  /// mature-age-exemption reason, which only needs a value when the
  /// exemption itself is ticked (checked in `validate`, not the form's
  /// built-in "Required" rule).
  final bool optional;
}

/// One record type a department official can view/create for a searched
/// citizen (e.g. "Passport" under Home Affairs). [fetchExisting] and
/// [buildInsertData] are closures rather than a fixed column-name shape so
/// the handful of tables that don't key directly off the citizen's ID
/// number (SARS tax returns via `tax_number`) still fit the same UI. Note:
/// identifiers assigned by the department itself (passport number, licence
/// number, VIN, tax number, case number, matric exam number) are never a
/// [RecordField] here -- they're server-generated inside the dedicated
/// `DepartmentRepository` issue/update methods, not typed by the official.
///
/// [idColumn] + [buildUpdateData] are optional -- when both are set, tapping
/// an existing row opens the same form pre-filled for editing (e.g. revoking
/// a passport, updating a tax return's filing status) instead of only ever
/// creating new rows. [buildDelete] optionally adds a "Remove" action
/// (SASSA grants only, per spec: "add, manage update remove").
class RecordTypeConfig {
  const RecordTypeConfig({
    required this.label,
    required this.icon,
    required this.fields,
    required this.fetchExisting,
    required this.rowTitle,
    required this.rowSubtitle,
    this.buildInsertData,
    this.idColumn,
    this.table,
    this.buildUpdateData,
    this.buildDelete,
    this.validate,
  });

  final String label;
  final String icon; // material icon name, resolved in the widget
  final List<RecordField> fields;
  final Future<List<Map<String, dynamic>>> Function(DepartmentRepository repo, CitizenLookupResult citizen)
      fetchExisting;
  /// `null` makes the record type view-only -- the section shows the
  /// citizen's existing rows but no "Add" action.
  final Future<void> Function(DepartmentRepository repo, CitizenLookupResult citizen, Map<String, dynamic> formValues)?
      buildInsertData;
  final String Function(Map<String, dynamic> row) rowTitle;
  final String Function(Map<String, dynamic> row) rowSubtitle;

  /// Checked against the submitted form values before insert/update ever
  /// reaches the repository -- returns a specific, human-readable reason
  /// the record can't be created (e.g. "This citizen is 12 years old -- a
  /// driver's licence cannot be issued before age 17.") or `null` if it's
  /// fine. The database enforces the same floors independently as a hard
  /// backstop; this is what lets an official see why *before* submitting
  /// rather than getting a raw Postgres error back.
  final String? Function(CitizenLookupResult citizen, Map<String, dynamic> formValues)? validate;

  /// Primary-key column present in the rows [fetchExisting] returns.
  final String? idColumn;

  /// The underlying Postgres table [fetchExisting] reads. Used by "Lodge
  /// appeal" (department_citizen_records_screen.dart) to record which
  /// table+row an appeal is against (`appeals.related_table`/`related_id`)
  /// -- both [table] and [idColumn] must be set for a row to be appealable;
  /// a config missing either just doesn't get an Appeal action.
  final String? table;

  /// Takes [citizen] too (not just the existing row) because updating a
  /// record's status also needs to update that citizen's mirrored
  /// `credentials` row -- see `DepartmentRepository`'s
  /// `_updateCredentialMirror`.
  final Future<void> Function(
    DepartmentRepository repo,
    CitizenLookupResult citizen,
    Map<String, dynamic> existingRow,
    Map<String, dynamic> formValues,
  )? buildUpdateData;
  final Future<void> Function(DepartmentRepository repo, CitizenLookupResult citizen, Map<String, dynamic> existingRow)?
      buildDelete;
}

const _dateOnly = RecordFieldType.date;

/// The 6 public universities + 3 TVET colleges seeded into
/// `dhet_institutions` (docs/database/dhet_institutions_and_academic_records.sql)
/// -- hardcoded here the same way `marriage_type`/`offence_code` dropdown
/// options are, rather than fetched, since it's small and static.
const _institutionCodes = [
  'UCT',
  'UKZN',
  'UP',
  'WITS',
  'NMU',
  'SU',
  'CPUT TVET',
  'False Bay TVET',
  'Tshwane North TVET',
];

const _provinces = [
  'Eastern Cape',
  'Free State',
  'Gauteng',
  'KwaZulu-Natal',
  'Limpopo',
  'Mpumalanga',
  'Northern Cape',
  'North West',
  'Western Cape',
];

/// Shared by every record type that's just "one citizen, one event date,
/// one minimum age" (driver's licence, tax registration, employment).
/// Marriage (two people) and SASSA Old Age (current age, not an event
/// date) have their own inline logic instead.
String? _minAgeValidator({
  required CitizenLookupResult citizen,
  required Map<String, dynamic> values,
  required String dateKey,
  required int minAge,
  required String label,
}) {
  final dob = citizen.dateOfBirth ?? saIdDateOfBirth(citizen.idNumber);
  if (dob == null) return null;
  final eventDate = DateTime.tryParse(values[dateKey] as String? ?? '') ?? DateTime.now();
  final age = ageAt(dob, eventDate);
  if (age < minAge) {
    return '${citizen.fullName} would be $age years old on ${eventDate.toIso8601String().split('T').first} – '
        '$label requires a minimum age of $minAge.';
  }
  return null;
}

List<RecordTypeConfig> recordTypesForDepartment(String departmentCode) {
  switch (departmentCode) {
    case 'HOME_AFFAIRS':
      return [
        RecordTypeConfig(
          label: 'Marriage',
          icon: 'favorite_outline',
          idColumn: 'marriage_id',
          table: 'dha_marital_records',
          fields: const [
            RecordField(key: 'spouse_2_id', label: "Spouse's SA ID number", type: RecordFieldType.text),
            RecordField(
              key: 'marriage_type',
              label: 'Marriage type',
              type: RecordFieldType.dropdown,
              options: ['Civil', 'Customary'],
            ),
            RecordField(key: 'date_of_marriage', label: 'Date of marriage', type: _dateOnly),
          ],
          validate: (citizen, values) {
            final marriageDate = DateTime.tryParse(values['date_of_marriage'] as String? ?? '');
            if (marriageDate == null) return null;
            final spouse1Dob = saIdDateOfBirth(citizen.idNumber);
            if (spouse1Dob != null && ageAt(spouse1Dob, marriageDate) < 18) {
              return '${citizen.fullName} would be ${ageAt(spouse1Dob, marriageDate)} years old on this date – '
                  'the minimum marriage age is 18.';
            }
            final spouse2Dob = saIdDateOfBirth(values['spouse_2_id'] as String? ?? '');
            if (spouse2Dob != null && ageAt(spouse2Dob, marriageDate) < 18) {
              return 'The spouse would be ${ageAt(spouse2Dob, marriageDate)} years old on this date – '
                  'the minimum marriage age is 18.';
            }
            return null;
          },
          fetchExisting: (repo, citizen) =>
              repo.getRecordsByColumn(table: 'dha_marital_records', column: 'spouse_1_id', value: citizen.idNumber),
          // Via the register_marriage RPC, which rejects the request
          // server-side if either citizen is already married -- not a
          // plain insertRecord (docs/database/register_marriage.sql).
          buildInsertData: (repo, citizen, values) => repo.registerMarriage(
            spouse1Id: citizen.idNumber,
            spouse2Id: values['spouse_2_id'] as String,
            marriageType: values['marriage_type'] as String,
            dateOfMarriage: DateTime.parse(values['date_of_marriage'] as String),
          ),
          rowTitle: (r) => 'Married to ${r['spouse_2_id']}',
          rowSubtitle: (r) => '${r['marriage_type']} • ${r['date_of_marriage']}',
        ),
        RecordTypeConfig(
          label: 'Death',
          icon: 'event_busy_outlined',
          idColumn: 'death_id',
          table: 'dha_death_records',
          fields: const [
            RecordField(key: 'date_of_death', label: 'Date of death', type: _dateOnly),
            RecordField(key: 'place_of_death', label: 'Place of death', type: RecordFieldType.text),
            RecordField(key: 'cause_code', label: 'Cause code', type: RecordFieldType.text),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dha_death_records', column: 'national_id_number', value: citizen.idNumber),
          // Declaring a death also raises a flagged record for an
          // administrator to review and deactivate this citizen's account
          // (see declareCitizenDeceased) -- not a plain insertRecord.
          buildInsertData: (repo, citizen, values) => repo.declareCitizenDeceased(
            citizenId: citizen.citizenId,
            dateOfDeath: DateTime.parse(values['date_of_death'] as String),
            placeOfDeath: values['place_of_death'] as String,
            causeCode: values['cause_code'] as String,
          ),
          rowTitle: (r) => 'Deceased ${r['date_of_death']}',
          rowSubtitle: (r) => '${r['place_of_death'] ?? ''}',
        ),
        RecordTypeConfig(
          label: 'Passport',
          icon: 'menu_book_outlined',
          idColumn: 'passport_number',
          table: 'dha_passports',
          fields: const [
            RecordField(key: 'issue_date', label: 'Issue date', type: _dateOnly),
            RecordField(key: 'expiry_date', label: 'Expiry date', type: _dateOnly),
            RecordField(
              key: 'status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['Active', 'Expired', 'Revoked'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dha_passports', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.issuePassport(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            issueDate: DateTime.parse(values['issue_date'] as String),
            expiryDate: DateTime.parse(values['expiry_date'] as String),
            status: values['status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updatePassport(
            citizenId: citizen.citizenId,
            passportNumber: existingRow['passport_number'] as String,
            issueDate: DateTime.parse(values['issue_date'] as String),
            expiryDate: DateTime.parse(values['expiry_date'] as String),
            status: values['status'] as String,
          ),
          rowTitle: (r) => r['passport_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['status']} • expires ${r['expiry_date']}',
        ),
        RecordTypeConfig(
          label: 'Immigration',
          icon: 'flight_land_outlined',
          idColumn: 'immigration_id',
          table: 'dha_immigration_records',
          fields: const [
            RecordField(
              key: 'visa_type',
              label: 'Visa/permit type',
              type: RecordFieldType.dropdown,
              options: ['Work Visa', 'Study Visa', 'Visitor Visa', 'Permanent Residence', 'Refugee Status'],
            ),
            RecordField(
              key: 'status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['Active', 'Pending', 'Expired', 'Revoked'],
            ),
            RecordField(key: 'issue_date', label: 'Issue date', type: _dateOnly),
            RecordField(key: 'expiry_date', label: 'Expiry date', type: _dateOnly),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dha_immigration_records', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.insertRecord(table: 'dha_immigration_records', data: {
            'national_id_number': citizen.idNumber,
            'visa_type': values['visa_type'],
            'status': values['status'],
            'issue_date': values['issue_date'],
            'expiry_date': values['expiry_date'],
          }),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateRecord(
            table: 'dha_immigration_records',
            idColumn: 'immigration_id',
            idValue: existingRow['immigration_id'],
            data: {
              'visa_type': values['visa_type'],
              'status': values['status'],
              'issue_date': values['issue_date'],
              'expiry_date': values['expiry_date'],
            },
          ),
          rowTitle: (r) => r['visa_type'] as String? ?? '',
          rowSubtitle: (r) => '${r['status']} • expires ${r['expiry_date'] ?? 'n/a'}',
        ),
      ];

    case 'TRANSPORT':
      return [
        RecordTypeConfig(
          label: "Driver's Licence",
          icon: 'badge_outlined',
          idColumn: 'licence_number',
          table: 'dot_driver_licences',
          fields: const [
            RecordField(
              key: 'licence_code',
              label: 'Licence code',
              type: RecordFieldType.dropdown,
              options: ['Code B', 'Code EB', 'Code EC1', 'Code C1'],
            ),
            RecordField(key: 'issue_date', label: 'Issue date', type: _dateOnly),
            RecordField(key: 'expiry_date', label: 'Expiry date', type: _dateOnly),
            RecordField(
              key: 'status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['Valid', 'Suspended', 'Expired', 'Revoked'],
            ),
          ],
          validate: (citizen, values) =>
              _minAgeValidator(citizen: citizen, values: values, dateKey: 'issue_date', minAge: 17, label: "a driver's licence"),
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dot_driver_licences', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.issueDriversLicence(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            licenceCode: values['licence_code'] as String,
            issueDate: DateTime.parse(values['issue_date'] as String),
            expiryDate: DateTime.parse(values['expiry_date'] as String),
            status: values['status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateDriversLicence(
            citizenId: citizen.citizenId,
            licenceNumber: existingRow['licence_number'] as String,
            licenceCode: values['licence_code'] as String,
            issueDate: DateTime.parse(values['issue_date'] as String),
            expiryDate: DateTime.parse(values['expiry_date'] as String),
            status: values['status'] as String,
          ),
          rowTitle: (r) => r['licence_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['licence_code']} • ${r['status']}',
        ),
        RecordTypeConfig(
          label: 'Vehicle / Number Plate',
          icon: 'directions_car_outlined',
          idColumn: 'vin_number',
          table: 'dot_vehicles',
          fields: const [
            RecordField(key: 'make', label: 'Make', type: RecordFieldType.text),
            RecordField(key: 'model', label: 'Model', type: RecordFieldType.text),
            RecordField(key: 'year', label: 'Year', type: RecordFieldType.number),
            RecordField(key: 'disc_expiry_date', label: 'Licence disc expiry', type: _dateOnly),
          ],
          fetchExisting: (repo, citizen) =>
              repo.getRecordsByColumn(table: 'dot_vehicles', column: 'owner_id', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.registerVehicle(
            nationalIdNumber: citizen.idNumber,
            make: values['make'] as String,
            model: values['model'] as String,
            year: int.tryParse(values['year']?.toString() ?? '') ?? 0,
            discExpiryDate: DateTime.parse(values['disc_expiry_date'] as String),
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateRecord(
            table: 'dot_vehicles',
            idColumn: 'vin_number',
            idValue: existingRow['vin_number'],
            data: {
              'make': values['make'],
              'model': values['model'],
              'year': int.tryParse(values['year']?.toString() ?? '') ?? 0,
              'disc_expiry_date': values['disc_expiry_date'],
            },
          ),
          rowTitle: (r) => r['registration_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['make']} ${r['model']} (${r['year']})',
        ),
      ];

    case 'SARS':
      return [
        RecordTypeConfig(
          label: 'Taxpayer Registration',
          icon: 'account_balance_outlined',
          idColumn: 'tax_number',
          table: 'sars_taxpayers',
          fields: const [
            RecordField(
              key: 'tax_compliance_status',
              label: 'Compliance status',
              type: RecordFieldType.dropdown,
              options: ['Compliant', 'Non-Compliant'],
            ),
            RecordField(key: 'registered_date', label: 'Registered date', type: _dateOnly),
          ],
          validate: (citizen, values) =>
              _minAgeValidator(citizen: citizen, values: values, dateKey: 'registered_date', minAge: 18, label: 'a tax registration'),
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'sars_taxpayers', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.registerTaxpayer(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            complianceStatus: values['tax_compliance_status'] as String,
            registeredDate: DateTime.parse(values['registered_date'] as String),
          ),
          // "Grant compliance or non-compliance documents" -- flips the
          // compliance status the org verification flow reads.
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateTaxpayerCompliance(
            citizenId: citizen.citizenId,
            taxNumber: existingRow['tax_number'] as String,
            complianceStatus: values['tax_compliance_status'] as String,
            registeredDate: DateTime.tryParse(values['registered_date'] as String? ?? ''),
          ),
          rowTitle: (r) => r['tax_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['tax_compliance_status']}',
        ),
        RecordTypeConfig(
          label: 'Tax Return',
          icon: 'receipt_long_outlined',
          idColumn: 'return_id',
          table: 'sars_tax_returns',
          fields: const [
            RecordField(key: 'tax_number', label: "Taxpayer's tax number", type: RecordFieldType.text),
            RecordField(key: 'tax_year', label: 'Tax year', type: RecordFieldType.number),
            RecordField(key: 'declared_income', label: 'Declared income (R)', type: RecordFieldType.number),
            RecordField(key: 'refund_or_due_amount', label: 'Refund/due amount (R)', type: RecordFieldType.number),
            RecordField(
              key: 'filing_status',
              label: 'Filing status',
              type: RecordFieldType.dropdown,
              options: ['Submitted', 'Assessed', 'Paid'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getSarsTaxReturnsForCitizen(citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.insertRecord(table: 'sars_tax_returns', data: {
            'tax_number': values['tax_number'],
            'tax_year': int.tryParse(values['tax_year']?.toString() ?? '') ?? DateTime.now().year,
            'declared_income': num.tryParse(values['declared_income']?.toString() ?? '') ?? 0,
            'refund_or_due_amount': num.tryParse(values['refund_or_due_amount']?.toString() ?? '') ?? 0,
            'filing_status': values['filing_status'],
          }),
          // "Payments, refunds" -- recording a payment/refund is moving
          // filing_status/refund_or_due_amount on the same return, not a
          // separate ledger table (see docs/DATA_MODEL.md).
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateRecord(
            table: 'sars_tax_returns',
            idColumn: 'return_id',
            idValue: existingRow['return_id'],
            data: {
              'tax_number': values['tax_number'],
              'tax_year': int.tryParse(values['tax_year']?.toString() ?? '') ?? DateTime.now().year,
              'declared_income': num.tryParse(values['declared_income']?.toString() ?? '') ?? 0,
              'refund_or_due_amount': num.tryParse(values['refund_or_due_amount']?.toString() ?? '') ?? 0,
              'filing_status': values['filing_status'],
            },
          ),
          rowTitle: (r) => 'Tax year ${r['tax_year']}',
          rowSubtitle: (r) => '${r['filing_status']} • R${r['declared_income']}',
        ),
      ];

    case 'SAPS':
      return [
        RecordTypeConfig(
          label: 'Criminal Record',
          icon: 'gavel_outlined',
          idColumn: 'case_number',
          table: 'saps_criminal_records',
          fields: const [
            RecordField(
              key: 'offence_code',
              label: 'Offence',
              type: RecordFieldType.dropdown,
              options: ['THEFT', 'ASSAULT', 'FRAUD', 'TRAFFIC'],
            ),
            RecordField(key: 'conviction_date', label: 'Conviction date', type: _dateOnly),
            RecordField(
              key: 'sentence_status',
              label: 'Sentence status',
              type: RecordFieldType.dropdown,
              options: ['Served', 'Ongoing', 'Expunged'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'saps_criminal_records', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.recordCriminalCase(
            nationalIdNumber: citizen.idNumber,
            offenceCode: values['offence_code'] as String,
            convictionDate: DateTime.parse(values['conviction_date'] as String),
            sentenceStatus: values['sentence_status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateRecord(
            table: 'saps_criminal_records',
            idColumn: 'case_number',
            idValue: existingRow['case_number'],
            data: {
              'offence_code': values['offence_code'],
              'conviction_date': values['conviction_date'],
              'sentence_status': values['sentence_status'],
            },
          ),
          rowTitle: (r) => r['case_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['offence_code']} • ${r['sentence_status']}',
        ),
        RecordTypeConfig(
          label: 'Clearance Certificate',
          icon: 'verified_outlined',
          idColumn: 'certificate_number',
          table: 'saps_clearance_certificates',
          fields: const [
            RecordField(key: 'issue_date', label: 'Issue date', type: _dateOnly),
            RecordField(
              key: 'status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['Clear', 'Record Found'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'saps_clearance_certificates', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.issueClearanceCertificate(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            issueDate: DateTime.parse(values['issue_date'] as String),
            status: values['status'] as String,
          ),
          rowTitle: (r) => r['status'] as String? ?? '',
          rowSubtitle: (r) => 'Issued ${r['issue_date']}',
        ),
      ];

    case 'DBE':
      return [
        RecordTypeConfig(
          label: 'Matric Certificate',
          icon: 'school_outlined',
          idColumn: 'matric_exam_number',
          table: 'dbe_nsc_results',
          fields: const [
            RecordField(key: 'year', label: 'Year', type: RecordFieldType.number),
            RecordField(
              key: 'overall_pass_status',
              label: 'Pass status',
              type: RecordFieldType.dropdown,
              options: ['Bachelor Pass', 'Diploma', 'Higher Certificate'],
            ),
          ],
          // Real floor, no ceiling: the standard route sits Grade 12 around
          // 17-19, but DBE's private/adult-candidate route lets someone sit
          // and pass matric well into adulthood -- there is no upper age
          // limit for writing the NSC, only a minimum of 17.
          validate: (citizen, values) {
            final dob = citizen.dateOfBirth ?? saIdDateOfBirth(citizen.idNumber);
            final year = int.tryParse(values['year']?.toString() ?? '');
            if (dob == null || year == null) return null;
            final age = year - dob.year;
            if (age < 17) {
              return '${citizen.fullName} would be $age years old in $year – the minimum age to write the NSC (including as a private/adult candidate) is 17.';
            }
            return null;
          },
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dbe_nsc_results', column: 'national_id_number', value: citizen.idNumber),
          // "Grant matric certificate upon completion" -- the NSC result
          // row *is* the matric certificate (docs/DATA_MODEL.md).
          buildInsertData: (repo, citizen, values) => repo.issueMatricCertificate(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            year: int.tryParse(values['year']?.toString() ?? '') ?? DateTime.now().year,
            overallPassStatus: values['overall_pass_status'] as String,
          ),
          rowTitle: (r) => 'NSC ${r['year']}',
          rowSubtitle: (r) => '${r['overall_pass_status']}',
        ),
      ];

    case 'DHET':
      return [
        RecordTypeConfig(
          label: 'Student Enrolment',
          icon: 'menu_book_outlined',
          idColumn: 'enrollment_id',
          table: 'dhet_student_enrollment',
          fields: const [
            RecordField(
              key: 'institution_code',
              label: 'Institution (6 universities + TVET colleges)',
              type: RecordFieldType.dropdown,
              options: _institutionCodes,
            ),
            RecordField(key: 'qualification_name', label: 'Qualification', type: RecordFieldType.text),
            RecordField(
              key: 'completion_status',
              label: 'Completion status',
              type: RecordFieldType.dropdown,
              options: ['Enrolled', 'Graduated', 'Dropped'],
            ),
            RecordField(
              key: 'study_mode',
              label: 'Study mode',
              type: RecordFieldType.dropdown,
              options: ['Full-time', 'Part-time'],
            ),
            RecordField(
              key: 'mature_age_exemption',
              label: 'No matric on file – mature age exemption',
              type: RecordFieldType.dropdown,
              options: ['No', 'Yes'],
            ),
            RecordField(
              key: 'mature_age_exemption_reason',
              label: 'Exemption reason (required if "Yes" above)',
              type: RecordFieldType.text,
              optional: true,
            ),
          ],
          // A university/TVET college requires a matric (NSC) pass for
          // admission -- enforced server-side by the `enrol_student` RPC
          // (docs/database/cross_department_eligibility_checks.sql), which
          // rejects the insert unless the citizen already has a
          // `dbe_nsc_results` row or this exemption is set with a reason.
          // This client-side check just surfaces the same rule earlier,
          // same as every other `validate` here.
          validate: (citizen, values) {
            if (values['mature_age_exemption'] == 'Yes' &&
                (values['mature_age_exemption_reason'] as String? ?? '').trim().isEmpty) {
              return 'A reason is required when registering a mature age exemption.';
            }
            return null;
          },
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_student_enrollment', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.enrolStudent(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            institutionCode: values['institution_code'] as String,
            qualificationName: values['qualification_name'] as String,
            completionStatus: values['completion_status'] as String,
            studyMode: values['study_mode'] as String,
            matureAgeExemption: values['mature_age_exemption'] == 'Yes',
            matureAgeExemptionReason: values['mature_age_exemption_reason'] as String?,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateStudentEnrolment(
            citizenId: citizen.citizenId,
            enrollmentId: existingRow['enrollment_id'] as String,
            completionStatus: values['completion_status'] as String,
            institutionCode: values['institution_code'] as String?,
            qualificationName: values['qualification_name'] as String?,
            studyMode: values['study_mode'] as String?,
          ),
          rowTitle: (r) => r['qualification_name'] as String? ?? '',
          rowSubtitle: (r) =>
              '${r['institution_code']} • ${r['completion_status']} • ${r['study_mode'] ?? 'Full-time'}',
        ),
        RecordTypeConfig(
          label: 'Academic Record',
          icon: 'workspace_premium_outlined',
          idColumn: 'record_id',
          table: 'dhet_academic_records',
          fields: const [
            RecordField(
              key: 'institution_code',
              label: 'Institution',
              type: RecordFieldType.dropdown,
              options: _institutionCodes,
            ),
            RecordField(key: 'qualification_name', label: 'Qualification', type: RecordFieldType.text),
            RecordField(key: 'year', label: 'Year', type: RecordFieldType.number),
            RecordField(
              key: 'final_result',
              label: 'Final result',
              type: RecordFieldType.dropdown,
              options: ['Distinction', 'Merit', 'Pass', 'Fail'],
            ),
          ],
          validate: (citizen, values) {
            final dob = citizen.dateOfBirth ?? saIdDateOfBirth(citizen.idNumber);
            final year = int.tryParse(values['year']?.toString() ?? '');
            if (dob == null || year == null) return null;
            final age = year - dob.year;
            if (age < 17) {
              return '${citizen.fullName} would be $age years old in $year – too young to have completed this qualification.';
            }
            return null;
          },
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_academic_records', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.recordAcademicResult(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            institutionCode: values['institution_code'] as String,
            qualificationName: values['qualification_name'] as String,
            year: int.tryParse(values['year']?.toString() ?? '') ?? DateTime.now().year,
            finalResult: values['final_result'] as String,
          ),
          rowTitle: (r) => r['qualification_name'] as String? ?? '',
          rowSubtitle: (r) => '${r['institution_code']} • ${r['year']} • ${r['final_result']}',
        ),
        RecordTypeConfig(
          label: 'NSFAS Funding',
          icon: 'payments_outlined',
          idColumn: 'application_id',
          table: 'dhet_nsfas_funding',
          fields: const [
            RecordField(key: 'funding_year', label: 'Funding year', type: RecordFieldType.number),
            RecordField(
              key: 'approved_status',
              label: 'Approved',
              type: RecordFieldType.dropdown,
              options: ['Yes', 'No'],
            ),
            RecordField(key: 'disbursed_amount', label: 'Disbursed amount (R)', type: RecordFieldType.number),
          ],
          // Approving funding ('Yes') is rejected server-side by the
          // `issue_nsfas_funding` RPC unless this citizen is actively
          // enrolled and has no active employment record -- NSFAS funds
          // students without a full-time income, not employed people
          // (docs/database/cross_department_eligibility_checks.sql).
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_nsfas_funding', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.issueNsfasFunding(
            nationalIdNumber: citizen.idNumber,
            fundingYear: int.tryParse(values['funding_year']?.toString() ?? '') ?? DateTime.now().year,
            approvedStatus: values['approved_status'] == 'Yes',
            disbursedAmount: num.tryParse(values['disbursed_amount']?.toString() ?? '') ?? 0,
          ),
          rowTitle: (r) => 'NSFAS ${r['funding_year']}',
          rowSubtitle: (r) =>
              '${r['approved_status'] == true ? 'Approved' : 'Not approved'} • R${r['disbursed_amount']}',
        ),
      ];

    case 'SASSA':
      return [
        RecordTypeConfig(
          label: 'SASSA Grant',
          icon: 'volunteer_activism_outlined',
          idColumn: 'grant_id',
          table: 'sassa_grants',
          fields: const [
            RecordField(
              key: 'grant_type',
              label: 'Grant type',
              type: RecordFieldType.dropdown,
              options: ['SRD R370', 'Child Support', 'Disability', 'Old Age'],
            ),
            RecordField(
              key: 'status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['Active', 'Pending', 'Suspended'],
            ),
            RecordField(
              key: 'payout_method',
              label: 'Payout method',
              type: RecordFieldType.dropdown,
              options: ['Bank Transfer', 'Retail Post Office'],
            ),
          ],
          // Only "Old Age" carries an age floor -- SRD R370/Child Support/
          // Disability have no such restriction, and Old Age is judged
          // against the citizen's *current* age (an ongoing entitlement),
          // not a submitted event date.
          validate: (citizen, values) {
            if (values['grant_type'] != 'Old Age') return null;
            final dob = citizen.dateOfBirth ?? saIdDateOfBirth(citizen.idNumber);
            if (dob == null) return null;
            final age = ageAt(dob, DateTime.now());
            if (age < 60) {
              return '${citizen.fullName} is $age years old – the Old Age grant requires a minimum age of 60.';
            }
            return null;
          },
          fetchExisting: (repo, citizen) =>
              repo.getRecordsByColumn(table: 'sassa_grants', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.issueSassaGrant(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            grantType: values['grant_type'] as String,
            status: values['status'] as String,
            payoutMethod: values['payout_method'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateSassaGrant(
            citizenId: citizen.citizenId,
            grantId: existingRow['grant_id'] as String,
            grantType: values['grant_type'] as String,
            status: values['status'] as String,
            payoutMethod: values['payout_method'] as String,
          ),
          buildDelete: (repo, citizen, existingRow) => repo.removeSassaGrant(
            citizenId: citizen.citizenId,
            grantId: existingRow['grant_id'] as String,
          ),
          rowTitle: (r) => r['grant_type'] as String? ?? '',
          rowSubtitle: (r) => '${r['status']} • ${r['payout_method']}',
        ),
      ];

    case 'LABOUR':
      return [
        RecordTypeConfig(
          label: 'Employment / UIF',
          icon: 'work_outline',
          idColumn: 'record_id',
          table: 'labour_employment_records',
          fields: const [
            RecordField(key: 'employer_name', label: 'Employer (organisation)', type: RecordFieldType.text),
            RecordField(
              key: 'employment_status',
              label: 'Employment status',
              type: RecordFieldType.dropdown,
              options: ['Employed', 'Unemployed', 'Self-Employed'],
            ),
            RecordField(key: 'start_date', label: 'Start date', type: _dateOnly),
            RecordField(key: 'uif_contribution_amount', label: 'UIF contribution (R/month)', type: RecordFieldType.number),
            RecordField(
              key: 'uif_claim_status',
              label: 'UIF claim status',
              type: RecordFieldType.dropdown,
              options: ['Not Claiming', 'Claiming', 'Claim Approved', 'Claim Rejected'],
            ),
          ],
          validate: (citizen, values) =>
              _minAgeValidator(citizen: citizen, values: values, dateKey: 'start_date', minAge: 15, label: 'an employment record'),
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'labour_employment_records', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.recordEmployment(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            employerName: values['employer_name'] as String?,
            employmentStatus: values['employment_status'] as String,
            startDate: DateTime.tryParse(values['start_date'] as String? ?? ''),
            uifContributionAmount: num.tryParse(values['uif_contribution_amount']?.toString() ?? '') ?? 0,
            uifClaimStatus: values['uif_claim_status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateEmployment(
            citizenId: citizen.citizenId,
            recordId: existingRow['record_id'] as String,
            employerName: values['employer_name'] as String?,
            employmentStatus: values['employment_status'] as String,
            uifContributionAmount: num.tryParse(values['uif_contribution_amount']?.toString() ?? '') ?? 0,
            uifClaimStatus: values['uif_claim_status'] as String,
            startDate: DateTime.tryParse(values['start_date'] as String? ?? ''),
          ),
          rowTitle: (r) => r['employer_name'] as String? ?? (r['employment_status'] as String? ?? ''),
          rowSubtitle: (r) => '${r['employment_status']} • UIF: ${r['uif_claim_status'] ?? 'Not Claiming'}',
        ),
      ];

    case 'DHS':
      return [
        RecordTypeConfig(
          label: 'Property',
          icon: 'home_work_outlined',
          idColumn: 'property_id',
          table: 'properties',
          fields: const [
            RecordField(key: 'municipality', label: 'Municipality', type: RecordFieldType.text),
            RecordField(
              key: 'province',
              label: 'Province',
              type: RecordFieldType.dropdown,
              options: _provinces,
            ),
            RecordField(key: 'suburb', label: 'Suburb (optional)', type: RecordFieldType.text),
            RecordField(
              key: 'property_type',
              label: 'Property type',
              type: RecordFieldType.dropdown,
              options: ['house', 'flat', 'townhouse', 'sectional_title', 'serviced_stand', 'other'],
            ),
            RecordField(
              key: 'housing_status',
              label: 'Housing status',
              type: RecordFieldType.dropdown,
              options: ['planned', 'under_construction', 'completed', 'allocated', 'occupied', 'vacant', 'transferred'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getPropertyForCitizen(citizen.citizenId),
          // A citizen has at most one active property via
          // `housing_beneficiaries` (docs/DATA_MODEL.md) -- registering
          // links this citizen as the owning beneficiary in the same call.
          buildInsertData: (repo, citizen, values) => repo.registerProperty(
            citizenId: citizen.citizenId,
            municipality: values['municipality'] as String,
            province: values['province'] as String,
            suburb: (values['suburb'] as String?)?.isEmpty ?? true ? null : values['suburb'] as String,
            propertyType: values['property_type'] as String,
            housingStatus: values['housing_status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updatePropertyStatus(
            propertyId: existingRow['property_id'] as String,
            housingStatus: values['housing_status'] as String,
            municipality: values['municipality'] as String?,
            province: values['province'] as String?,
            suburb: (values['suburb'] as String?)?.isEmpty ?? true ? null : values['suburb'] as String,
            propertyType: values['property_type'] as String?,
          ),
          rowTitle: (r) => r['property_reference'] as String? ?? '',
          rowSubtitle: (r) => '${r['municipality'] ?? ''}, ${r['province'] ?? ''} • ${r['housing_status']}',
        ),
        RecordTypeConfig(
          label: 'Title Deed',
          icon: 'description_outlined',
          idColumn: 'title_deed_id',
          table: 'title_deeds',
          fields: const [
            RecordField(
              key: 'deed_type',
              label: 'Deed type',
              type: RecordFieldType.dropdown,
              options: ['title_deed', 'sectional_title', 'deed_of_grant', 'other'],
            ),
            RecordField(key: 'registered_owner_name', label: 'Registered owner name', type: RecordFieldType.text),
            RecordField(key: 'registration_date', label: 'Registration date', type: _dateOnly),
          ],
          fetchExisting: (repo, citizen) => repo.getTitleDeedsForCitizen(citizen.citizenId),
          // Requires a property to already be registered for this citizen
          // -- issueTitleDeedForCitizen looks it up and raises a clear
          // error if there isn't one yet, rather than asking for a
          // property picker here too.
          buildInsertData: (repo, citizen, values) => repo.issueTitleDeedForCitizen(
            citizenId: citizen.citizenId,
            deedType: values['deed_type'] as String,
            registeredOwnerName: values['registered_owner_name'] as String,
            registrationDate: DateTime.parse(values['registration_date'] as String),
          ),
          rowTitle: (r) => r['title_deed_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['deed_type']} • ${r['registration_status']}',
        ),
        RecordTypeConfig(
          label: 'Housing Application',
          icon: 'assignment_outlined',
          idColumn: 'housing_application_id',
          table: 'housing_applications',
          fields: const [
            RecordField(
              key: 'programme_code',
              label: 'Programme',
              type: RecordFieldType.dropdown,
              options: ['RDP', 'FLISP', 'CRU'],
            ),
            RecordField(key: 'municipality', label: 'Municipality', type: RecordFieldType.text),
            RecordField(
              key: 'province',
              label: 'Province',
              type: RecordFieldType.dropdown,
              options: _provinces,
            ),
            RecordField(key: 'household_size', label: 'Household size', type: RecordFieldType.number),
            RecordField(key: 'household_income', label: 'Household income (R/month)', type: RecordFieldType.number),
            // Only meaningful on edit -- a new application always starts
            // 'submitted' (see submitHousingApplication); the field is
            // still listed here so the edit dialog can show/change it.
            RecordField(
              key: 'application_status',
              label: 'Status',
              type: RecordFieldType.dropdown,
              options: ['submitted', 'under_review', 'approved', 'rejected', 'allocated', 'completed', 'cancelled'],
            ),
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'housing_applications', column: 'citizen_id', value: citizen.citizenId),
          buildInsertData: (repo, citizen, values) => repo.submitHousingApplication(
            citizenId: citizen.citizenId,
            programmeCode: values['programme_code'] as String,
            municipality: values['municipality'] as String,
            province: values['province'] as String,
            householdSize: int.tryParse(values['household_size']?.toString() ?? ''),
            householdIncome: num.tryParse(values['household_income']?.toString() ?? ''),
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateHousingApplicationStatus(
            housingApplicationId: existingRow['housing_application_id'] as String,
            applicationStatus: values['application_status'] as String,
            programmeCode: values['programme_code'] as String?,
            municipality: values['municipality'] as String?,
            province: values['province'] as String?,
            householdSize: int.tryParse(values['household_size']?.toString() ?? ''),
            householdIncome: num.tryParse(values['household_income']?.toString() ?? ''),
          ),
          rowTitle: (r) => r['application_reference'] as String? ?? '',
          rowSubtitle: (r) => '${r['application_status']} • ${r['municipality'] ?? ''}',
        ),
        // Generic household/occupancy data from `human_settlements_records`
        // -- view-only (no `buildInsertData`): its record_type values aren't
        // documented anywhere, so there's no form to create one from.
        RecordTypeConfig(
          label: 'Household Record',
          icon: 'home_outlined',
          fields: const [],
          fetchExisting: (repo, citizen) => repo.getHouseholdRecordsForCitizen(citizen.citizenId),
          rowTitle: (r) => '${r['record_type'] ?? 'RECORD'} • ${r['properties']?['property_reference'] ?? 'Unknown property'}',
          rowSubtitle: (r) {
            final data = (r['record_data'] as Map<String, dynamic>?) ?? const {};
            final details = data.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
            final recordedAt = (r['recorded_at'] as String?)?.split('T').first ?? '';
            return [details, recordedAt].where((s) => s.isNotEmpty).join('\n');
          },
        ),
      ];

    default:
      return const [];
  }
}
