import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../services/service_providers.dart';

/// Basic Education's Examination Results: synchronised NSC results, their
/// calculated pass categories and publication. Reads go through RLS (DBE
/// officials and administrators only); synchronise, publish and review are
/// security-definer RPCs that re-check the caller is an active DBE official
/// (docs/database/nsc_statement_of_results.sql). Officials can't edit marks
/// or categories -- those only ever come from the results source.
class ExamResultsRepository {
  ExamResultsRepository(this._client);

  final SupabaseClient _client;

  Future<ExamResultsSummary> getSummary() async {
    final (rows, lastRun) = await (
      _client.from('dbe_nsc_statements').select('publication_status'),
      _client
          .from('dbe_results_sync_runs')
          .select('finished_at')
          .eq('status', 'completed')
          .order('finished_at', ascending: false)
          .limit(1)
          .maybeSingle(),
    ).wait;
    int count(String status) => rows.where((r) => r['publication_status'] == status).length;
    return ExamResultsSummary(
      total: rows.length,
      published: count('published'),
      unpublished: count('unpublished'),
      requiresReview: count('requires_review'),
      lastSynchronisedAt: DateTime.tryParse(lastRun?['finished_at'] as String? ?? '')?.toLocal(),
    );
  }

  Future<List<ExamResultRecord>> getRecords() async {
    final rows = await _client
        .from('dbe_nsc_statements')
        .select()
        .order('exam_year', ascending: false)
        .order('learner_name');
    return [for (final row in rows) ExamResultRecord.fromJson(row)];
  }

  Future<ExamResultRecord?> getRecord(String statementId) async {
    final row = await _client
        .from('dbe_nsc_statements')
        .select('*, dbe_nsc_statement_subjects(subject_name, percentage, achievement_level, sort_order)')
        .eq('statement_id', statementId)
        .maybeSingle();
    return row == null ? null : ExamResultRecord.fromJson(row);
  }

  Future<SyncOutcome> synchronise() async {
    final result = Map<String, dynamic>.from(await _client.rpc('sync_nsc_results') as Map);
    if (result['status'] != 'completed') {
      throw const AppException('Synchronisation was unsuccessful. No examination records were changed.');
    }
    return SyncOutcome.fromJson(result);
  }

  /// Publishes [statementIds], or every record ready for publication when
  /// null. Returns (published, skipped).
  Future<(int, int)> publish({List<String>? statementIds}) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc('publish_nsc_results', params: {'p_statement_ids': statementIds}) as Map,
    );
    return ((result['published'] as num?)?.toInt() ?? 0, (result['skipped'] as num?)?.toInt() ?? 0);
  }

  Future<void> confirmReview(String statementId) async {
    await _client.rpc('confirm_nsc_statement_review', params: {'p_statement_id': statementId});
  }
}

class ExamResultsSummary {
  const ExamResultsSummary({
    required this.total,
    required this.published,
    required this.unpublished,
    required this.requiresReview,
    this.lastSynchronisedAt,
  });

  final int total;
  final int published;
  final int unpublished;
  final int requiresReview;
  final DateTime? lastSynchronisedAt;
}

class SyncOutcome {
  const SyncOutcome({
    required this.received,
    required this.imported,
    required this.updated,
    required this.unchanged,
    required this.requiringReview,
  });

  factory SyncOutcome.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SyncOutcome(
      received: n('received'),
      imported: n('imported'),
      updated: n('updated'),
      unchanged: n('unchanged'),
      requiringReview: n('requiring_review'),
    );
  }

  final int received;
  final int imported;
  final int updated;
  final int unchanged;
  final int requiringReview;
}

enum PublicationStatus {
  unpublished('Unpublished'),
  published('Published'),
  requiresReview('Requires Review');

  const PublicationStatus(this.label);

  final String label;

  static PublicationStatus parse(String? value) => switch (value) {
        'published' => published,
        'requires_review' => requiresReview,
        _ => unpublished,
      };
}

class ExamResultRecord {
  const ExamResultRecord({
    required this.statementId,
    required this.examNumber,
    required this.examYear,
    required this.learnerName,
    required this.status,
    required this.reviewReasons,
    required this.changedAfterPublication,
    required this.citizenMatched,
    required this.recordReference,
    required this.subjects,
    required this.checks,
    this.calculatedPassCategory,
    this.officialPassCategory,
    this.schoolName,
    this.examSession,
    this.publishedAt,
    this.lastSyncedAt,
  });

  factory ExamResultRecord.fromJson(Map<String, dynamic> json) {
    final evaluation = json['evaluation'] as Map<String, dynamic>?;
    final subjectRows = [
      for (final s in (json['dbe_nsc_statement_subjects'] as List? ?? const []))
        Map<String, dynamic>.from(s as Map),
    ]..sort((a, b) => ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));

    return ExamResultRecord(
      statementId: json['statement_id'] as String,
      examNumber: json['exam_number'] as String? ?? '',
      examYear: (json['exam_year'] as num?)?.toInt() ?? 0,
      learnerName: json['learner_name'] as String? ?? 'Unknown learner',
      status: PublicationStatus.parse(json['publication_status'] as String?),
      reviewReasons: [for (final r in (json['review_reasons'] as List? ?? const [])) r.toString()],
      changedAfterPublication: json['changed_after_publication'] == true,
      citizenMatched: json['citizen_id'] != null,
      recordReference: json['record_reference'] as String? ?? '',
      calculatedPassCategory: json['calculated_pass_category'] as String?,
      officialPassCategory: json['official_pass_category'] as String?,
      schoolName: json['school_name'] as String?,
      examSession: json['exam_session'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '')?.toLocal(),
      lastSyncedAt: DateTime.tryParse(json['last_synced_at'] as String? ?? '')?.toLocal(),
      subjects: [
        for (final s in subjectRows)
          (
            subject: s['subject_name'] as String? ?? '',
            percentage: (s['percentage'] as num?)?.toDouble(),
            level: (s['achievement_level'] as num?)?.toInt(),
          ),
      ],
      checks: [
        for (final c in (evaluation?['checks'] as List? ?? const []))
          (requirement: (c as Map)['requirement']?.toString() ?? '', met: c['met'] == true),
      ],
    );
  }

  final String statementId;
  final String examNumber;
  final int examYear;
  final String learnerName;
  final PublicationStatus status;
  final List<String> reviewReasons;
  final bool changedAfterPublication;
  final bool citizenMatched;
  final String recordReference;
  final String? calculatedPassCategory;
  final String? officialPassCategory;
  final String? schoolName;
  final String? examSession;
  final DateTime? publishedAt;
  final DateTime? lastSyncedAt;

  /// Only filled by [ExamResultsRepository.getRecord].
  final List<({String subject, double? percentage, int? level})> subjects;

  /// Requirement-by-requirement explanation of the calculated category.
  final List<({String requirement, bool met})> checks;

  bool get hasDiscrepancy => reviewReasons.any((r) => r.startsWith('Discrepancy'));

  /// Meets every publication check (the server re-checks on publish).
  bool get readyToPublish =>
      status == PublicationStatus.unpublished &&
      citizenMatched &&
      calculatedPassCategory != null &&
      calculatedPassCategory == officialPassCategory;
}

final examResultsRepositoryProvider = Provider<ExamResultsRepository>((ref) {
  return ExamResultsRepository(ref.watch(supabaseClientProvider));
});

final examResultsSummaryProvider = FutureProvider.autoDispose<ExamResultsSummary>((ref) {
  return ref.watch(examResultsRepositoryProvider).getSummary();
});

final examResultsProvider = FutureProvider.autoDispose<List<ExamResultRecord>>((ref) {
  return ref.watch(examResultsRepositoryProvider).getRecords();
});

final examResultDetailProvider = FutureProvider.autoDispose.family<ExamResultRecord?, String>((ref, id) {
  return ref.watch(examResultsRepositoryProvider).getRecord(id);
});
