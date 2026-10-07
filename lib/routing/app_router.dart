import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/role_navigation_shell.dart';
import '../models/user_role.dart';
import '../features/admin/presentation/admin_citizen_search_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/admin/presentation/admin_profile_screen.dart';
import '../features/admin/presentation/admin_verification_queue_screen.dart';
import '../features/admin/presentation/audit_log_detail_screen.dart';
import '../features/admin/presentation/audit_logs_list_screen.dart';
import '../features/admin/presentation/compliance_audits_list_screen.dart';
import '../features/admin/presentation/admin_analytics_screen.dart';
import '../features/admin/presentation/household_records_list_screen.dart';
import '../features/admin/domain/user_list_item.dart';
import '../features/admin/presentation/department_detail_screen.dart';
import '../features/admin/presentation/department_form_screen.dart';
import '../features/admin/presentation/department_official_form_screen.dart';
import '../features/admin/presentation/departments_list_screen.dart';
import '../features/admin/presentation/appeal_detail_screen.dart';
import '../features/admin/presentation/appeals_list_screen.dart';
import '../features/admin/presentation/flagged_record_detail_screen.dart';
import '../features/admin/presentation/flagged_records_list_screen.dart';
import '../features/admin/presentation/organisation_detail_screen.dart';
import '../features/admin/presentation/organisations_list_screen.dart';
import '../features/admin/presentation/user_detail_screen.dart';
import '../features/admin/presentation/users_list_screen.dart';
import '../features/auth/application/logout.dart';
import '../features/auth/presentation/account_not_configured_screen.dart';
import '../features/auth/presentation/account_revoked_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/citizen/data/citizen_repository.dart';
import '../features/citizen/presentation/citizen_dashboard_screen.dart';
import '../features/citizen/presentation/citizen_verification_list_screen.dart';
import '../features/citizen/presentation/consent_management_screen.dart';
import '../features/citizen/presentation/citizen_timeline_screen.dart';
import '../features/citizen/presentation/my_appeals_screen.dart';
import '../features/citizen/presentation/my_employment_screen.dart';
import '../features/citizen/presentation/digital_id_card_screen.dart';
import '../features/citizen/presentation/digital_identity_screen.dart';
import '../features/citizen/presentation/document_detail_screen.dart';
import '../features/citizen/presentation/document_wallet_screen.dart';
import '../features/citizen/presentation/documents_list_screen.dart';
import '../features/citizen/presentation/human_settlements_screen.dart';
import '../features/citizen/presentation/notification_detail_screen.dart';
import '../features/citizen/presentation/notifications_list_screen.dart';
import '../features/citizen/presentation/personal_information_screen.dart';
import '../features/citizen/presentation/profile_overview_screen.dart';
import '../features/citizen/presentation/sassa_screen.dart';
import '../features/citizen/presentation/services_screen.dart';
import '../features/department_official/presentation/department_citizen_records_screen.dart';
import '../features/department_official/presentation/department_citizen_search_screen.dart';
import '../features/department_official/presentation/department_colleagues_screen.dart';
import '../features/department_official/presentation/department_dashboard_screen.dart';
import '../features/department_official/presentation/department_profile_screen.dart';
import '../features/department_official/presentation/department_services_screen.dart';
import '../features/department_official/presentation/edit_citizen_screen.dart';
import '../features/department_official/presentation/register_citizen_screen.dart';
import '../features/department_official/presentation/saps_clearance_search_screen.dart';
import '../features/department_official/presentation/saps_offenders_screen.dart';
import '../features/department_official/presentation/saps_wanted_persons_screen.dart';
import '../features/organisation/presentation/citizen_search_screen.dart';
import '../features/organisation/presentation/organisation_colleagues_screen.dart';
import '../features/organisation/presentation/organisation_dashboard_screen.dart';
import '../features/organisation/presentation/organisation_profile_screen.dart';
import '../features/organisation/presentation/organisation_registration_screen.dart';
import '../features/organisation/presentation/organisation_verification_list_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/account_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/appearance_settings_screen.dart';
import '../features/settings/presentation/privacy_settings_screen.dart';
import '../features/settings/presentation/security_settings_screen.dart';
import '../features/settings/presentation/settings_home_screen.dart';
import '../features/shared/presentation/coming_soon_screen.dart';
import '../features/shared/presentation/header_citizen_search.dart';
import '../features/shared/presentation/no_internet_screen.dart';
import '../features/shared/presentation/not_found_screen.dart';
import '../features/shared/presentation/unauthorized_screen.dart';
import '../features/verification/presentation/verification_request_detail_screen.dart';
import '../services/service_providers.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

const _protectedPrefixes = [
  AppRoutes.citizenDashboard,
  AppRoutes.departmentDashboard,
  AppRoutes.organisationDashboard,
  AppRoutes.adminDashboard,
  AppRoutes.settings,
];

/// Maps each role-specific area to the one role allowed in it. Used to stop
/// a signed-in user from reaching another role's dashboard by typing its URL
/// directly -- RLS still governs what data those screens can actually read,
/// this just stops the navigation itself.
const _roleAreaPrefixes = {
  AppRoutes.citizenDashboard: UserRole.citizen,
  AppRoutes.departmentDashboard: UserRole.departmentOfficial,
  AppRoutes.organisationDashboard: UserRole.organisationUser,
  AppRoutes.adminDashboard: UserRole.administrator,
};

/// Notifies go_router's [GoRouter.refreshListenable] whenever Supabase's
/// auth state changes, so the `redirect` guard below is re-evaluated on
/// login/logout without recreating the whole router.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Maps the `?role=` query param a dashboard stat card's "50 citizens" tap
/// sends (e.g. `AppRoutes.adminUsers + '?role=citizen'`) to the matching
/// filter, so the Users screen opens pre-filtered instead of showing every
/// role mixed together.
AdminUserRole? _roleFilterFromQuery(GoRouterState state) {
  return switch (state.uri.queryParameters['role']) {
    'citizen' => AdminUserRole.citizen,
    'departmentOfficial' => AdminUserRole.departmentOfficial,
    'organisationUser' => AdminUserRole.organisationUser,
    'administrator' => AdminUserRole.administrator,
    _ => null,
  };
}

Future<String?> _resolveRoleAreaRedirect(Ref ref, UserRole requiredRole) async {
  // `currentRoleProvider` only recomputes when the auth stream fires, and it
  // is a separate stream subscriber from this router's own refreshListenable
  // -- there's no guaranteed ordering between the two. Switching accounts
  // within the same tab (sign out of a citizen, sign in as an official) can
  // therefore hit this redirect before the provider has re-resolved, handing
  // back the *previous* account's cached role and sending every non-citizen
  // login to /unauthorized. Force a fresh lookup against the current session
  // instead of trusting whatever is currently cached.
  ref.invalidate(currentRoleProvider);
  final roleResult = await ref.read(currentRoleProvider.future);
  if (roleResult == null) return AppRoutes.accountNotConfigured;
  if (roleResult.role != requiredRole) return AppRoutes.unauthorized;

  // Re-checked on every navigation within a role area (this function
  // already runs per-navigation for the role-match check above) -- this is
  // the "block on next action" enforcement for a revoked organisation/
  // deactivated official: no real-time listener, just piggybacking on the
  // guard that already runs here. An already-open session keeps working
  // until its next navigation, at which point it's signed out.
  final blockedReason = await ref.read(roleServiceProvider).checkAccountActive(roleResult);
  if (blockedReason != null) {
    await ref.read(authServiceProvider).signOut();
    return '${AppRoutes.accountRevoked}?reason=${Uri.encodeComponent(blockedReason)}';
  }

  return null;
}

/// Every role's navigation ends Profile -> Settings -> Log Out. Settings is
/// its own tab in each role's shell (the shared [SettingsHomeScreen], minus
/// its own Log out row since the shell has one); Log Out is an action, not a
/// branch, so it must stay the last destination.
const _settingsDestination =
    AppNavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings');

AppNavDestination _logOutDestination(WidgetRef ref) => AppNavDestination(
      icon: Icons.logout,
      selectedIcon: Icons.logout,
      label: 'Log Out',
      onSelected: (context) => confirmAndLogOut(context, ref),
    );

StatefulShellBranch _settingsBranch(String path) => StatefulShellBranch(routes: [
      GoRoute(path: path, builder: (c, s) => const SettingsHomeScreen(showLogout: false)),
    ]);

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final refreshStream = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshStream,
    // Deliberately not `async`: most navigations (unauthenticated, or to a
    // non-role-scoped route like settings) resolve synchronously below, so
    // go_router can redirect within the same frame -- only the role-area
    // branch needs to await a database lookup.
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final isProtected = _protectedPrefixes.any((p) => state.matchedLocation.startsWith(p));
      if (!loggedIn && isProtected) return AppRoutes.login;
      if (!loggedIn) return null;

      MapEntry<String, UserRole>? roleAreaEntry;
      for (final entry in _roleAreaPrefixes.entries) {
        if (state.matchedLocation.startsWith(entry.key)) {
          roleAreaEntry = entry;
          break;
        }
      }
      if (roleAreaEntry == null) return null;

      return _resolveRoleAreaRedirect(ref, roleAreaEntry.value);
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // --- Auth ---
      GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterScreen()),
      GoRoute(path: AppRoutes.registerOrganisation, builder: (c, s) => const OrganisationRegistrationScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.resetPassword, builder: (c, s) => const ResetPasswordScreen()),
      GoRoute(
        path: AppRoutes.accountNotConfigured,
        builder: (c, s) => const AccountNotConfiguredScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountRevoked,
        builder: (c, s) => AccountRevokedScreen(reason: s.uri.queryParameters['reason']),
      ),

      // --- Shared ---
      GoRoute(path: AppRoutes.unauthorized, builder: (c, s) => const UnauthorizedScreen()),
      GoRoute(path: AppRoutes.noInternet, builder: (c, s) => const NoInternetScreen()),
      GoRoute(path: AppRoutes.notFound, builder: (c, s) => const NotFoundScreen()),
      GoRoute(
        path: AppRoutes.comingSoon,
        builder: (c, s) => ComingSoonScreen(featureName: s.uri.queryParameters['feature']),
      ),

      // --- Settings (shared across roles) ---
      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsHomeScreen()),
      GoRoute(path: AppRoutes.settingsAccount, builder: (c, s) => const AccountSettingsScreen()),
      GoRoute(path: AppRoutes.settingsSecurity, builder: (c, s) => const SecuritySettingsScreen()),
      GoRoute(
        path: AppRoutes.settingsNotifications,
        builder: (c, s) => const NotificationSettingsScreen(),
      ),
      GoRoute(path: AppRoutes.settingsPrivacy, builder: (c, s) => const PrivacySettingsScreen()),
      GoRoute(path: AppRoutes.settingsAppearance, builder: (c, s) => const AppearanceSettingsScreen()),
      GoRoute(path: AppRoutes.settingsAbout, builder: (c, s) => const AboutScreen()),

      // --- Citizen ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
            return RoleNavigationShell(
              navigationShell: navigationShell,
              title: 'UbuntuID',
              destinations: [
                const AppNavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
                const AppNavDestination(icon: Icons.apps_outlined, selectedIcon: Icons.apps, label: 'Services'),
                AppNavDestination(
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications,
                  label: 'Notifications',
                  badgeCount: unread,
                ),
                const AppNavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
                _settingsDestination,
                _logOutDestination(ref),
              ],
            );
          },
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.citizenDashboard, builder: (c, s) => const CitizenDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.citizenServices, builder: (c, s) => const ServicesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.citizenNotifications, builder: (c, s) => const NotificationsListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.citizenProfile, builder: (c, s) => const ProfileOverviewScreen()),
          ]),
          _settingsBranch(AppRoutes.citizenSettings),
        ],
      ),

      // Citizen detail/sub screens: deliberately top-level (siblings of the
      // shell above, not nested branch routes) so they push full-screen on
      // the root navigator instead of staying inside the tab chrome --
      // go_router only allows a branch route's parentNavigatorKey to match
      // its own branch, never escape to the root navigator.
      GoRoute(
        path: AppRoutes.citizenDigitalIdentity,
        builder: (c, s) => DigitalIdentityScreen(
          filterTypeCode: s.uri.queryParameters['type'],
          title: s.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: AppRoutes.citizenDocuments,
        builder: (c, s) => const DocumentsListScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.citizenDocuments}/:id',
        builder: (c, s) => DocumentDetailScreen(documentId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.citizenNotifications}/:id',
        builder: (c, s) => NotificationDetailScreen(notificationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.citizenPersonalInformation,
        builder: (c, s) => const PersonalInformationScreen(),
      ),
      GoRoute(path: AppRoutes.citizenSassa, builder: (c, s) => const SassaScreen()),
      GoRoute(
        path: AppRoutes.citizenHumanSettlements,
        builder: (c, s) => const HumanSettlementsScreen(),
      ),
      GoRoute(path: AppRoutes.citizenVerification, builder: (c, s) => const CitizenVerificationListScreen()),
      GoRoute(path: AppRoutes.citizenConsent, builder: (c, s) => const ConsentManagementScreen()),
      GoRoute(path: AppRoutes.citizenDigitalIdCard, builder: (c, s) => const DigitalIdCardScreen()),
      GoRoute(path: AppRoutes.citizenDocumentWallet, builder: (c, s) => const DocumentWalletScreen()),
      GoRoute(path: AppRoutes.citizenTimeline, builder: (c, s) => const CitizenTimelineScreen()),
      GoRoute(path: AppRoutes.citizenEmployment, builder: (c, s) => const MyEmploymentScreen()),
      GoRoute(
        path: '${AppRoutes.citizenVerification}/:id',
        builder: (c, s) => VerificationRequestDetailScreen(requestId: s.pathParameters['id']!),
      ),

      // --- Department official ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) => RoleNavigationShell(
            navigationShell: navigationShell,
            title: 'UbuntuID',
            destinations: [
              const AppNavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
              const AppNavDestination(icon: Icons.apps_outlined, selectedIcon: Icons.apps, label: 'Services'),
              const AppNavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
              _settingsDestination,
              _logOutDestination(ref),
            ],
            appBarActions: const [HeaderCitizenSearch(searchRoute: AppRoutes.departmentCitizenSearch)],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.departmentDashboard, builder: (c, s) => const DepartmentDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.departmentServices, builder: (c, s) => const DepartmentServicesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.departmentProfile, builder: (c, s) => const DepartmentProfileScreen()),
          ]),
          _settingsBranch(AppRoutes.departmentSettings),
        ],
      ),
      // Reached from Services, not a bottom-nav tab --
      // visible only to Home Affairs officials (see
      // DepartmentDashboardScreen / RegisterCitizenScreen).
      GoRoute(path: AppRoutes.departmentRegisterCitizen, builder: (c, s) => const RegisterCitizenScreen()),
      // Visible only to SAPS officials.
      GoRoute(path: AppRoutes.departmentClearanceSearch, builder: (c, s) => const SapsClearanceSearchScreen()),
      // Reached from the header search field, for every department official
      // regardless of category. `?id=` pre-fills and runs the search.
      GoRoute(
        path: AppRoutes.departmentCitizenSearch,
        builder: (c, s) => DepartmentCitizenSearchScreen(initialIdNumber: s.uri.queryParameters['id']),
      ),
      GoRoute(path: AppRoutes.departmentCitizenRecords, builder: (c, s) => const DepartmentCitizenRecordsScreen()),
      GoRoute(path: AppRoutes.departmentColleagues, builder: (c, s) => const DepartmentColleaguesScreen()),
      // Visible only to Home Affairs officials.
      GoRoute(
        path: '${AppRoutes.departmentEditCitizen}/:id/edit',
        builder: (c, s) => EditCitizenScreen(citizenId: s.pathParameters['id']!),
      ),
      // Visible only to SAPS officials.
      GoRoute(path: AppRoutes.departmentSapsWanted, builder: (c, s) => const SapsWantedPersonsScreen()),
      GoRoute(path: AppRoutes.departmentSapsOffenders, builder: (c, s) => const SapsOffendersScreen()),

      // --- Organisation ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) => RoleNavigationShell(
            navigationShell: navigationShell,
            title: 'UbuntuID',
            destinations: [
              const AppNavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
              const AppNavDestination(
                icon: Icons.person_add_alt_outlined,
                selectedIcon: Icons.person_add_alt,
                label: 'New Applicant',
              ),
              const AppNavDestination(icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: 'Applicants'),
              const AppNavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
              _settingsDestination,
              _logOutDestination(ref),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.organisationDashboard, builder: (c, s) => const OrganisationDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.organisationSearch, builder: (c, s) => const CitizenSearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.organisationVerification,
              builder: (c, s) => const OrganisationVerificationListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.organisationProfile, builder: (c, s) => const OrganisationProfileScreen()),
          ]),
          _settingsBranch(AppRoutes.organisationSettings),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.organisationVerification}/:id',
        builder: (c, s) => VerificationRequestDetailScreen(requestId: s.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.organisationColleagues, builder: (c, s) => const OrganisationColleaguesScreen()),

      // --- Administrator ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Consumer(
          builder: (context, ref, _) => RoleNavigationShell(
            navigationShell: navigationShell,
            title: 'UbuntuID',
            destinations: [
              const AppNavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
              const AppNavDestination(icon: Icons.group_outlined, selectedIcon: Icons.group, label: 'Users'),
              const AppNavDestination(icon: Icons.apartment_outlined, selectedIcon: Icons.apartment, label: 'Organisations'),
              const AppNavDestination(
                icon: Icons.account_balance_outlined,
                selectedIcon: Icons.account_balance,
                label: 'Departments',
              ),
              const AppNavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Audit'),
              const AppNavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
              _settingsDestination,
              _logOutDestination(ref),
            ],
            appBarActions: const [HeaderCitizenSearch(searchRoute: AppRoutes.adminCitizenSearch)],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.adminDashboard, builder: (c, s) => const AdminDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.adminUsers,
              builder: (c, s) => UsersListScreen(initialRoleFilter: _roleFilterFromQuery(s)),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.adminOrganisations, builder: (c, s) => const OrganisationsListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.adminDepartments, builder: (c, s) => const DepartmentsListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.adminAudit, builder: (c, s) => const AuditLogsListScreen()),
          ]),
          StatefulShellBranch(routes: [
                ]),
          _settingsBranch(AppRoutes.adminSettings),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.adminUsers}/:id',
        builder: (c, s) => UserDetailScreen(userId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminOfficialNew,
        builder: (c, s) => const DepartmentOfficialFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminOfficialEdit}/:id/edit',
        builder: (c, s) => DepartmentOfficialFormScreen(officialId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.adminOrganisations}/:id',
        builder: (c, s) => OrganisationDetailScreen(organisationId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.adminDepartmentNew,
        builder: (c, s) => const DepartmentFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.adminDepartments}/:id',
        builder: (c, s) => DepartmentDetailScreen(departmentId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.adminAudit}/:id',
        builder: (c, s) => AuditLogDetailScreen(logId: s.pathParameters['id']!),
      ),

      // Reached from the admin dashboard / header, not a navigation tab.
      GoRoute(path: AppRoutes.adminVerification, builder: (c, s) => const AdminVerificationQueueScreen()),
      GoRoute(
        path: '${AppRoutes.adminVerification}/:id',
        builder: (c, s) => VerificationRequestDetailScreen(requestId: s.pathParameters['id']!),
      ),
      // Reached from the admin header's search field; `?id=` pre-fills and runs the search.
      GoRoute(
        path: AppRoutes.adminCitizenSearch,
        builder: (c, s) => AdminCitizenSearchScreen(initialIdNumber: s.uri.queryParameters['id']),
      ),
      GoRoute(path: AppRoutes.adminComplianceAudits, builder: (c, s) => const ComplianceAuditsListScreen()),
      GoRoute(path: AppRoutes.adminHouseholdRecords, builder: (c, s) => const HouseholdRecordsListScreen()),
      GoRoute(path: AppRoutes.adminAnalytics, builder: (c, s) => const AdminAnalyticsScreen()),
      GoRoute(path: AppRoutes.adminFlaggedRecords, builder: (c, s) => const FlaggedRecordsListScreen()),
      GoRoute(
        path: '${AppRoutes.adminFlaggedRecords}/:id',
        builder: (c, s) => FlaggedRecordDetailScreen(flagId: s.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.adminAppeals, builder: (c, s) => const AppealsListScreen()),
      GoRoute(
        path: '${AppRoutes.adminAppeals}/:id',
        builder: (c, s) => AppealDetailScreen(appealId: s.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.citizenAppeals, builder: (c, s) => const MyAppealsScreen()),
      GoRoute(path: AppRoutes.adminProfile, builder: (c, s) => const AdminProfileScreen()),
    ],
  );
});
