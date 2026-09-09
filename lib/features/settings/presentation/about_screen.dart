import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';

/// The 4 UbuntuID system administrators seeded at project setup
/// (`ubuntuid_administrators`, confirmed live -- a 5th row present in the
/// database is a test/QA artifact from a later session, not a named
/// developer, so it's deliberately left out here).
const _developers = ['Kopano Mogadile', 'Tebogo Mothibi', 'Keabetswe Molefane', 'Buhle Ndlovu'];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About UbuntuID')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: AppLogo(size: 56)),
          const SizedBox(height: 20),
          const Text(
            'UbuntuID is a final-year university prototype demonstrating a '
            'digital identity and verification platform for South African '
            'citizens, government departments and organisations.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'UbuntuID is an independent academic project. It is not an '
            'official South African Government or GCIS service, and '
            'government-service data shown in this app is simulated, not '
            'real. See docs/PROJECT_SCOPE.md in the project repository for '
            'full scope details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.charcoalMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const _AboutRow(label: 'Version', value: '1.0.0'),
          const _AboutRow(label: 'Build', value: 'Prototype'),
          const SizedBox(height: 24),
          const Divider(),
          const _SectionTitle('What UbuntuID does'),
          const SizedBox(height: 8),
          const Text(
            'One central digital identity per citizen, with department-specific '
            'access on top of it: Home Affairs registers and maintains the core '
            'identity record; Transport, SARS, SAPS, Basic Education, Higher '
            'Education, SASSA and Employment & Labour each manage only their '
            'own service records against that identity. Organisations can '
            'search for a citizen and request verification of specific '
            'credentials (with consent tracked and revocable); a UbuntuID '
            'administrator oversees the whole platform -- users, departments, '
            'organisations, flagged records and an audit trail. Everything '
            'runs on Supabase/PostgreSQL with Row Level Security as the real '
            'access-control boundary, not just the app\'s own screens.',
          ),
          const SizedBox(height: 24),
          const Divider(),
          const _SectionTitle('Developed by'),
          const SizedBox(height: 8),
          const Text(
            'UbuntuID was built and is administered by 4 UbuntuID system '
            'administrators:',
          ),
          const SizedBox(height: 10),
          for (final name in _developers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: AppColors.charcoalMuted),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const _SectionTitle('Recommended enhancements'),
          const SizedBox(height: 4),
          const Text(
            'Ideas for extending UbuntuID beyond this prototype, kept here so '
            'they read as a roadmap rather than a hidden gap (see also '
            'docs/FUTURE_WORK.md in the project repository).',
            style: TextStyle(color: AppColors.charcoalMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const _RequirementGroup(
            title: 'Functional',
            items: [
              'Real document upload and storage for citizens\' identity documents, not metadata-only records',
              'A dedicated Human Settlements department workflow, rather than housing data existing only for realism',
              'In-app staff self-management for department/organisation admins, not only a platform administrator',
              'Push/SMS notification delivery, not just in-app notification rows',
              'Two-factor authentication (currently a visible but disabled settings toggle)',
              'A citizen-facing appeals/dispute process for flagged or rejected records',
            ],
          ),
          const SizedBox(height: 14),
          const _RequirementGroup(
            title: 'Non-functional',
            items: [
              'Automated integration tests against a seeded local Supabase instance, not pure-logic unit tests only',
              'Tightening organisation credential-type scope into the RLS policy itself, not just the application-layer query filter',
              'A production-grade transactional email provider, replacing Supabase\'s built-in low-volume sender',
              'Structured performance/load testing as citizen and record volume grows',
              'Formal accessibility (WCAG) review of every screen, not just spot-checked components',
              'A documented data-retention and deletion policy for citizen records',
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _RequirementGroup extends StatelessWidget {
  const _RequirementGroup({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 5, color: AppColors.charcoalMuted),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.charcoalMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
