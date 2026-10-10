/// A published National Senior Certificate Statement of Results -- the
/// snapshot frozen when a Basic Education official published it
/// (`my_nsc_statements()`, docs/database/nsc_statement_of_results.sql).
class NscStatement {
  const NscStatement({
    required this.statementId,
    required this.matricExamNumber,
    required this.examNumber,
    required this.examYear,
    required this.learnerName,
    required this.passCategory,
    required this.recordReference,
    required this.subjects,
    this.examSession,
    this.schoolName,
    this.publishedAt,
  });

  factory NscStatement.fromJson(Map<String, dynamic> json) {
    return NscStatement(
      statementId: json['statement_id'] as String,
      matricExamNumber: json['matric_exam_number'] as String? ?? json['exam_number'] as String? ?? '',
      examNumber: json['exam_number'] as String? ?? '',
      examYear: (json['exam_year'] as num?)?.toInt() ?? 0,
      examSession: json['exam_session'] as String?,
      schoolName: json['school_name'] as String?,
      learnerName: json['learner_name'] as String? ?? '',
      passCategory: json['pass_category'] as String? ?? '',
      recordReference: json['record_reference'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      subjects: [
        for (final s in (json['subjects'] as List? ?? const []))
          NscSubjectResult.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
    );
  }

  final String statementId;

  /// The `dbe_nsc_results` certificate this statement belongs to.
  final String matricExamNumber;
  final String examNumber;
  final int examYear;
  final String? examSession;
  final String? schoolName;
  final String learnerName;
  final String passCategory;
  final String recordReference;
  final DateTime? publishedAt;
  final List<NscSubjectResult> subjects;

  bool get achieved => passCategory != 'NSC Not Achieved';
}

class NscSubjectResult {
  const NscSubjectResult({required this.subject, this.percentage, this.achievementLevel});

  factory NscSubjectResult.fromJson(Map<String, dynamic> json) {
    return NscSubjectResult(
      subject: json['subject'] as String? ?? json['subject_name'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toDouble(),
      achievementLevel: (json['achievement_level'] as num?)?.toInt(),
    );
  }

  final String subject;
  final double? percentage;
  final int? achievementLevel;

  /// "72%" (or "72.5%"), "—" when missing.
  String get percentageLabel {
    final p = percentage;
    if (p == null) return '—';
    return p == p.roundToDouble() ? '${p.toInt()}%' : '${p.toStringAsFixed(1)}%';
  }
}
