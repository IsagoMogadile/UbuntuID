import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../../department_official/data/department_repository.dart';
import '../../department_official/domain/department_record_config.dart';
import '../../shared/domain/citizen_lookup_result.dart';
import '../data/admin_repository.dart';

/// Department codes in the order an administrator vetting someone cares
/// about most: identity and status, crime, tax, then everything else.
/// Human Settlements is left out on purpose -- administrators have no
/// business with household/property records.
const _departments = [
  ('HOME_AFFAIRS', 'Home Affairs'),
  ('SAPS', 'Police (SAPS)'),
  ('SARS', 'SARS (tax)'),
  ('LABOUR', 'Employment and Labour'),
  ('TRANSPORT', 'Transport'),
  ('SASSA', 'SASSA'),
  ('DBE', 'Basic Education'),
  ('DHET', 'Higher Education'),
];

typedef ProfileRecords = ({RecordTypeConfig config, List<Map<String, dynamic>> rows, bool failed});

enum SummaryTone { good, warning, neutral }

typedef SummaryLine = ({String topic, String value, SummaryTone tone});

/// Everything UbuntuID holds about one person, read with the
/// administrator's own access (admins can read every department table).
class DigitalProfile {
  const DigitalProfile({
    required this.citizen,
    this.departments = const [],
    this.wanted = const [],
    this.memberships = const [],
    this.marriages = const [],
    this.addresses = const [],
  });

  /// `null` -- this ID number isn't registered on UbuntuID.
  final Map<String, dynamic>? citizen;
  final List<({String name, List<ProfileRecords> records})> departments;
  final List<Map<String, dynamic>> wanted;
  final List<Map<String, dynamic>> memberships;

  /// From either side of `dha_marital_records`, with `_spouse_name` added.
  final List<Map<String, dynamic>> marriages;
  final List<Map<String, dynamic>> addresses;

  List<Map<String, dynamic>> rows(String label) => [
        for (final d in departments)
          for (final r in d.records)
            if (r.config.label == label) ...r.rows,
      ];

  bool get incomplete => departments.any((d) => d.records.any((r) => r.failed));

  /// One plain line per topic, clear or not, e.g. "Criminal record: Clear",
  /// "Married: Yes, to Lerato Mogadile".
  List<SummaryLine> get summary {
    final c = citizen;
    if (c == null) {
      return const [(topic: 'UbuntuID', value: 'Not registered on UbuntuID', tone: SummaryTone.warning)];
    }
    const good = SummaryTone.good, warn = SummaryTone.warning, plain = SummaryTone.neutral;
    final lines = <SummaryLine>[];
    void add(String topic, String value, SummaryTone tone) => lines.add((topic: topic, value: value, tone: tone));

    final status = c['current_status'] as String? ?? 'unknown';
    add('UbuntuID status', _label(status), status == 'active' ? good : warn);

    final deaths = rows('Death');
    add('Alive', deaths.isEmpty ? 'Yes' : 'No, deceased on ${deaths.first['date_of_death'] ?? 'unknown date'}',
        deaths.isEmpty ? good : warn);

    final citizenship = c['citizenship_status'] as String? ?? 'citizen';
    final permits = rows('Immigration');
    if (citizenship == 'citizen') {
      add('Citizenship', 'South African citizen', good);
    } else {
      final active = permits.where((p) => p['status'] == 'Active');
      add(
        'Citizenship',
        '${_label(citizenship)} · ${active.isEmpty ? 'no active visa or permit on record' : '${active.first['visa_type']} (active, expires ${active.first['expiry_date'] ?? 'n/a'})'}',
        active.isEmpty ? warn : plain,
      );
    }

    final crimes = rows('Criminal Record');
    add(
      'Criminal record',
      crimes.isEmpty
          ? 'Clear'
          : '${crimes.length} record${crimes.length == 1 ? '' : 's'}: '
              '${crimes.map((r) => '${_label(r['offence_code'] as String? ?? 'offence')} (${r['sentence_status'] ?? 'unknown'})').join(', ')}',
      crimes.isEmpty ? good : warn,
    );

    final wantedNow = wanted.where((w) => w['status'] == 'Wanted');
    add(
      'SAPS wanted list',
      wantedNow.isNotEmpty
          ? 'Wanted: ${wantedNow.first['reason'] ?? ''}'
          : wanted.isEmpty
              ? 'Not listed'
              : 'Previously listed (${_label(wanted.first['status'] as String? ?? '')})',
      wantedNow.isNotEmpty ? warn : good,
    );

    final clearances = rows('Clearance Certificate');
    if (clearances.isNotEmpty) {
      add('Police clearance', '${clearances.first['status']} · issued ${clearances.first['issue_date'] ?? ''}', plain);
    }

    final taxpayer = rows('Taxpayer Registration');
    final returns = rows('Tax Return');
    if (taxpayer.isEmpty) {
      add('Tax', 'Not registered with SARS', warn);
    } else {
      final t = taxpayer.first;
      final compliant = t['tax_compliance_status'] == 'Compliant';
      add('Tax', '${compliant ? 'Compliant' : 'Not compliant'} · tax number ${t['tax_number'] ?? '—'}', compliant ? good : warn);
      add(
        'Tax returns',
        returns.isEmpty
            ? 'None filed'
            : 'Latest: tax year ${returns.first['tax_year']} · ${returns.first['filing_status']} · '
                'declared R${returns.first['declared_income'] ?? 0}',
        returns.isEmpty ? warn : plain,
      );
    }

    add(
      'Married',
      marriages.isEmpty
          ? 'No'
          : marriages.map((m) {
              final details = [
                if (m['marriage_type'] != null) _label(m['marriage_type'] as String),
                if (m['date_of_marriage'] != null) 'since ${m['date_of_marriage']}',
              ];
              return 'Yes, to ${m['_spouse_name'] ?? 'ID ${m['_spouse_id']}'}'
                  '${details.isEmpty ? '' : ' (${details.join(', ')})'}';
            }).join('; '),
      plain,
    );

    final passports = rows('Passport');
    add('Passport',
        passports.isEmpty ? 'None' : '${passports.first['passport_number']} · ${passports.first['status']} · expires ${passports.first['expiry_date'] ?? 'n/a'}',
        plain);

    final licences = rows("Driver's Licence");
    add("Driver's licence",
        licences.isEmpty ? 'None' : '${licences.first['licence_number']} · code ${licences.first['licence_code']} · ${licences.first['status']}',
        plain);

    final vehicles = rows('Vehicle / Number Plate');
    add('Vehicles',
        vehicles.isEmpty ? 'None' : vehicles.map((v) => '${v['registration_number']} (${v['make']} ${v['model']})').join(', '),
        plain);

    final jobs = rows('Employment / UIF');
    add('Employment',
        jobs.isEmpty ? 'No employment record' : '${jobs.first['employer_name'] ?? 'Employer not given'} · ${jobs.first['employment_status']}',
        plain);

    final grants = rows('SASSA Grant');
    add('SASSA grants', grants.isEmpty ? 'None' : grants.map((g) => '${g['grant_type']} (${g['status']})').join(', '), plain);

    final matric = rows('Matric Certificate');
    add('Matric', matric.isEmpty ? 'No matric on record' : 'NSC ${matric.first['year']} · ${matric.first['overall_pass_status']}', plain);

    final tertiary = [...rows('Academic Record'), ...rows('Student Enrolment')];
    add('Tertiary education',
        tertiary.isEmpty ? 'None' : {for (final t in tertiary) t['qualification_name'] ?? 'Qualification'}.join(', '), plain);

    if (memberships.isNotEmpty) {
      add('Organisation accounts', memberships.map((m) => m['organisations']?['legal_name'] ?? 'Organisation').join(', '), plain);
    }
    if (incomplete) add('Note', 'Some records could not be loaded, so this profile may be incomplete.', warn);
    return lines;
  }
}

String _label(String value) {
  final text = value.replaceAll('_', ' ').trim();
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1).toLowerCase();
}

final digitalProfileProvider = FutureProvider.autoDispose.family<DigitalProfile, String>((ref, idNumber) async {
  final admin = ref.watch(adminRepositoryProvider);
  final citizen = await admin.getCitizenByIdNumber(idNumber);
  if (citizen == null) return const DigitalProfile(citizen: null);

  final citizenId = citizen['citizen_id'] as String;
  final lookup = CitizenLookupResult(
    citizenId: citizenId,
    firstName: citizen['first_name'] as String? ?? '',
    lastName: citizen['last_name'] as String? ?? '',
    idNumber: idNumber,
    currentStatus: citizen['current_status'] as String? ?? 'unknown',
  );
  final departmentRepo = ref.watch(departmentRepositoryProvider);

  Future<ProfileRecords> load(RecordTypeConfig config) async {
    try {
      return (config: config, rows: await config.fetchExisting(departmentRepo, lookup), failed: false);
    } catch (_) {
      return (config: config, rows: const <Map<String, dynamic>>[], failed: true);
    }
  }

  Future<List<Map<String, dynamic>>> safe(Future<List<Map<String, dynamic>>> f) =>
      f.catchError((_) => <Map<String, dynamic>>[]);

  final results = await Future.wait([
    Future.wait([
      for (final (code, name) in _departments)
        Future.wait([
          // Marriages come from getMarriages instead, which reads both
          // sides of the record and adds the spouse's name.
          for (final config in recordTypesForDepartment(code))
            if (config.label != 'Marriage') load(config),
        ]).then((records) => (name: name, records: records)),
    ]),
    safe(admin.getWantedListings(idNumber)),
    safe(admin.getOrganisationMemberships(idNumber)),
    safe(admin.getMarriages(idNumber)),
    safe(admin.getAddresses(citizenId)),
  ]);

  return DigitalProfile(
    citizen: citizen,
    departments: results[0] as List<({String name, List<ProfileRecords> records})>,
    wanted: results[1] as List<Map<String, dynamic>>,
    memberships: results[2] as List<Map<String, dynamic>>,
    marriages: results[3] as List<Map<String, dynamic>>,
    addresses: results[4] as List<Map<String, dynamic>>,
  );
});

/// A person's full UbuntuID digital profile for an administrator: a plain
/// summary first (criminal record, tax, marriage, citizenship, ...), then
/// every field UbuntuID holds -- identity, addresses, organisation accounts
/// and each department's records. Read-only. Used on user details, staff
/// requests and its own page.
class DigitalProfileView extends ConsumerWidget {
  const DigitalProfileView({super.key, required this.idNumber});

  final String idNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(digitalProfileProvider(idNumber));
    return profileAsync.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: LoadingIndicator()),
      error: (e, _) => AppCard(
        child: Row(
          children: [
            const Expanded(child: Text('Could not load this digital profile.')),
            TextButton(onPressed: () => ref.invalidate(digitalProfileProvider(idNumber)), child: const Text('Retry')),
          ],
        ),
      ),
      data: (profile) => _ProfileBody(profile: profile),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final DigitalProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = profile.citizen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(
          name: c == null ? null : '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim(),
          lines: profile.summary,
        ),
        if (c != null) ...[
          const SizedBox(height: 20),
          Text('Full profile', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Section(title: 'Identity', initiallyExpanded: true, entries: [_fields(c)]),
          _Section(title: 'Addresses', entries: [for (final a in profile.addresses) _fields(a)]),
          _Section(
            title: 'Marriages',
            entries: [
              for (final m in profile.marriages)
                {
                  'Spouse': '${m['_spouse_name'] ?? 'Unknown'} (ID ${m['_spouse_id']})',
                  ..._fields(m),
                },
            ],
          ),
          _Section(
            title: 'Organisation accounts',
            entries: [
              for (final m in profile.memberships)
                {
                  'Organisation': m['organisations']?['legal_name'] ?? 'Organisation',
                  'Role': m['user_role'] == 'manager' ? 'Head' : _label(m['user_role'] as String? ?? ''),
                  'Account': m['active'] == false ? 'Inactive' : 'Active',
                  'Organisation status': _label(m['organisations']?['registration_status'] as String? ?? ''),
                },
            ],
            onTapEntry: (i) {
              final id = profile.memberships[i]['organisations']?['organisation_id'];
              if (id != null) context.push('${AppRoutes.adminOrganisations}/$id');
            },
          ),
          _Section(title: 'SAPS wanted list', entries: [for (final w in profile.wanted) _fields(w)]),
          for (final dept in profile.departments)
            for (final r in dept.records)
              _Section(
                title: '${dept.name} · ${r.config.label}',
                failed: r.failed,
                entries: [for (final row in r.rows) _fields(row)],
              ),
        ],
      ],
    );
  }
}

/// Every column of a row as label → value, minus internal keys (row ids,
/// foreign keys, timestamps) and the profile's own `_` helper fields.
Map<String, Object?> _fields(Map<String, dynamic> row) {
  const hidden = {'created_at', 'updated_at', 'auth_user_id', 'national_id_number', 'spouse_1_id', 'spouse_2_id'};
  final out = <String, Object?>{};
  row.forEach((key, value) {
    if (key.startsWith('_') || hidden.contains(key) || key.endsWith('_id')) return;
    if (value is Map || value is List) return;
    out[_label(key)] = value;
  });
  return out;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.name, required this.lines});

  final String? name;
  final List<SummaryLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warnings = lines.where((l) => l.tone == SummaryTone.warning).length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name != null) Text(name!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            warnings == 0 ? 'Nothing to worry about' : '$warnings thing${warnings == 1 ? '' : 's'} to check',
            style: TextStyle(color: warnings == 0 ? AppColors.green : AppColors.error, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (line.tone) {
                      SummaryTone.good => Icons.check_circle_outline,
                      SummaryTone.warning => Icons.error_outline,
                      SummaryTone.neutral => Icons.circle_outlined,
                    },
                    size: 18,
                    color: switch (line.tone) {
                      SummaryTone.good => AppColors.green,
                      SummaryTone.warning => AppColors.error,
                      SummaryTone.neutral => AppColors.charcoalMuted,
                    },
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: Text(line.topic, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Text(line.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A collapsible block listing each entry's fields in full.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.entries,
    this.initiallyExpanded = false,
    this.failed = false,
    this.onTapEntry,
  });

  final String title;
  final List<Map<String, Object?>> entries;
  final bool initiallyExpanded;
  final bool failed;
  final void Function(int index)? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              failed
                  ? 'Could not load'
                  : entries.isEmpty
                      ? 'None'
                      : '${entries.length} record${entries.length == 1 ? '' : 's'}',
              style: failed ? const TextStyle(color: AppColors.error) : muted,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, entry) in entries.indexed) ...[
                if (i > 0) const Divider(height: 20),
                InkWell(
                  onTap: onTapEntry == null ? null : () => onTapEntry!(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final MapEntry(:key, :value) in entry.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 150, child: Text(key, style: muted)),
                              Expanded(child: Text(value == null || '$value'.isEmpty ? '—' : _display(value))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _display(Object value) {
    if (value is bool) return value ? 'Yes' : 'No';
    final text = '$value';
    // ISO timestamps → just the date.
    return RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(text) ? text.split('T').first : text;
  }
}
