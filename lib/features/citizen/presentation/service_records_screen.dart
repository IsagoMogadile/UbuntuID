import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import '../domain/credential_item.dart';

/// Where tapping a credential leads: its department's full records.
/// `null` for credential types with no details screen.
String? credentialDetailRoute(CredentialItem credential) {
  return switch (credential.typeCode) {
    'DRIVERS_LICENCE' => AppRoutes.citizenDriversLicence,
    'SASSA_STATUS' => AppRoutes.citizenSassa,
    final code when _sectionsByType.containsKey(code) =>
      '${AppRoutes.citizenServiceRecords}?type=${Uri.encodeComponent(code)}'
          '&title=${Uri.encodeComponent(credential.typeName)}',
    _ => null,
  };
}

/// Full details behind a department service (Passport, Tax, Police
/// Clearance, Matric, Higher Education, Employment): every record that
/// department holds for this citizen, grouped into sections. View-only --
/// the department issues and updates these records.
class ServiceRecordsScreen extends ConsumerWidget {
  const ServiceRecordsScreen({super.key, required this.typeCode, this.title});

  final String typeCode;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = _sectionsByType[typeCode] ?? const <_Section>[];

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Service details')),
      body: sections.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No details available',
              message: 'This service has no further details to show.',
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myNscStatementsProvider);
                for (final section in sections) {
                  ref.invalidate(_sectionRowsProvider(section.key));
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: 20),
                    _SectionView(section: sections[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionView extends ConsumerWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(_sectionRowsProvider(section.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: section.title),
        rowsAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorView(
            message: 'Could not load ${section.title.toLowerCase()}.',
            onRetry: () => ref.invalidate(_sectionRowsProvider(section.key)),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return EmptyState(icon: section.icon, title: 'Nothing on record', message: section.emptyMessage);
            }
            return Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecordCard(section: section, row: row),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.section, required this.row});

  final _Section section;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final status = section.status?.call(row);
    final shownKeys = {for (final f in section.fields) f.key};

    // Columns without specific wording are still shown, so the citizen
    // sees everything the department holds -- minus internal keys.
    final extras = row.entries.where((e) =>
        !shownKeys.contains(e.key) &&
        !section.hiddenKeys.contains(e.key) &&
        !_internalKeys.contains(e.key) &&
        !e.key.endsWith('_id') &&
        e.value is! Map &&
        e.value is! List &&
        _hasValue(e.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(section.cardTitle(row), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (status != null && status.isNotEmpty) StatusBadge.fromStatus(status),
            ],
          ),
          const SizedBox(height: 12),
          for (final field in section.fields) DetailRow(label: field.label, value: field.display(row)),
          for (final entry in extras) DetailRow(label: _humanise(entry.key), value: _formatAny(entry.value)),
          if (section.footer != null) ...[
            const SizedBox(height: 8),
            section.footer!(row),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section configuration
// ---------------------------------------------------------------------------

enum _Kind { text, date, money, yesNo }

class _Field {
  const _Field(this.key, this.label, [this.kind = _Kind.text]) : compute = null;

  /// A value built from the row rather than read from one column.
  const _Field.computed(this.key, this.label, String? Function(Map<String, dynamic> row) this.compute)
      : kind = _Kind.text;

  final String key;
  final String label;
  final _Kind kind;
  final String? Function(Map<String, dynamic> row)? compute;

  String display(Map<String, dynamic> row) {
    if (compute != null) {
      final value = compute!(row);
      return value == null || value.trim().isEmpty ? _notOnRecord : value;
    }
    final value = row[key];
    if (!_hasValue(value)) return _notOnRecord;
    return switch (kind) {
      _Kind.date => _formatDate(value) ?? value.toString(),
      _Kind.money => num.tryParse(value.toString()) == null
          ? value.toString()
          : AppFormatters.currencyZar(num.parse(value.toString())),
      _Kind.yesNo => _isTrue(value) ? 'Yes' : 'No',
      _Kind.text => value.toString(),
    };
  }
}

class _Section {
  const _Section({
    required this.key,
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.fetch,
    required this.cardTitle,
    required this.fields,
    this.status,
    this.hiddenKeys = const {},
    this.footer,
  });

  /// Unique across all sections; keys [_sectionRowsProvider].
  final String key;
  final String title;
  final IconData icon;
  final String emptyMessage;
  final Future<List<Map<String, dynamic>>> Function(CitizenRepository repo) fetch;
  final String Function(Map<String, dynamic> row) cardTitle;
  final String? Function(Map<String, dynamic> row)? status;
  final List<_Field> fields;

  /// Columns already covered by a computed field, left out of the extras.
  final Set<String> hiddenKeys;

  /// Extra content under a record's details (e.g. Statement of Results).
  final Widget Function(Map<String, dynamic> row)? footer;
}

final _sectionRowsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, key) {
  final section = _sectionsByType.values.expand((s) => s).firstWhere((s) => s.key == key);
  return section.fetch(ref.watch(citizenRepositoryProvider));
});

const _institutionEmbed = '*, dhet_institutions(institution_name)';

String? _institutionName(Map<String, dynamic> row) =>
    (row['dhet_institutions'] as Map<String, dynamic>?)?['institution_name'] as String? ??
    row['institution_code'] as String?;

final _passports = _Section(
  key: 'passports',
  title: 'Passports',
  icon: Icons.menu_book_outlined,
  emptyMessage: 'Home Affairs has no passport on file for you.',
  fetch: (repo) => repo.getDepartmentRecords(table: 'dha_passports', orderBy: 'issue_date'),
  cardTitle: (r) => 'South African Passport',
  status: (r) => r['status'] as String?,
  fields: const [
    _Field('passport_number', 'Passport number'),
    _Field('issue_date', 'Issue date', _Kind.date),
    _Field('expiry_date', 'Expiry date', _Kind.date),
  ],
);

final _immigration = _Section(
  key: 'immigration',
  title: 'Visas and permits',
  icon: Icons.flight_land_outlined,
  emptyMessage: 'You have no visas or permits on record.',
  fetch: (repo) => repo.getDepartmentRecords(table: 'dha_immigration_records', orderBy: 'issue_date'),
  cardTitle: (r) => _text(r['visa_type'], 'Visa or permit'),
  status: (r) => r['status'] as String?,
  fields: const [
    _Field('visa_type', 'Type'),
    _Field('issue_date', 'Issue date', _Kind.date),
    _Field('expiry_date', 'Expiry date', _Kind.date),
  ],
);

final _marriages = _Section(
  key: 'marriages',
  title: 'Marriage records',
  icon: Icons.favorite_outline,
  emptyMessage: 'You have no marriage on record.',
  fetch: (repo) => repo.getMyMarriages(),
  cardTitle: spouseLabel,
  status: (r) => r['status'] as String?,
  hiddenKeys: const {'spouse_id_number'},
  fields: const [
    _Field('spouse_name', 'Spouse'),
    _Field('marriage_type', 'Marriage type'),
    _Field('date_of_marriage', 'Date of marriage', _Kind.date),
  ],
);

final Map<String, List<_Section>> _sectionsByType = {
  // The Home Affairs records reached from Digital Identity.
  'HOME_AFFAIRS': [_marriages, _passports, _immigration],
  'PASSPORT': [_passports, _immigration, _marriages],
  'TAX_COMPLIANCE': [
    _Section(
      key: 'taxpayer',
      title: 'Tax registration',
      icon: Icons.account_balance_outlined,
      emptyMessage: 'SARS has no tax registration on file for you.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'sars_taxpayers', orderBy: 'registered_date'),
      cardTitle: (r) => 'Taxpayer registration',
      status: (r) => r['tax_compliance_status'] as String?,
      fields: const [
        _Field('tax_number', 'Tax number'),
        _Field('tax_compliance_status', 'Compliance status'),
        _Field('registered_date', 'Registered on', _Kind.date),
      ],
    ),
    _Section(
      key: 'tax_returns',
      title: 'Tax returns',
      icon: Icons.receipt_long_outlined,
      emptyMessage: 'You have no tax returns on record.',
      fetch: (repo) => repo.getMyTaxReturns(),
      cardTitle: (r) => r['tax_year'] == null ? 'Tax return' : 'Tax year ${r['tax_year']}',
      status: (r) => r['filing_status'] as String?,
      fields: const [
        _Field('tax_year', 'Tax year'),
        _Field('declared_income', 'Declared income', _Kind.money),
        _Field('refund_or_due_amount', 'Refund or amount due', _Kind.money),
        _Field('filing_status', 'Filing status'),
      ],
    ),
  ],
  'CRIMINAL_CLEARANCE': [
    _Section(
      key: 'clearance',
      title: 'Clearance certificates',
      icon: Icons.verified_outlined,
      emptyMessage: 'SAPS has not issued you a clearance certificate.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'saps_clearance_certificates', orderBy: 'issue_date'),
      cardTitle: (r) => 'Police clearance certificate',
      status: (r) => r['status'] as String?,
      fields: const [
        _Field('status', 'Result'),
        _Field('issue_date', 'Issue date', _Kind.date),
      ],
    ),
    _Section(
      key: 'criminal_records',
      title: 'Criminal records',
      icon: Icons.gavel_outlined,
      emptyMessage: 'You have no criminal records on file.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'saps_criminal_records', orderBy: 'conviction_date'),
      cardTitle: (r) => _capitalise(_humanise(_text(r['offence_code'], 'Offence').toLowerCase())),
      status: (r) => r['sentence_status'] as String?,
      fields: const [
        _Field('case_number', 'Case number'),
        _Field('offence_code', 'Offence'),
        _Field('conviction_date', 'Conviction date', _Kind.date),
        _Field('sentence_status', 'Sentence status'),
      ],
    ),
  ],
  'NSC': [
    _Section(
      key: 'nsc',
      title: 'Matric results',
      icon: Icons.school_outlined,
      emptyMessage: 'Basic Education has no matric results on file for you.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'dbe_nsc_results', orderBy: 'year'),
      cardTitle: (r) => r['year'] == null ? 'National Senior Certificate' : 'National Senior Certificate ${r['year']}',
      status: (r) => r['overall_pass_status'] as String?,
      fields: const [
        _Field('matric_exam_number', 'Exam number'),
        _Field('year', 'Year written'),
        _Field('overall_pass_status', 'Pass type'),
      ],
      footer: (r) => _StatementOfResultsTile(matricExamNumber: r['matric_exam_number']?.toString() ?? ''),
    ),
  ],
  'TERTIARY_QUALIFICATION': [
    _Section(
      key: 'academic_records',
      title: 'Qualifications',
      icon: Icons.workspace_premium_outlined,
      emptyMessage: 'You have no completed qualifications on record.',
      fetch: (repo) => repo.getDepartmentRecords(
          table: 'dhet_academic_records', select: _institutionEmbed, orderBy: 'year'),
      cardTitle: (r) => _text(r['qualification_name'], 'Qualification'),
      status: (r) => r['final_result'] as String?,
      hiddenKeys: const {'institution_code'},
      fields: const [
        _Field.computed('institution', 'Institution', _institutionName),
        _Field('year', 'Year'),
        _Field('final_result', 'Final result'),
      ],
    ),
    _Section(
      key: 'enrolments',
      title: 'Enrolments',
      icon: Icons.school_outlined,
      emptyMessage: 'You have no enrolments on record.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'dhet_student_enrollment', select: _institutionEmbed),
      cardTitle: (r) => _text(r['qualification_name'], 'Enrolment'),
      status: (r) => r['completion_status'] as String?,
      hiddenKeys: const {'institution_code'},
      fields: const [
        _Field.computed('institution', 'Institution', _institutionName),
        _Field('completion_status', 'Status'),
        _Field('study_mode', 'Study mode'),
      ],
    ),
    _Section(
      key: 'nsfas',
      title: 'NSFAS funding',
      icon: Icons.payments_outlined,
      emptyMessage: 'You have no NSFAS funding on record.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'dhet_nsfas_funding', orderBy: 'funding_year'),
      cardTitle: (r) => r['funding_year'] == null ? 'NSFAS funding' : 'NSFAS funding ${r['funding_year']}',
      status: (r) => r['approved_status'] == null ? null : (_isTrue(r['approved_status']) ? 'approved' : 'declined'),
      fields: const [
        _Field('funding_year', 'Funding year'),
        _Field('approved_status', 'Approved', _Kind.yesNo),
        _Field('disbursed_amount', 'Amount paid out', _Kind.money),
      ],
    ),
  ],
  'LABOUR_STATUS': [
    _Section(
      key: 'employment',
      title: 'Employment and UIF',
      icon: Icons.work_outline,
      emptyMessage: 'Employment and Labour has no employment records on file for you.',
      fetch: (repo) => repo.getDepartmentRecords(table: 'labour_employment_records', orderBy: 'start_date'),
      cardTitle: (r) => _text(r['employer_name'], 'Employment record'),
      status: (r) => r['employment_status'] as String?,
      fields: const [
        _Field('employer_name', 'Employer'),
        _Field('employment_status', 'Employment status'),
        _Field('start_date', 'Start date', _Kind.date),
        _Field('uif_contribution_amount', 'UIF contribution (per month)', _Kind.money),
        _Field('uif_claim_status', 'UIF claim status'),
      ],
    ),
  ],
};

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

const _notOnRecord = 'Not on record';

/// Bookkeeping columns a citizen doesn't need to see.
const _internalKeys = {'national_id_number', 'owner_id', 'created_at', 'updated_at'};

bool _hasValue(Object? value) => value != null && value.toString().trim().isNotEmpty;

bool _isTrue(Object? value) => value == true || const {'true', 'yes', '1'}.contains(value.toString().toLowerCase());

String _text(Object? value, String fallback) => _hasValue(value) ? value.toString() : fallback;

String _humanise(String value) => _capitalise(value.replaceAll('_', ' ').trim());

String _capitalise(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String? _formatDate(Object? value) {
  final parsed = DateTime.tryParse(value.toString());
  return parsed == null ? null : AppFormatters.date(parsed);
}

String _formatAny(Object? value) {
  if (value is bool) return value ? 'Yes' : 'No';
  final text = value.toString();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) return _formatDate(text) ?? text;
  return text;
}

/// "Statement of Results" inside a National Senior Certificate card. Opens
/// the published statement for that certificate; until one is published it
/// says so and stays inactive.
class _StatementOfResultsTile extends ConsumerWidget {
  const _StatementOfResultsTile({required this.matricExamNumber});

  final String matricExamNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statementsAsync = ref.watch(myNscStatementsProvider);
    final available = statementsAsync.value?.any((s) => s.matricExamNumber == matricExamNumber) ?? false;
    final note = switch (statementsAsync) {
      AsyncLoading() => 'Checking for your Statement of Results…',
      AsyncError() => 'Your Statement of Results could not be checked. Pull down to try again.',
      _ when !available => 'Your Statement of Results is not yet available.',
      _ => null,
    };

    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
        title: const Text('Statement of Results', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(note ?? 'View your examination subjects, marks and achievement levels.'),
        trailing: available ? const Icon(Icons.chevron_right) : null,
        onTap: available
            ? () => context.push('${AppRoutes.citizenNscStatement}/${Uri.encodeComponent(matricExamNumber)}')
            : null,
      ),
    );
  }
}
