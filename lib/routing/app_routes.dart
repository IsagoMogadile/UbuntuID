import '../models/user_role.dart';

/// Centralised route path constants so screens never hand-type a path
/// string more than once.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const registerOrganisation = '/register-organisation';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const accountNotConfigured = '/account-not-configured';
  static const accountRevoked = '/account-revoked';

  /// Public (no login required) -- reachable from the login screen's "About
  /// UbuntuID" button for a new/prospective user who hasn't signed up yet.
  /// Same `AboutScreen` widget the logged-in Settings -> About screen uses
  /// (`settingsAbout`).
  static const about = '/about';

  // Shared
  static const unauthorized = '/unauthorized';
  static const noInternet = '/no-internet';
  static const notFound = '/not-found';
  static const comingSoon = '/coming-soon';

  // Citizen
  static const citizenDashboard = '/citizen';
  static const citizenServices = '/citizen/services';
  static const citizenNotifications = '/citizen/notifications';
  static const citizenProfile = '/citizen/profile';
  static const citizenDigitalIdentity = '/citizen/digital-identity';
  static const citizenDocuments = '/citizen/documents';
  static const citizenSassa = '/citizen/services/sassa';
  static const citizenHumanSettlements = '/citizen/services/human-settlements';
  static const citizenPersonalInformation = '/citizen/profile/personal-information';
  static const citizenVerification = '/citizen/verification';
  static const citizenConsent = '/citizen/profile/consent';
  static const citizenDigitalIdCard = '/citizen/profile/id-card';
  static const citizenDocumentWallet = '/citizen/wallet';
  static const citizenTimeline = '/citizen/timeline';
  static const citizenEmployment = '/citizen/employment';
  static const citizenAppeals = '/citizen/appeals';

  // Department official
  static const departmentDashboard = '/department-official';
  static const departmentVerification = '/department-official/verification';
  static const departmentServices = '/department-official/services';
  static const departmentProfile = '/department-official/profile';
  static const departmentRegisterCitizen = '/department-official/register-citizen';
  static const departmentClearanceSearch = '/department-official/clearance-search';
  static const departmentCitizenSearch = '/department-official/citizen-search';
  static const departmentCitizenRecords = '/department-official/citizen-records';
  static const departmentEditCitizen = '/department-official/citizens'; // + '/:id/edit'
  static const departmentSapsWanted = '/department-official/saps/wanted';
  static const departmentSapsOffenders = '/department-official/saps/offenders';

  // Organisation
  static const organisationDashboard = '/organisation';
  static const organisationSearch = '/organisation/search';
  static const organisationVerification = '/organisation/verification';
  static const organisationProfile = '/organisation/profile';
  static const organisationColleagues = '/organisation/colleagues';

  // Administrator
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminOrganisations = '/admin/organisations';
  static const adminDepartments = '/admin/departments';
  static const adminDepartmentNew = '/admin/departments/new';
  static const adminAudit = '/admin/audit';
  static const adminVerification = '/admin/verification';
  static const adminFlaggedRecords = '/admin/flagged-records';
  static const adminAppeals = '/admin/appeals';
  static const adminProfile = '/admin/profile';
  static const adminOfficialNew = '/admin/officials/new';
  static const adminOfficialEdit = '/admin/officials'; // + '/:id/edit'
  static const adminCitizenSearch = '/admin/citizen-search';
  static const adminComplianceAudits = '/admin/compliance-audits';
  static const adminHouseholdRecords = '/admin/household-records';
  static const adminAnalytics = '/admin/analytics';

  // Department official
  static const departmentColleagues = '/department-official/colleagues';

  // Shared settings
  static const settings = '/settings';
  static const settingsAccount = '/settings/account';
  static const settingsSecurity = '/settings/security';
  static const settingsNotifications = '/settings/notifications';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsAppearance = '/settings/appearance';
  static const settingsAbout = '/settings/about';

  static String dashboardForRole(UserRole role) => switch (role) {
        UserRole.citizen => citizenDashboard,
        UserRole.departmentOfficial => departmentDashboard,
        UserRole.organisationUser => organisationDashboard,
        UserRole.administrator => adminDashboard,
      };
}
