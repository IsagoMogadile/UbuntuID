/// Mirrors `public.audit_logs`. `actor_id` is polymorphic (its meaning
/// depends on `actor_type`: `department_officials.official_id`,
/// `ubuntuid_administrators.admin_id`, `citizens.citizen_id`, or
/// `organisation_users.organisation_user_id` -- no single FK), so
/// [actorName] is resolved separately, not read directly off the row --
/// see `AdminRepository.streamAuditLogs`.
class AuditLogItem {
  const AuditLogItem({
    required this.logId,
    required this.actorType,
    required this.action,
    required this.relatedTable,
    required this.occurredAt,
    this.actorId,
    this.actorName,
    this.ipAddress,
    this.targetCitizenId,
    this.targetCitizenName,
    this.metadata,
  });

  final String logId;
  final String actorType;
  final String action;
  final String relatedTable;
  final DateTime occurredAt;
  final String? actorId;

  /// The responsible official/administrator/citizen/organisation user's
  /// name, resolved from [actorId] + [actorType] -- null for `actor_type =
  /// 'system'` (most rows: seed data, triggers) or an actor row that no
  /// longer exists.
  final String? actorName;
  final String? ipAddress;

  /// The citizen this event was about (`audit_logs.target_citizen_id`),
  /// resolved to a name the same way [actorName] is -- null when the
  /// affected row has no `citizen_id` column at all (most non-citizen
  /// tables) or that citizen no longer exists.
  final String? targetCitizenId;
  final String? targetCitizenName;

  /// The full row snapshot `fn_audit_log` captured (`to_jsonb(NEW/OLD)`) --
  /// shown as "what changed" in the detail screen since the raw `action`
  /// string alone (e.g. "update_organisations") doesn't say what happened.
  final Map<String, dynamic>? metadata;
}
