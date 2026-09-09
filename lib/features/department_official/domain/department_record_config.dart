import '../../shared/domain/citizen_lookup_result.dart';
import '../data/department_repository.dart';

enum RecordFieldType { text, number, date, dropdown, boolean }

class RecordField {
  const RecordField({
    required this.key,
    required this.label,
    required this.type,
    this.options,
  });

  final String key;
  final String label;
  final RecordFieldType type;
  final List<String>? options;
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
    required this.buildInsertData,
    required this.rowTitle,
    required this.rowSubtitle,
    this.idColumn,
    this.buildUpdateData,
    this.buildDelete,
  });

  final String label;
  final String icon; // material icon name, resolved in the widget
  final List<RecordField> fields;
  final Future<List<Map<String, dynamic>>> Function(DepartmentRepository repo, CitizenLookupResult citizen)
      fetchExisting;
  final Future<void> Function(DepartmentRepository repo, CitizenLookupResult citizen, Map<String, dynamic> formValues)
      buildInsertData;
  final String Function(Map<String, dynamic> row) rowTitle;
  final String Function(Map<String, dynamic> row) rowSubtitle;

  /// Primary-key column present in the rows [fetchExisting] returns --
  /// required for edit/delete to be able to target one row.
  final String? idColumn;

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

List<RecordTypeConfig> recordTypesForDepartment(String departmentCode) {
  switch (departmentCode) {
    case 'HOME_AFFAIRS':
      return [
        RecordTypeConfig(
          label: 'Marriage',
          icon: 'favorite_outline',
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
          fields: const [
            RecordField(
              key: 'tax_compliance_status',
              label: 'Compliance status',
              type: RecordFieldType.dropdown,
              options: ['Compliant', 'Non-Compliant'],
            ),
            RecordField(key: 'registered_date', label: 'Registered date', type: _dateOnly),
          ],
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
          ),
          rowTitle: (r) => r['tax_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['tax_compliance_status']}',
        ),
        RecordTypeConfig(
          label: 'Tax Return',
          icon: 'receipt_long_outlined',
          idColumn: 'return_id',
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
            data: {'sentence_status': values['sentence_status']},
          ),
          rowTitle: (r) => r['case_number'] as String? ?? '',
          rowSubtitle: (r) => '${r['offence_code']} • ${r['sentence_status']}',
        ),
        RecordTypeConfig(
          label: 'Clearance Certificate',
          icon: 'verified_outlined',
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
          fields: const [
            RecordField(key: 'year', label: 'Year', type: RecordFieldType.number),
            RecordField(
              key: 'overall_pass_status',
              label: 'Pass status',
              type: RecordFieldType.dropdown,
              options: ['Bachelor Pass', 'Diploma', 'Higher Certificate'],
            ),
          ],
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
          ],
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_student_enrollment', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.enrolStudent(
            citizenId: citizen.citizenId,
            nationalIdNumber: citizen.idNumber,
            institutionCode: values['institution_code'] as String,
            qualificationName: values['qualification_name'] as String,
            completionStatus: values['completion_status'] as String,
          ),
          buildUpdateData: (repo, citizen, existingRow, values) => repo.updateStudentEnrolment(
            citizenId: citizen.citizenId,
            enrollmentId: existingRow['enrollment_id'] as String,
            completionStatus: values['completion_status'] as String,
          ),
          rowTitle: (r) => r['qualification_name'] as String? ?? '',
          rowSubtitle: (r) => '${r['institution_code']} • ${r['completion_status']}',
        ),
        RecordTypeConfig(
          label: 'Academic Record',
          icon: 'workspace_premium_outlined',
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
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_academic_records', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.insertRecord(table: 'dhet_academic_records', data: {
            'national_id_number': citizen.idNumber,
            'institution_code': values['institution_code'],
            'qualification_name': values['qualification_name'],
            'year': int.tryParse(values['year']?.toString() ?? '') ?? DateTime.now().year,
            'final_result': values['final_result'],
          }),
          rowTitle: (r) => r['qualification_name'] as String? ?? '',
          rowSubtitle: (r) => '${r['institution_code']} • ${r['year']} • ${r['final_result']}',
        ),
        RecordTypeConfig(
          label: 'NSFAS Funding',
          icon: 'payments_outlined',
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
          fetchExisting: (repo, citizen) => repo.getRecordsByColumn(
              table: 'dhet_nsfas_funding', column: 'national_id_number', value: citizen.idNumber),
          buildInsertData: (repo, citizen, values) => repo.insertRecord(table: 'dhet_nsfas_funding', data: {
            'national_id_number': citizen.idNumber,
            'funding_year': int.tryParse(values['funding_year']?.toString() ?? '') ?? DateTime.now().year,
            'approved_status': values['approved_status'] == 'Yes',
            'disbursed_amount': num.tryParse(values['disbursed_amount']?.toString() ?? '') ?? 0,
          }),
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
          ),
          rowTitle: (r) => r['property_reference'] as String? ?? '',
          rowSubtitle: (r) => '${r['municipality'] ?? ''}, ${r['province'] ?? ''} • ${r['housing_status']}',
        ),
        RecordTypeConfig(
          label: 'Title Deed',
          icon: 'description_outlined',
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
          ),
          rowTitle: (r) => r['application_reference'] as String? ?? '',
          rowSubtitle: (r) => '${r['application_status']} • ${r['municipality'] ?? ''}',
        ),
      ];

    default:
      return const [];
  }
}
