import 'package:flutter/material.dart';

import '../../../routing/app_routes.dart';
import 'guide_mockups.dart';

/// One "how do I...?" section of the citizen user guide. The in-app guide
/// and the downloadable PDF are both built from [citizenGuideTopics], so
/// they always say the same thing.
class GuideTopic {
  const GuideTopic({
    required this.title,
    required this.icon,
    required this.summary,
    required this.where,
    required this.steps,
    required this.mockup,
    this.tip,
    this.route,
    this.openLabel,
  });

  final String title;
  final IconData icon;
  final String summary;

  /// The path to it in a few words, e.g. "Bottom bar > Services".
  final String where;

  /// Numbered steps; step N matches the gold "N" on [mockup].
  final List<String> steps;
  final GuideMockup mockup;
  final String? tip;

  /// Where the guide's "Take me there" button goes, if anywhere.
  final String? route;
  final String? openLabel;
}

const citizenGuideTopics = <GuideTopic>[
  GuideTopic(
    title: 'Finding your way around',
    icon: Icons.explore_outlined,
    summary: 'Every main page is one tap away on the bar at the bottom of the screen. '
        'On a computer or tablet the same buttons run down the left-hand side instead.',
    where: 'Bottom bar (left side on a computer)',
    steps: [
      'Use the bar to switch between Dashboard, Services, Notifications and Reports.',
      'Tap More for Settings and Log Out.',
      'The Guide button at the top opens this guide from any main page.',
      'The person icon in the top-right corner opens your Profile.',
    ],
    mockup: GuideMockup(GuideScreen.dashboard, highlights: ['nav', 'nav:4', 'guide', 'profile']),
    tip: 'Lost? Tap Dashboard on the bottom bar to go back to the start.',
  ),
  GuideTopic(
    title: 'Your digital ID card',
    icon: Icons.badge_outlined,
    summary: 'Your Dashboard opens with your digital ID card, QR code included, '
        'so you can show it the moment you log in.',
    where: 'Dashboard > top of the page',
    steps: [
      'Your ID card shows your name, ID number and a QR code that others can scan to check it is real.',
      'Your identity status says whether Home Affairs has verified you, and what to do if not.',
    ],
    mockup: GuideMockup(GuideScreen.dashboard, highlights: ['idCard', 'status']),
    tip: 'If your status is not "Active", visit a Home Affairs office to fix it.',
    route: AppRoutes.citizenDashboard,
    openLabel: 'Go to Dashboard',
  ),
  GuideTopic(
    title: 'Document Wallet and downloading your ID',
    icon: Icons.wallet_outlined,
    summary: 'The Document Wallet holds your ID and every credential issued to you, '
        "such as your driver's licence or matric certificate.",
    where: 'Dashboard > tap your ID card',
    steps: [
      'Tap your ID card on the Dashboard to open the Document Wallet.',
      'Swipe left or right, or tap a dot, to move between your cards.',
      'Tap Download PDF to save the card you are looking at.',
    ],
    mockup: GuideMockup(GuideScreen.wallet, highlights: ['wallet:card', 'wallet:dots', 'wallet:download']),
    route: AppRoutes.citizenDocumentWallet,
    openLabel: 'Open Document Wallet',
  ),
  GuideTopic(
    title: 'Downloading documents',
    icon: Icons.description_outlined,
    summary: 'Every official document you can download, plus anything else on file for you, is listed in one place.',
    where: 'Dashboard > Quick actions > Documents',
    steps: [
      'On the Dashboard, tap Documents under Quick actions.',
      'Tap the download arrow next to a document to save it as a PDF.',
      'Documents on file shows other documents and whether they have been verified.',
    ],
    mockup: GuideMockup(GuideScreen.documents, highlights: ['doc:list', 'doc:download', 'doc:onFile']),
    route: AppRoutes.citizenDocuments,
    openLabel: 'Open Documents',
  ),
  GuideTopic(
    title: 'Government services',
    icon: Icons.apps_outlined,
    summary: 'See your records from each department: Home Affairs, licences, tax, police clearance, '
        'matric and university results, UIF, SASSA grants and housing.',
    where: 'Bottom bar > Services',
    steps: [
      'Tap Services on the bottom bar.',
      'Tap a department, for example SASSA Grants, to see your status and history with it.',
    ],
    mockup: GuideMockup(GuideScreen.services, highlights: ['nav:1', 'svc:SASSA Grants']),
    tip: 'Matric results are under Basic Education; university results are under Higher Education.',
    route: AppRoutes.citizenServices,
    openLabel: 'Open Services',
  ),
  GuideTopic(
    title: 'Who checked my details',
    icon: Icons.fact_check_outlined,
    summary: 'Whenever an organisation (an employer, bank or municipality) checks your details, it is recorded here.',
    where: 'Dashboard > Quick actions > Who checked my details',
    steps: [
      'Each row shows who checked, what they checked and when. Tap one for the full results.',
      'The badge shows whether the check is Pending, Completed or Rejected.',
    ],
    mockup: GuideMockup(GuideScreen.verification, highlights: ['ver:0', 'ver:badge']),
    route: AppRoutes.citizenVerification,
    openLabel: 'See who checked',
  ),
  GuideTopic(
    title: 'Controlling who can verify you',
    icon: Icons.privacy_tip_outlined,
    summary: 'You decide which organisations may verify your credentials, and you can take that permission back at any time.',
    where: 'Profile (top-right) > Verification consent',
    steps: [
      'Each organisation you have allowed is listed with what it can verify.',
      'Tap Revoke to stop an organisation from verifying you again.',
    ],
    mockup: GuideMockup(GuideScreen.consent, highlights: ['consent:list', 'consent:revoke']),
    route: AppRoutes.citizenConsent,
    openLabel: 'Manage consent',
  ),
  GuideTopic(
    title: 'Notifications',
    icon: Icons.notifications_outlined,
    summary: 'UbuntuID tells you when something changes, such as new results or someone checking your details.',
    where: 'Bottom bar > Notifications',
    steps: [
      'The red number on Notifications shows how many you have not read yet.',
      'New messages have a gold dot. Tap one to read it in full.',
    ],
    mockup: GuideMockup(GuideScreen.notifications, highlights: ['nav:2', 'notif:0']),
    route: AppRoutes.citizenNotifications,
    openLabel: 'Open Notifications',
  ),
  GuideTopic(
    title: 'Your profile and personal information',
    icon: Icons.person_outline,
    summary: 'Check the details government holds about you: name, ID number, address and contact details.',
    where: 'Person icon (top-right) > Profile',
    steps: [
      'Tap the person icon in the top-right corner of any main page.',
      'Personal information shows your details as they are on record.',
      'Verification consent is where you allow or revoke organisations.',
    ],
    mockup: GuideMockup(GuideScreen.profile, highlights: ['back', 'profile:personal', 'profile:consent']),
    tip: 'If a detail is wrong, contact the department that keeps it, such as Home Affairs.',
    route: AppRoutes.citizenProfile,
    openLabel: 'Open Profile',
  ),
  GuideTopic(
    title: 'Your activity report',
    icon: Icons.bar_chart_outlined,
    summary: 'A summary of your activity, such as checks on your details and documents, that you can download.',
    where: 'Bottom bar > Reports',
    steps: [
      'Tap Reports on the bottom bar.',
      'Choose the period you want to see, for example the last 30 days.',
      'Tap the download arrow to save the report as a PDF or Excel file.',
    ],
    mockup: GuideMockup(GuideScreen.reports, highlights: ['nav:3', 'rep:period', 'rep:download']),
    route: AppRoutes.citizenReports,
    openLabel: 'Open Reports',
  ),
  GuideTopic(
    title: 'Bigger text, dark mode and read aloud',
    icon: Icons.accessibility_new_outlined,
    summary: 'Make UbuntuID easier to read and use: change the theme, make text bigger, or have it read to you.',
    where: 'More > Settings > Accessibility',
    steps: [
      'Choose a light or dark theme, or match your phone.',
      'Pick a bigger text size; the preview shows how it will look.',
      'Turn on Read aloud, then tap anything once to hear it, and again to use it.',
    ],
    mockup: GuideMockup(GuideScreen.accessibility, highlights: ['a11y:theme', 'a11y:text', 'a11y:read']),
    route: AppRoutes.settingsAccessibility,
    openLabel: 'Open Accessibility',
  ),
  GuideTopic(
    title: 'Settings, password and signing out',
    icon: Icons.settings_outlined,
    summary: 'Change your password and notification preferences, send feedback, or sign out.',
    where: 'Bottom bar > More > Settings',
    steps: [
      'Tap More on the bottom bar, then Settings.',
      'Account is where you change your email or password.',
      'Feedback lets you send a complaint, compliment or suggestion.',
      'Sign out when you are finished, especially on a shared device.',
    ],
    mockup: GuideMockup(GuideScreen.settings, highlights: ['nav:4', 'set:Account', 'set:Feedback', 'set:Sign out']),
    tip: 'For your safety UbuntuID signs you out by itself after a while without use.',
    route: AppRoutes.citizenSettings,
    openLabel: 'Open Settings',
  ),
];
