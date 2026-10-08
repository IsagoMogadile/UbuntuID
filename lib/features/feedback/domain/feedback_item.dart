/// Mirrors `public.citizen_feedback` -- a citizen's complaint, compliment or
/// suggestion about one department or UbuntuID as a whole (no department).
/// Only administrators see feedback system-wide; a citizen sees their own.
/// See docs/database/citizen_feedback.sql.
class FeedbackItem {
  const FeedbackItem({
    required this.feedbackId,
    required this.feedbackType,
    required this.message,
    required this.status,
    required this.createdAt,
    this.citizenDisplayName,
    this.departmentName,
    this.rating,
    this.adminResponse,
    this.respondedAt,
  });

  final String feedbackId;

  /// 'complaint' | 'compliment' | 'suggestion'.
  final String feedbackType;
  final String message;

  /// 'submitted' | 'acknowledged' | 'under_investigation' | 'resolved'.
  final String status;
  final DateTime createdAt;

  /// Only filled for the administrator's view.
  final String? citizenDisplayName;

  /// Null means the feedback is about UbuntuID in general.
  final String? departmentName;

  /// 1-5, optional.
  final int? rating;
  final String? adminResponse;
  final DateTime? respondedAt;

  String get subjectLabel => departmentName ?? 'UbuntuID (general)';
}

/// The statuses an administrator can move feedback to.
const feedbackAdminStatuses = ['acknowledged', 'under_investigation', 'resolved'];

const feedbackTypes = ['complaint', 'compliment', 'suggestion'];

String feedbackLabel(String value) {
  final words = value.split('_');
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
