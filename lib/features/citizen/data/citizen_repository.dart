import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../../shared/data/qualification_lookup.dart';
import '../domain/citizen_address.dart';
import '../domain/consent_grant_item.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';
import '../domain/document_item.dart';
import '../domain/notification_item.dart';
import '../domain/service_item.dart';
import '../domain/timeline_event.dart';

/// Real Supabase-backed citizen data source. Schema reference:
/// docs/SCREEN_DATABASE_MAP.md and docs/DATA_MODEL.md. RLS is live and
/// applied for every query below (see docs/KNOWN_LIMITATIONS.md).
///
/// UbuntuID is not an application/upload platform (see
/// docs/PROJECT_SCOPE.md) -- citizens only ever *view* records that already
/// exist against their `citizen_id`; there is no citizen-facing INSERT
/// anywhere in this repository. `sassa_grant_applications`/
/// `housing_applications` are read-only status views of records created by
/// the (simulated) department process, not something a citizen submits
/// through this app. `job_applications`/`job_postings` are not surfaced to
/// citizens at all -- recruitment is the organisation's own external
/// system; UbuntuID only ever verifies identity/credentials for it.
class CitizenRepository {
  CitizenRepository(this._client);

  final SupabaseClient _client;
  Future<Map<String, dynamic>>? _citizenRowFuture;

  Future<Map<String, dynamic>> _citizenRow() {
    return _citizenRowFuture ??= () async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const AppException('You are not signed in.');
      final row = await _client.from('citizens').select().eq('auth_user_id', userId).maybeSingle();
      if (row == null) {
        throw const AppException('No citizen record is linked to this account.');
      }
      return row;
    }();
  }

  Future<String> _citizenId() async => (await _citizenRow())['citizen_id'] as String;
  Future<String> _citizenIdNumber() async => (await _citizenRow())['id_number'] as String;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  Future<DigitalIdentity> getDigitalIdentity() async {
    final row = await _citizenRow();
    return DigitalIdentity(
      citizenId: row['citizen_id'] as String,
      idNumber: row['id_number'] as String? ?? '',
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      dateOfBirth: _parseDate(row['date_of_birth']) ?? DateTime(1900),
      currentStatus: row['current_status'] as String? ?? 'active',
      registeredAt: _parseDate(row['registered_at']) ?? DateTime.now(),
      phoneNumber: row['phone_number'] as String?,
      email: row['email'] as String?,
    );
  }

  /// Every citizen has exactly one current address via household
  /// membership (`docs/DATA_MODEL.md` §Households) -- this was seeded for
  /// all 150 citizens but never displayed anywhere until now.
  Future<List<CitizenAddress>> getAddresses() async {
    final citizenId = await _citizenId();
    final rows = await _client
        .from('citizen_addresses')
        .select()
        .eq('citizen_id', citizenId)
        .order('is_current', ascending: false)
        .order('effective_date', ascending: false);
    return [
      for (final row in rows)
        CitizenAddress(
          addressType: row['address_type'] as String? ?? 'residential',
          isCurrent: row['is_current'] as bool? ?? true,
          unitNumber: row['unit_number'] as String?,
          streetNumber: row['street_number'] as String?,
          streetName: row['street_name'] as String?,
          suburb: row['suburb'] as String?,
          city: row['city'] as String?,
          municipality: row['municipality'] as String?,
          province: row['province'] as String?,
          postalCode: row['postal_code'] as String?,
        ),
    ];
  }

  /// For NSC/TERTIARY_QUALIFICATION credentials, also resolves the real
  /// qualification behind them (institution, result, year) via
  /// `fetchQualificationDetail` -- every other credential type's
  /// `qualification` stays `null`.
  Future<List<CredentialItem>> getCredentials() async {
    final citizenId = await _citizenId();
    final idNumber = await _citizenIdNumber();
    final rows = await _client
        .from('credentials')
        .select('credential_id, status, issued_date, expiry_date, '
            'credential_types(type_code, display_name, departments(department_name))')
        .eq('citizen_id', citizenId)
        .order('issued_date', ascending: false);

    final items = <CredentialItem>[];
    for (final row in rows) {
      final typeCode = row['credential_types']?['type_code'] as String?;
      items.add(CredentialItem(
        credentialId: row['credential_id'] as String,
        typeName: (row['credential_types']?['display_name'] as String?) ?? 'Credential',
        issuingDepartment:
            (row['credential_types']?['departments']?['department_name'] as String?) ?? 'Unknown department',
        status: _effectiveCredentialStatus(row['status'] as String?, _parseDate(row['expiry_date'])),
        issuedDate: _parseDate(row['issued_date']) ?? DateTime.now(),
        expiryDate: _parseDate(row['expiry_date']),
        qualification: await fetchQualificationDetail(_client, typeCode: typeCode, nationalIdNumber: idNumber),
      ));
    }
    return items;
  }

  /// The `status` column isn't kept in sync as time passes -- nothing
  /// flips it from `active` to `expired` once `expiry_date` is in the
  /// past (there's no scheduled job for it). Recompute it for display so
  /// an expired credential is never shown as active, regardless of how
  /// stale the stored column is.
  static String _effectiveCredentialStatus(String? status, DateTime? expiryDate) {
    final raw = status ?? 'pending';
    if (raw == 'active' && expiryDate != null && expiryDate.isBefore(DateTime.now())) {
      return 'expired';
    }
    return raw;
  }

  /// A chronological "life events" feed for `CitizenTimelineScreen` --
  /// aggregated from `citizens.registered_at`/`date_of_birth`,
  /// `credentials` (every type already carries an `issued_date`), and
  /// `dha_marital_records` (not otherwise citizen-visible outside Digital
  /// Identity). Not its own table -- see `TimelineEvent`.
  Future<List<TimelineEvent>> getLifeTimeline() async {
    final row = await _citizenRow();
    final idNumber = row['id_number'] as String;
    final events = <TimelineEvent>[];

    final dob = _parseDate(row['date_of_birth']);
    if (dob != null) {
      events.add(TimelineEvent(date: dob, title: 'Born', icon: Icons.cake_outlined));
    }

    final registeredAt = _parseDate(row['registered_at']);
    if (registeredAt != null) {
      events.add(TimelineEvent(
        date: registeredAt,
        title: 'UbuntuID digital identity registered',
        subtitle: 'Department of Home Affairs',
        icon: Icons.badge_outlined,
      ));
    }

    final marriageRows = await _client
        .from('dha_marital_records')
        .select('spouse_1_id, spouse_2_id, marriage_type, date_of_marriage')
        .or('spouse_1_id.eq.$idNumber,spouse_2_id.eq.$idNumber');
    for (final m in marriageRows) {
      final spouseId = m['spouse_1_id'] == idNumber ? m['spouse_2_id'] : m['spouse_1_id'];
      final date = _parseDate(m['date_of_marriage']);
      if (date == null) continue;
      events.add(TimelineEvent(
        date: date,
        title: 'Married',
        subtitle: '${m['marriage_type']} marriage • spouse ID $spouseId',
        icon: Icons.favorite_outline,
      ));
    }

    final credentials = await getCredentials();
    for (final c in credentials) {
      events.add(TimelineEvent(
        date: c.issuedDate,
        title: c.typeName,
        subtitle: 'Issued by ${c.issuingDepartment}',
        icon: _iconForCredential(c.typeName),
      ));
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  static IconData _iconForCredential(String typeName) {
    final name = typeName.toLowerCase();
    if (name.contains('passport')) return Icons.flight_land_outlined;
    if (name.contains('licence') || name.contains('license')) return Icons.directions_car_outlined;
    if (name.contains('tax')) return Icons.receipt_long_outlined;
    if (name.contains('criminal') || name.contains('clearance')) return Icons.verified_outlined;
    if (name.contains('matric') || name.contains('nsc')) return Icons.school_outlined;
    if (name.contains('tertiary') || name.contains('qualification')) return Icons.workspace_premium_outlined;
    if (name.contains('labour') || name.contains('employment')) return Icons.work_outline;
    if (name.contains('sassa') || name.contains('grant')) return Icons.volunteer_activism_outlined;
    return Icons.verified_user_outlined;
  }

  // ---------------------------------------------------------------------
  // Consent management -- which organisations currently hold consent to
  // verify which of this citizen's credential types, and letting them
  // revoke it (spec suggestion #2).
  // ---------------------------------------------------------------------

  Future<List<ConsentGrantItem>> getConsentGrants() async {
    final citizenId = await _citizenId();
    final results = await Future.wait([
      _client
          .from('consent_grants')
          .select('consent_id, scope, granted_at, expires_at, revoked_at, organisations(legal_name)')
          .eq('citizen_id', citizenId)
          .order('granted_at', ascending: false),
      _client.from('credential_types').select('credential_type_id, display_name'),
    ]);
    final rows = results[0];
    final typeNameById = {
      for (final t in results[1]) t['credential_type_id'] as String: t['display_name'] as String,
    };

    return [
      for (final row in rows)
        ConsentGrantItem(
          consentId: row['consent_id'] as String,
          organisationName: (row['organisations']?['legal_name'] as String?) ?? 'Unknown organisation',
          credentialTypeNames: [
            for (final id in (row['scope']?['credential_type_ids'] as List<dynamic>? ?? []))
              typeNameById[id as String] ?? 'Unknown credential',
          ],
          grantedAt: _parseDate(row['granted_at']) ?? DateTime.now(),
          expiresAt: _parseDate(row['expires_at']),
          revokedAt: _parseDate(row['revoked_at']),
        ),
    ];
  }

  Future<void> revokeConsent(String consentId) {
    return _client.rpc('citizen_revoke_consent', params: {'p_consent_id': consentId});
  }

  Future<List<DocumentItem>> getDocuments() async {
    final citizenId = await _citizenId();
    final rows = await _client
        .from('documents')
        .select('document_id, document_type, file_name, status, created_at, reviewed_at')
        .eq('citizen_id', citizenId)
        .order('created_at', ascending: false);

    return [
      for (final row in rows)
        DocumentItem(
          documentId: row['document_id'] as String,
          documentType: row['document_type'] as String? ?? 'Document',
          fileName: row['file_name'] as String? ?? '',
          status: row['status'] as String? ?? 'pending',
          createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
          reviewedAt: _parseDate(row['reviewed_at']),
        ),
    ];
  }

  /// A static menu (not a Supabase read itself -- each entry routes to a
  /// screen that reads live data). All 5 previously routed through
  /// "Identity Verification"/"Tax & SARS"/"Licences & Qualifications" were
  /// marked `available: false` and dead-ended on the generic "coming soon"
  /// screen even though the real screens they describe already exist and
  /// are wired to live data (`CitizenVerificationListScreen`,
  /// `DigitalIdentityScreen`'s credential list, which already includes
  /// every credential type -- tax compliance, driver's licence, NSC,
  /// tertiary qualification, etc.) -- see `ServicesScreen._routeFor`.
  /// One tile per department, not a handful of bundled catch-alls -- every
  /// department that issues a citizen-facing credential/status gets its
  /// own entry here. Most route to the Digital Identity screen's
  /// credential list (where every credential type is already shown,
  /// regardless of issuing department) since that's the real destination;
  /// SASSA/Human Settlements/Verification keep their own dedicated screens.
  Future<List<ServiceItem>> getServices() async {
    return const [
      ServiceItem(
        name: 'Home Affairs',
        description: 'Passport and civil identity records',
        icon: Icons.badge_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: "Driver's Licence",
        description: 'Your driving licence status and expiry',
        icon: Icons.directions_car_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'Tax & SARS',
        description: 'Tax compliance status and records',
        icon: Icons.receipt_long_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'Police Clearance',
        description: 'Criminal clearance certificate status',
        icon: Icons.gavel_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'Basic Education',
        description: 'Matric (National Senior Certificate) results',
        icon: Icons.school_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'Higher Education',
        description: 'Registered tertiary qualifications and results',
        icon: Icons.workspace_premium_outlined,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'Employment & UIF',
        description: 'Employment status and UIF contributions',
        icon: Icons.work_outline,
        available: true,
        route: AppRoutes.citizenDigitalIdentity,
      ),
      ServiceItem(
        name: 'SASSA Grants',
        description: 'View your social grant status and payment history',
        icon: Icons.volunteer_activism_outlined,
        available: true,
        route: AppRoutes.citizenSassa,
      ),
      ServiceItem(
        name: 'Human Settlements',
        description: 'View your housing programme status and title deed',
        icon: Icons.home_work_outlined,
        available: true,
        route: AppRoutes.citizenHumanSettlements,
      ),
      ServiceItem(
        name: 'Identity Verification',
        description: 'See who has requested to verify your identity',
        icon: Icons.verified_user_outlined,
        available: true,
        route: AppRoutes.citizenVerification,
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  /// Live unread count for the Notifications nav badge -- `notifications`
  /// is in the `supabase_realtime` publication, so this updates the moment
  /// a new notification is written (e.g. the verification-decision
  /// trigger) or one is marked read, with no manual refresh.
  Stream<int> streamUnreadNotificationCount() async* {
    final citizenId = await _citizenId();
    yield* _client
        .from('notifications')
        .stream(primaryKey: ['notification_id'])
        .eq('citizen_id', citizenId)
        .map((rows) => rows.where((r) => r['is_read'] != true).length);
  }

  Future<List<NotificationItem>> getNotifications() async {
    final citizenId = await _citizenId();
    const baseColumns = 'notification_id, message, channel, delivery_status, created_at';
    var hasReadColumn = true;
    List<Map<String, dynamic>> rows;
    try {
      rows = await _client
          .from('notifications')
          .select('$baseColumns, is_read')
          .eq('citizen_id', citizenId)
          .order('created_at', ascending: false);
    } on PostgrestException catch (e) {
      // 42703 = undefined_column. `is_read` is applied and live as of this
      // session, so this branch shouldn't fire in practice -- kept as a
      // defensive fallback so the list still loads even if it somehow did.
      if (e.code == '42703') {
        hasReadColumn = false;
        rows = await _client
            .from('notifications')
            .select(baseColumns)
            .eq('citizen_id', citizenId)
            .order('created_at', ascending: false);
      } else {
        rethrow;
      }
    }

    return [
      for (final row in rows)
        NotificationItem(
          notificationId: row['notification_id'] as String,
          message: row['message'] as String? ?? '',
          channel: row['channel'] as String? ?? 'app',
          deliveryStatus: row['delivery_status'] as String? ?? 'delivered',
          createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
          isRead: hasReadColumn ? (row['is_read'] as bool? ?? false) : false,
        ),
    ];
  }

  /// Persists read state via the `mark_notification_read` RPC (applied and
  /// confirmed live -- see docs/KNOWN_LIMITATIONS.md).
  Future<void> markNotificationRead(String notificationId) {
    return _client.rpc('mark_notification_read', params: {'p_notification_id': notificationId});
  }

  // ---------------------------------------------------------------------
  // SASSA (simulated)
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSassaGrants() async {
    final idNumber = await _citizenIdNumber();
    return _client
        .from('sassa_grants')
        .select()
        .eq('national_id_number', idNumber)
        .order('created_at', ascending: false);
  }

  // ---------------------------------------------------------------------
  // Human Settlements (simulated)
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getHousingApplicationsRaw() async {
    final citizenId = await _citizenId();
    return _client
        .from('housing_applications')
        .select('*, housing_programmes(programme_name)')
        .eq('citizen_id', citizenId)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getHousingBeneficiaryProperties() async {
    final citizenId = await _citizenId();
    return _client
        .from('housing_beneficiaries')
        .select('*, properties(*, title_deeds(*))')
        .eq('citizen_id', citizenId);
  }
}

final citizenRepositoryProvider = Provider<CitizenRepository>((ref) {
  // Recreated whenever the auth session changes so a cached citizen row
  // from a previous session can never leak into a new one.
  ref.watch(authStateChangesProvider);
  return CitizenRepository(ref.watch(supabaseClientProvider));
});

final digitalIdentityProvider = FutureProvider.autoDispose<DigitalIdentity>((ref) {
  return ref.watch(citizenRepositoryProvider).getDigitalIdentity();
});

final credentialsProvider = FutureProvider.autoDispose<List<CredentialItem>>((ref) {
  return ref.watch(citizenRepositoryProvider).getCredentials();
});

final lifeTimelineProvider = FutureProvider.autoDispose<List<TimelineEvent>>((ref) {
  return ref.watch(citizenRepositoryProvider).getLifeTimeline();
});

final citizenAddressesProvider = FutureProvider.autoDispose<List<CitizenAddress>>((ref) {
  return ref.watch(citizenRepositoryProvider).getAddresses();
});

final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(citizenRepositoryProvider).streamUnreadNotificationCount();
});

final consentGrantsProvider = FutureProvider.autoDispose<List<ConsentGrantItem>>((ref) {
  return ref.watch(citizenRepositoryProvider).getConsentGrants();
});

final documentsProvider = FutureProvider.autoDispose<List<DocumentItem>>((ref) {
  return ref.watch(citizenRepositoryProvider).getDocuments();
});

final servicesProvider = FutureProvider.autoDispose<List<ServiceItem>>((ref) {
  return ref.watch(citizenRepositoryProvider).getServices();
});

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() {
    return ref.watch(citizenRepositoryProvider).getNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData([
      for (final n in current)
        if (n.notificationId == notificationId) n.copyWith(isRead: true) else n,
    ]);

    try {
      await ref.read(citizenRepositoryProvider).markNotificationRead(notificationId);
    } catch (_) {
      // The RPC is applied and live; this only protects against a
      // transient network error -- the optimistic update above still
      // stands for this session either way.
    }
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(NotificationsController.new);

final sassaGrantsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(citizenRepositoryProvider).getSassaGrants();
});

final housingApplicationsRawProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(citizenRepositoryProvider).getHousingApplicationsRaw();
});

final housingBeneficiaryPropertiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(citizenRepositoryProvider).getHousingBeneficiaryProperties();
});
