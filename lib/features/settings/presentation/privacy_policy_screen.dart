import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';

/// The privacy policy: what UbuntuID holds, how it is used, who sees it,
/// and that organisations a citizen applies to are responsible for their
/// own use of what they receive. Public -- readable before signing up.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const lastUpdated = '9 October 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('UbuntuID privacy policy', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text('Last updated $lastUpdated', style: TextStyle(color: AppColors.charcoalMuted)),
              const SizedBox(height: 16),
              for (final part in _policy) part.build(context),
            ],
          ),
        ),
      ),
    );
  }
}

const List<_Part> _policy = [
          _Paragraph(
            'UbuntuID is a digital identity platform. It brings together the records government departments '
            'already hold about you, such as your identity, qualifications and licences, so that you can see '
            'them in one place and prove them to organisations without paper copies. This policy explains what '
            'we hold, how we use it, and who can see it. We process personal information in line with the '
            'Protection of Personal Information Act (POPIA).',
          ),
          _Section(
            title: '1. Information UbuntuID holds',
            bullets: [
              'Identity details from the population register: your name, ID number, date of birth and '
                  'citizenship status.',
              'Credentials issued by government departments, for example your matric results, driver\'s '
                  'licence, police clearance, tax, social grant, employment and housing records. Each '
                  'department remains the owner of its own records.',
              'Your account details: email address, phone number and the settings you choose.',
              'Activity records: who verified or viewed your information, when, and why. These are kept in '
                  'an audit log so every access can be traced.',
              'Notifications we send you and feedback you send us.',
            ],
          ),
          _Section(
            title: '2. How UbuntuID uses your information',
            bullets: [
              'To show you your identity and credentials, and let you download or share them.',
              'To answer verification requests from organisations you have applied to, using only the '
                  'credentials that organisation was approved to check.',
              'To let government departments keep their own records about you up to date. When one '
                  'department updates a record (for example when you start a new job), related records update '
                  'automatically.',
              'To notify you about applications, decisions and changes to your records.',
              'To keep the platform secure, prevent fraud and investigate misuse.',
            ],
            footer: 'UbuntuID does not sell your information, does not use it for advertising, and does not '
                'share it with anyone except as described in this policy or where the law requires it.',
          ),
          _Section(
            title: '3. Who can see your information',
            bullets: [
              'You can see everything UbuntuID holds about you.',
              'Government departments can see and update only the records they are responsible for.',
              'Organisations can verify only the credentials they were approved for, and only when you have '
                  'applied to them. Before approval, every organisation must explain why it needs each type of '
                  'credential, and a UbuntuID administrator reviews that reason.',
              'UbuntuID administrators can see account and audit information to run and protect the platform. '
                  'Their actions are logged too.',
            ],
          ),
          _Highlight(
            title: '4. Organisations you apply to',
            body: 'When you apply to an organisation (such as an employer, bank or university), UbuntuID only '
                'confirms whether the details you gave match official records, and shares the credentials you '
                'applied with. What the organisation then does with that information is decided by the '
                'organisation alone.\n\n'
                'UbuntuID plays no role in, and is not responsible for, how an organisation you applied to '
                'uses, stores, shares or deletes your information. Each organisation is a separate responsible '
                'party under POPIA with its own privacy obligations. If you have questions or concerns about '
                'how an organisation handles your information, contact that organisation directly, or the '
                'Information Regulator.',
          ),
          _Section(
            title: '5. Keeping your information secure',
            bullets: [
              'Access is limited by role: citizens, departments, organisations and administrators each see '
                  'only what they need.',
              'Information is encrypted while it travels between your device and UbuntuID.',
              'You are signed out automatically after 15 minutes of inactivity, and each browser tab needs '
                  'its own sign-in.',
              'Every verification and change to a record is written to an audit log.',
            ],
          ),
          _Section(
            title: '6. How long we keep it',
            bullets: [
              'Identity and credential records are kept for as long as the issuing department requires them '
                  'by law.',
              'Audit logs are kept so that past access can be checked, including after an account is closed.',
            ],
          ),
          _Section(
            title: '7. Your rights',
            bullets: [
              'See what information UbuntuID holds about you.',
              'Ask for incorrect information to be corrected. Corrections are made by the department that '
                  'issued the record.',
              'Withdraw an organisation\'s access to your information in Settings > Privacy > Organisation '
                  'consent.',
              'Object to how your information is used, or complain to the Information Regulator of South '
                  'Africa.',
            ],
          ),
          _Section(
            title: '8. Contact us',
            bullets: [
              'Send us a question or complaint through Feedback in the app. We reply in your notifications.',
            ],
            footer: 'We may update this policy. The date at the top shows when it last changed.',
          ),
];

/// One block of the policy.
sealed class _Part {
  const _Part();

  Widget build(BuildContext context);
}

class _Paragraph extends _Part {
  const _Paragraph(this.text);

  final String text;


  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(height: 1.5)));
}

class _Section extends _Part {
  const _Section({required this.title, required this.bullets, this.footer});

  final String title;
  final List<String> bullets;
  final String? footer;


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Text('•  ')),
                  Expanded(child: Text(b, style: const TextStyle(height: 1.5))),
                ],
              ),
            ),
          if (footer != null) Padding(padding: const EdgeInsets.only(top: 4), child: _Paragraph(footer!).build(context)),
        ],
      ),
    );
  }
}

class _Highlight extends _Part {
  const _Highlight({required this.title, required this.body});

  final String title;
  final String body;


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
