import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/service_providers.dart';
import '../domain/feedback_item.dart';

/// Citizen feedback (Settings > Feedback) and the administrator's review of
/// it. Writes go through the `submit_citizen_feedback` /
/// `admin_update_citizen_feedback` RPCs; RLS limits reads to the citizen's
/// own rows, or every row for an administrator. See
/// docs/database/citizen_feedback.sql.
class FeedbackRepository {
  FeedbackRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'feedback_id, feedback_type, rating, message, status, admin_response, '
      'responded_at, created_at, departments(department_name)';

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

  static FeedbackItem _fromRow(Map<String, dynamic> row, {bool withCitizen = false}) {
    String? citizenName;
    if (withCitizen) {
      final c = row['citizens'] as Map<String, dynamic>?;
      final name = '${c?['first_name'] ?? ''} ${c?['last_name'] ?? ''}'.trim();
      citizenName = name.isEmpty ? 'Unknown citizen' : name;
    }
    return FeedbackItem(
      feedbackId: row['feedback_id'] as String,
      feedbackType: row['feedback_type'] as String? ?? 'suggestion',
      message: row['message'] as String? ?? '',
      status: row['status'] as String? ?? 'submitted',
      createdAt: _date(row['created_at']) ?? DateTime.now(),
      citizenDisplayName: citizenName,
      departmentName: row['departments']?['department_name'] as String?,
      rating: row['rating'] as int?,
      adminResponse: row['admin_response'] as String?,
      respondedAt: _date(row['responded_at']),
    );
  }

  /// Active departments a citizen can direct feedback at.
  Future<List<({String id, String name})>> getDepartments() async {
    final rows = await _client
        .from('departments')
        .select('department_id, department_name')
        .eq('active', true)
        .order('department_name');
    return [
      for (final row in rows) (id: row['department_id'] as String, name: row['department_name'] as String),
    ];
  }

  Future<void> submitFeedback({
    required String feedbackType,
    required String message,
    String? departmentId,
    int? rating,
  }) {
    return _client.rpc('submit_citizen_feedback', params: {
      'p_feedback_type': feedbackType,
      'p_message': message,
      'p_department_id': departmentId,
      'p_rating': rating,
    });
  }

  /// The signed-in citizen's own feedback (RLS scopes it).
  Future<List<FeedbackItem>> getMyFeedback() async {
    final rows = await _client.from('citizen_feedback').select(_columns).order('created_at', ascending: false);
    return [for (final row in rows) _fromRow(row)];
  }

  /// Every citizen's feedback -- administrators only (RLS enforces it).
  Future<List<FeedbackItem>> getAllFeedback() async {
    final rows = await _client
        .from('citizen_feedback')
        .select('$_columns, citizens(first_name, last_name)')
        .order('created_at', ascending: false);
    return [for (final row in rows) _fromRow(row, withCitizen: true)];
  }

  Future<void> updateFeedback({required String feedbackId, required String status, String? response}) {
    return _client.rpc('admin_update_citizen_feedback', params: {
      'p_feedback_id': feedbackId,
      'p_status': status,
      'p_response': response,
    });
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  ref.watch(authStateChangesProvider);
  return FeedbackRepository(ref.watch(supabaseClientProvider));
});

final feedbackDepartmentsProvider = FutureProvider.autoDispose<List<({String id, String name})>>((ref) {
  return ref.watch(feedbackRepositoryProvider).getDepartments();
});

final myFeedbackProvider = FutureProvider.autoDispose<List<FeedbackItem>>((ref) {
  return ref.watch(feedbackRepositoryProvider).getMyFeedback();
});

final adminFeedbackProvider = FutureProvider.autoDispose<List<FeedbackItem>>((ref) {
  return ref.watch(feedbackRepositoryProvider).getAllFeedback();
});
