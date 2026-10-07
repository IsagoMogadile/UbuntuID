import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/credential_status.dart';
import '../../../services/service_providers.dart';
import '../../department_official/data/department_repository.dart';
import '../domain/report_data.dart';
import '../domain/report_range.dart';

/// Builds each role's report from live data only.
///
/// Access control is layered, never UI-only:
/// 1. Each report kind is only reachable from its own role's shell, behind
///    the router's role-area guard (`_resolveRoleAreaRedirect`).
/// 2. Every query runs as the signed-in user through the normal Supabase
///    client, so the existing RLS policies apply -- no `SECURITY DEFINER`
///    RPC or service key is involved, so a report can never read more than
///    that user's own screens already can.
/// 3. Each query is additionally filtered to the caller's own scope
///    (organisation id / department credential types / citizen id),
///    resolved from their own auth user -- defence in depth, and it keeps an
///    admin-style policy from ever widening a non-admin report.
///
/// Aggregates are computed client-side from minimal columns (statuses and
/// timestamps). Organisation and department reports never select citizen
/// names or ID numbers.
class ReportsRepository {
  ReportsRepository(this._client, this._departmentRepository);

  final SupabaseClient _client;
  final DepartmentRepository _departmentRepository;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('You are not signed in.');
    return id;
  }

  /// PostgREST caps a response at 1000 rows, so fetch page by page until a
  /// short page comes back -- otherwise larger tables would be silently
  /// under-counted.
  Future<List<Map<String, dynamic>>> _fetchAll(
    PostgrestTransformBuilder<PostgrestList> Function(int from, int to) page,
  ) async {
    const size = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += size) {
      final batch = await page(from, from + size - 1);
      rows.addAll(batch);
      if (batch.length < size) return rows;
    }
  }

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

  static List<(String, int)> _countBy(Iterable<String> values, {bool humanise = true, int? top}) {
    final counts = <String, int>{};
    for (final v in values) {
      final key = humanise ? humaniseStatus(v) : v;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final limited = top == null ? sorted : sorted.take(top);
    return [for (final e in limited) (e.key, e.value)];
  }

  static final _shortDate = DateFormat('d MMM y');

  // verification_requests.overall_status is CHECK-constrained to pending,
  // processing, completed, partially_verified, failed, rejected, cancelled.
  static const _inProgress = {'pending', 'processing'};
  static const _completed = {'completed', 'partially_verified'};
  static const _rejected = {'rejected', 'failed'};

  static List<ReportMetric> _requestMetrics(List<String> statuses, {required String noun}) => [
        ReportMetric(label: noun, value: statuses.length, icon: Icons.fact_check_outlined),
        ReportMetric(
          label: 'Completed',
          value: statuses.where(_completed.contains).length,
          icon: Icons.task_alt_outlined,
        ),
        ReportMetric(
          label: 'In progress',
          value: statuses.where(_inProgress.contains).length,
          icon: Icons.hourglass_top_outlined,
        ),
        ReportMetric(
          label: 'Rejected or failed',
          value: statuses.where(_rejected.contains).length,
          icon: Icons.cancel_outlined,
        ),
      ];

  // ---------------------------------------------------------------------
  // Administrator -- system-wide (admin RLS: `is_admin()` on every table).
  // ---------------------------------------------------------------------

  Future<ReportData> systemReport(ReportRange range) async {
    final totals = await Future.wait([
      _client.from('citizens').count(CountOption.exact),
      _client.from('organisations').count(CountOption.exact),
      _client.from('organisations').count(CountOption.exact).eq('registration_status', 'approved'),
      _client.from('departments').count(CountOption.exact).eq('active', true),
      _client.from('credentials').count(CountOption.exact),
    ]);

    final (citizens, requests, credentials, appeals) = await (
      _fetchAll((f, t) => _client
          .from('citizens')
          .select('registered_at')
          .gte('registered_at', range.startTimestamp)
          .lt('registered_at', range.endExclusiveTimestamp)
          .order('citizen_id')
          .range(f, t)),
      _fetchAll((f, t) => _client
          .from('verification_requests')
          .select('overall_status, requested_at, organisations(legal_name)')
          .gte('requested_at', range.startTimestamp)
          .lt('requested_at', range.endExclusiveTimestamp)
          .order('request_id')
          .range(f, t)),
      _fetchAll((f, t) => _client
          .from('credentials')
          .select('status, expiry_date, credential_types(departments(department_name))')
          .gte('issued_date', range.startDate)
          .lte('issued_date', range.endDate)
          .order('credential_id')
          .range(f, t)),
      _fetchAll((f, t) => _client
          .from('appeals')
          .select('status')
          .gte('submitted_at', range.startTimestamp)
          .lt('submitted_at', range.endExclusiveTimestamp)
          .order('appeal_id')
          .range(f, t)),
    ).wait;

    final requestStatuses = [for (final r in requests) r['overall_status'] as String? ?? 'unknown'];

    return ReportData(
      kind: ReportKind.system,
      ownerLabel: 'Scope',
      ownerName: 'UbuntuID platform (all departments and organisations)',
      range: range,
      metricGroups: [
        ReportMetricGroup(title: 'Platform totals (all time)', metrics: [
          ReportMetric(label: 'Registered citizens', value: totals[0], icon: Icons.groups_outlined),
          ReportMetric(label: 'Organisations', value: totals[1], icon: Icons.apartment_outlined),
          ReportMetric(label: 'Active organisations', value: totals[2], icon: Icons.verified_outlined),
          ReportMetric(label: 'Active departments', value: totals[3], icon: Icons.account_balance_outlined),
          ReportMetric(label: 'Credentials', value: totals[4], icon: Icons.badge_outlined),
        ]),
        ReportMetricGroup(title: 'Verification activity in this period', metrics: _requestMetrics(requestStatuses, noun: 'Requests')),
        ReportMetricGroup(title: 'Other activity in this period', metrics: [
          ReportMetric(label: 'New citizens', value: citizens.length, icon: Icons.person_add_alt_outlined),
          ReportMetric(label: 'Credentials issued', value: credentials.length, icon: Icons.workspace_premium_outlined),
          ReportMetric(label: 'Appeals lodged', value: appeals.length, icon: Icons.gavel_outlined),
        ]),
      ],
      sections: [
        TrendSection(
          title: 'Citizen registrations over time',
          points: range.trend(citizens.map((r) => _date(r['registered_at']))),
        ),
        TrendSection(
          title: 'Verification requests over time',
          points: range.trend(requests.map((r) => _date(r['requested_at']))),
        ),
        BreakdownSection(title: 'Verification requests by status', items: _countBy(requestStatuses), asDonut: true),
        BreakdownSection(
          title: 'Organisation usage',
          description: 'Verification requests made by each organisation (top 10).',
          items: _countBy(
            requests.map((r) => (r['organisations'] as Map<String, dynamic>?)?['legal_name'] as String? ?? 'Unknown'),
            humanise: false,
            top: 10,
          ),
        ),
        BreakdownSection(
          title: 'Credentials issued by department',
          items: _countBy(
            credentials.map((r) =>
                ((r['credential_types'] as Map<String, dynamic>?)?['departments'] as Map<String, dynamic>?)?['department_name']
                    as String? ??
                'Unknown'),
            humanise: false,
          ),
        ),
        BreakdownSection(
          title: 'Status of credentials issued',
          description: 'Expired is worked out from each credential\'s expiry date.',
          items: _countBy(credentials.map((r) => effectiveCredentialStatus(r['status'] as String?, _date(r['expiry_date'])))),
          asDonut: true,
        ),
      ],
      notes: const [
        '"Requests" are organisation verification requests -- the only request workflow UbuntuID records across '
            'the whole platform. Department record changes are not logged as requests.',
        'Platform totals are counts as of now; every other figure covers the reporting period only.',
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Organisation -- only its own data. RLS resolves
  // `current_org_user_organisation_id()` to NULL unless the organisation is
  // approved, and every query below is also filtered to that id.
  // ---------------------------------------------------------------------

  Future<ReportData> organisationReport(ReportRange range) async {
    final orgUser = await _client
        .from('organisation_users')
        .select('organisation_id, organisations(legal_name, registration_status)')
        .eq('auth_user_id', _userId)
        .maybeSingle();
    final organisationId = orgUser?['organisation_id'] as String?;
    final organisation = orgUser?['organisations'] as Map<String, dynamic>?;
    if (organisationId == null) throw const AppException('No organisation is linked to this account.');
    if (organisation?['registration_status'] != 'approved') {
      throw const AppException('Reports become available once a UbuntuID administrator approves your organisation.');
    }

    final totals = await Future.wait([
      _client
          .from('organisation_users')
          .count(CountOption.exact)
          .eq('organisation_id', organisationId)
          .eq('active', true),
      _client.from('organisation_credential_scopes').count(CountOption.exact).eq('organisation_id', organisationId),
      _client.from('organisation_employees').count(CountOption.exact).eq('organisation_id', organisationId),
    ]);

    final requests = await _fetchAll((f, t) => _client
        .from('verification_requests')
        .select('request_id, overall_status, requested_at, verification_results(match_status, credential_types(display_name))')
        .eq('organisation_id', organisationId)
        .gte('requested_at', range.startTimestamp)
        .lt('requested_at', range.endExclusiveTimestamp)
        .order('requested_at', ascending: false)
        .range(f, t));

    final statuses = [for (final r in requests) r['overall_status'] as String? ?? 'unknown'];
    final results = [
      for (final r in requests)
        for (final line in (r['verification_results'] as List? ?? const [])) line as Map<String, dynamic>,
    ];

    return ReportData(
      kind: ReportKind.organisation,
      ownerLabel: 'Organisation',
      ownerName: organisation?['legal_name'] as String? ?? 'Organisation',
      range: range,
      metricGroups: [
        ReportMetricGroup(title: 'Organisation (current)', metrics: [
          ReportMetric(label: 'Active users', value: totals[0], icon: Icons.group_outlined),
          ReportMetric(label: 'Credential types you may verify', value: totals[1], icon: Icons.rule_outlined),
          ReportMetric(label: 'Employees recorded', value: totals[2], icon: Icons.work_outline),
        ]),
        ReportMetricGroup(
          title: 'Verification requests in this period',
          metrics: _requestMetrics(statuses, noun: 'Requests'),
        ),
        ReportMetricGroup(title: 'Credential checks in this period', metrics: [
          ReportMetric(label: 'Credentials checked', value: results.length, icon: Icons.badge_outlined),
          ReportMetric(
            label: 'Verified (exact match)',
            value: results.where((r) => r['match_status'] == 'exact_match').length,
            icon: Icons.verified_outlined,
          ),
          ReportMetric(
            label: 'Did not match',
            value: results.where((r) => r['match_status'] == 'no_match').length,
            icon: Icons.highlight_off_outlined,
          ),
        ]),
      ],
      sections: [
        TrendSection(title: 'Verification requests over time', points: range.trend(requests.map((r) => _date(r['requested_at'])))),
        BreakdownSection(title: 'Requests by status', items: _countBy(statuses), asDonut: true),
        BreakdownSection(
          title: 'Services used',
          description: 'Credential types your organisation checked.',
          items: _countBy(
            results.map((r) => (r['credential_types'] as Map<String, dynamic>?)?['display_name'] as String? ?? 'Unknown'),
            humanise: false,
          ),
        ),
        BreakdownSection(title: 'Check outcomes', items: _countBy(results.map((r) => r['match_status'] as String? ?? 'pending'))),
        TableSection(
          title: 'Recent activity',
          description: 'Latest 10 requests in this period. Citizen details stay on the Applicants screen.',
          headers: const ['Date', 'Reference', 'Credentials', 'Status'],
          rows: [
            for (final r in requests.take(10))
              [
                _formatDate(r['requested_at']),
                (r['request_id'] as String).substring(0, 8).toUpperCase(),
                '${(r['verification_results'] as List? ?? const []).length}',
                humaniseStatus(r['overall_status'] as String? ?? 'unknown'),
              ],
          ],
        ),
      ],
      notes: const [
        'Only requests made by your organisation are included.',
        '"Organisation (current)" figures are counts as of now; everything else covers the reporting period only.',
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Department -- only its own credential types and record tables.
  // ---------------------------------------------------------------------

  Future<ReportData> departmentReport(ReportRange range) async {
    final profile = await _departmentRepository.getProfile();
    if (profile.departmentId.isEmpty) throw const AppException('No department is linked to this account.');

    final typeRows = await _client
        .from('credential_types')
        .select('credential_type_id')
        .eq('issuing_department_id', profile.departmentId);
    final typeIds = [for (final r in typeRows) r['credential_type_id'] as String];
    final isHumanSettlements = profile.departmentCode == 'DHS';

    final (stats, issued, applications) = await (
      _departmentRepository.getDashboardStats(),
      typeIds.isEmpty
          ? Future.value(const <Map<String, dynamic>>[])
          : _fetchAll((f, t) => _client
              .from('credentials')
              .select('citizen_id, status, issued_date, expiry_date, credential_types(display_name)')
              .inFilter('credential_type_id', typeIds)
              .gte('issued_date', range.startDate)
              .lte('issued_date', range.endDate)
              .order('credential_id')
              .range(f, t)),
      isHumanSettlements
          ? _fetchAll((f, t) => _client
              .from('housing_applications')
              .select('application_status, created_at')
              .gte('created_at', range.startTimestamp)
              .lt('created_at', range.endExclusiveTimestamp)
              .order('created_at')
              .range(f, t))
          : Future.value(const <Map<String, dynamic>>[]),
    ).wait;

    final citizensServed = {for (final r in issued) r['citizen_id']}.length;
    final applicationStatuses = [for (final a in applications) a['application_status'] as String? ?? 'unknown'];

    return ReportData(
      kind: ReportKind.department,
      ownerLabel: 'Department',
      ownerName: profile.departmentName,
      range: range,
      metricGroups: [
        ReportMetricGroup(title: 'Department (current)', metrics: [
          ReportMetric(label: 'Active officials', value: stats.activeOfficials, icon: Icons.groups_outlined),
          ReportMetric(label: 'Records on file', value: stats.totalRecords, icon: Icons.folder_open_outlined),
        ]),
        ReportMetricGroup(title: 'Activity in this period', metrics: [
          ReportMetric(label: 'Credentials issued', value: issued.length, icon: Icons.workspace_premium_outlined),
          ReportMetric(label: 'Citizens served', value: citizensServed, icon: Icons.person_outline),
        ]),
        if (isHumanSettlements)
          ReportMetricGroup(title: 'Housing applications in this period', metrics: [
            ReportMetric(label: 'Received', value: applications.length, icon: Icons.inbox_outlined),
            ReportMetric(
              label: 'Pending',
              value: applicationStatuses.where((s) => s == 'submitted' || s == 'under_review').length,
              icon: Icons.hourglass_top_outlined,
            ),
            ReportMetric(
              label: 'Approved',
              value: applicationStatuses.where((s) => s == 'approved').length,
              icon: Icons.task_alt_outlined,
            ),
            ReportMetric(
              label: 'Rejected',
              value: applicationStatuses.where((s) => s == 'rejected' || s == 'declined').length,
              icon: Icons.cancel_outlined,
            ),
          ]),
      ],
      sections: [
        TrendSection(
          title: 'Credentials issued over time',
          points: range.trend(issued.map((r) => _date(r['issued_date']))),
        ),
        if (isHumanSettlements) ...[
          TrendSection(
            title: 'Housing applications over time',
            points: range.trend(applications.map((r) => _date(r['created_at']))),
          ),
          BreakdownSection(title: 'Housing applications by status', items: _countBy(applicationStatuses), asDonut: true),
        ],
        BreakdownSection(
          title: 'Credentials issued by type',
          items: _countBy(
            issued.map((r) => (r['credential_types'] as Map<String, dynamic>?)?['display_name'] as String? ?? 'Unknown'),
            humanise: false,
          ),
        ),
        BreakdownSection(
          title: 'Status of credentials issued',
          description: 'Expired is worked out from each credential\'s expiry date.',
          items: _countBy(issued.map((r) => effectiveCredentialStatus(r['status'] as String?, _date(r['expiry_date'])))),
          asDonut: true,
        ),
        BreakdownSection(
          title: 'Records by service (all time)',
          description: 'Records held for each service this department manages.',
          items: [...stats.recordsByService]..sort((a, b) => b.$2.compareTo(a.$2)),
        ),
      ],
      notes: [
        'Departments do not receive verification requests: verification is automated and department access to it '
            'was removed by design (docs/DECISIONS.md), so request figures are not part of this report.',
        if (isHumanSettlements)
          'Housing applications are the department\'s request workflow and are filtered to the reporting period.'
        else
          'This department has no request/application workflow in UbuntuID, so there are no '
              'received/completed/pending/rejected request figures to report.',
        '"Records by service" is all-time: department record tables do not share a common creation date to filter on.',
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Citizen -- only their own rows (RLS: `citizen_id = current_citizen_id()`;
  // verification visibility via `can_view_verification_request`).
  // ---------------------------------------------------------------------

  Future<ReportData> citizenReport(ReportRange range) async {
    final citizen = await _client
        .from('citizens')
        .select('citizen_id, first_name, last_name')
        .eq('auth_user_id', _userId)
        .maybeSingle();
    final citizenId = citizen?['citizen_id'] as String?;
    if (citizenId == null) throw const AppException('No citizen record is linked to this account.');

    final (credentials, requests, consents, appeals) = await (
      _client
          .from('credentials')
          .select('credential_type_id, status, issued_date, expiry_date, '
              'credential_types(display_name, departments(department_name))')
          .eq('citizen_id', citizenId)
          .order('issued_date', ascending: false),
      _client
          .from('verification_requests')
          .select('overall_status, requested_at, responded_at, organisations(legal_name), '
              'verification_results(match_status, credential_type_id, credential_types(display_name))')
          .eq('citizen_id', citizenId)
          .order('requested_at', ascending: false),
      _client
          .from('consent_grants')
          .select('granted_at')
          .eq('citizen_id', citizenId)
          .gte('granted_at', range.startTimestamp)
          .lt('granted_at', range.endExclusiveTimestamp),
      _client
          .from('appeals')
          .select('status')
          .eq('citizen_id', citizenId)
          .gte('submitted_at', range.startTimestamp)
          .lt('submitted_at', range.endExclusiveTimestamp),
    ).wait;

    // Most recent successful check per credential type, across all time --
    // "last verified" isn't limited to the reporting period.
    final lastVerified = <String, DateTime>{};
    for (final request in requests) {
      final when = _date(request['responded_at']) ?? _date(request['requested_at']);
      if (when == null) continue;
      for (final line in (request['verification_results'] as List? ?? const [])) {
        final result = line as Map<String, dynamic>;
        final typeId = result['credential_type_id'] as String?;
        if (typeId == null || result['match_status'] != 'exact_match') continue;
        final previous = lastVerified[typeId];
        if (previous == null || when.isAfter(previous)) lastVerified[typeId] = when;
      }
    }

    final credentialStatuses = [
      for (final c in credentials) effectiveCredentialStatus(c['status'] as String?, _date(c['expiry_date'])),
    ];
    final periodRequests = [for (final r in requests) if (range.contains(_date(r['requested_at']))) r];
    final periodStatuses = [for (final r in periodRequests) r['overall_status'] as String? ?? 'unknown'];
    final name = '${citizen?['first_name'] ?? ''} ${citizen?['last_name'] ?? ''}'.trim();

    return ReportData(
      kind: ReportKind.citizen,
      ownerLabel: 'Citizen',
      ownerName: name.isEmpty ? 'You' : name,
      range: range,
      metricGroups: [
        ReportMetricGroup(title: 'My credentials (current)', metrics: [
          ReportMetric(label: 'Credentials held', value: credentials.length, icon: Icons.badge_outlined),
          ReportMetric(
            label: 'Active',
            value: credentialStatuses.where((s) => s == 'active').length,
            icon: Icons.verified_outlined,
          ),
          ReportMetric(
            label: 'Pending',
            value: credentialStatuses.where((s) => s == 'pending').length,
            icon: Icons.hourglass_top_outlined,
          ),
          ReportMetric(
            label: 'Expired, suspended or revoked',
            value: credentialStatuses.where((s) => s == 'expired' || s == 'suspended' || s == 'revoked').length,
            icon: Icons.block_outlined,
          ),
        ]),
        ReportMetricGroup(
          title: 'Verification checks on you in this period',
          metrics: _requestMetrics(periodStatuses, noun: 'Checks'),
        ),
        ReportMetricGroup(title: 'Other activity in this period', metrics: [
          ReportMetric(label: 'Consents granted', value: consents.length, icon: Icons.privacy_tip_outlined),
          ReportMetric(label: 'Appeals on your records', value: appeals.length, icon: Icons.gavel_outlined),
        ]),
      ],
      sections: [
        TableSection(
          title: 'My credentials',
          description: '"Last verified" is the most recent organisation check that matched this credential exactly.',
          headers: const ['Credential', 'Issued by', 'Status', 'Last verified'],
          emptyMessage: 'You do not hold any credentials yet.',
          rows: [
            for (var i = 0; i < credentials.length; i++)
              [
                (credentials[i]['credential_types'] as Map<String, dynamic>?)?['display_name'] as String? ?? 'Credential',
                ((credentials[i]['credential_types'] as Map<String, dynamic>?)?['departments']
                        as Map<String, dynamic>?)?['department_name'] as String? ??
                    '—',
                humaniseStatus(credentialStatuses[i]),
                switch (lastVerified[credentials[i]['credential_type_id']]) {
                  final DateTime d => _shortDate.format(d),
                  null => '—',
                },
              ],
          ],
        ),
        TrendSection(
          title: 'Verification checks over time',
          points: range.trend(periodRequests.map((r) => _date(r['requested_at']))),
        ),
        TableSection(
          title: 'Verification history',
          description: 'Organisations that checked your credentials in this period.',
          headers: const ['Date', 'Organisation', 'Credentials', 'Outcome'],
          rows: [
            for (final r in periodRequests)
              [
                _formatDate(r['requested_at']),
                (r['organisations'] as Map<String, dynamic>?)?['legal_name'] as String? ?? 'Unknown organisation',
                [
                  for (final line in (r['verification_results'] as List? ?? const []))
                    ((line as Map<String, dynamic>)['credential_types'] as Map<String, dynamic>?)?['display_name'] ??
                        'Credential',
                ].join(', '),
                humaniseStatus(r['overall_status'] as String? ?? 'unknown'),
              ],
          ],
        ),
      ],
      notes: const [
        'Only your own records are included.',
        'Citizens do not submit service requests in UbuntuID -- organisations request verification of your '
            'credentials with your consent, so those checks are what this report counts.',
      ],
    );
  }

  static String _formatDate(Object? value) => switch (_date(value)) {
        final DateTime d => _shortDate.format(d),
        null => '—',
      };

  Future<ReportData> build(ReportKind kind, ReportRange range) => switch (kind) {
        ReportKind.system => systemReport(range),
        ReportKind.organisation => organisationReport(range),
        ReportKind.department => departmentReport(range),
        ReportKind.citizen => citizenReport(range),
      };
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return ReportsRepository(ref.watch(supabaseClientProvider), ref.watch(departmentRepositoryProvider));
});

final reportProvider = FutureProvider.autoDispose.family<ReportData, (ReportKind, ReportRange)>((ref, key) {
  return ref.watch(reportsRepositoryProvider).build(key.$1, key.$2);
});
