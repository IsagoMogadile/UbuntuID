import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/wallet_card.dart';
import '../data/citizen_repository.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';

/// A swipeable wallet of every real document this citizen holds -- the
/// same QR-card presentation `DigitalIdCardScreen` established for identity,
/// extended to every credential (passport, driver's licence, tax
/// compliance, police clearance, matric, tertiary qualification, labour
/// status, SASSA status). One card per document, like a physical wallet;
/// swipe or use the dots to move between them.
class DocumentWalletScreen extends ConsumerStatefulWidget {
  const DocumentWalletScreen({super.key});

  @override
  ConsumerState<DocumentWalletScreen> createState() => _DocumentWalletScreenState();
}

class _DocumentWalletScreenState extends ConsumerState<DocumentWalletScreen> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final credentialsAsync = ref.watch(credentialsProvider);

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        title: const Text('Document Wallet'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => const ErrorView(message: 'Could not load your document wallet.'),
        data: (identity) => credentialsAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => const ErrorView(message: 'Could not load your documents.'),
          data: (credentials) {
            final cards = [
              _identityCard(identity),
              for (final c in credentials) _credentialCard(identity, c),
            ];
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                      child: Center(child: SingleChildScrollView(child: cards[i])),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == _page ? 0.9 : 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_page + 1} of ${cards.length} • swipe to browse',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _identityCard(DigitalIdentity identity) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: WalletCard(
        headerLabel: 'UbuntuID Digital Identity',
        icon: Icons.verified_user_outlined,
        qrData: 'UBUNTUID:${identity.idNumber}',
        primaryLine: identity.fullName.isEmpty ? 'Unknown' : identity.fullName,
        secondaryLines: [
          identity.idNumber,
          'DOB: ${AppFormatters.date(identity.dateOfBirth)}',
        ],
        status: identity.currentStatus,
        gradientColors: const [AppColors.green, AppColors.gold],
        footerNote: 'Present this QR code to a department official or approved organisation for identity verification.',
      ),
    );
  }

  Widget _credentialCard(DigitalIdentity identity, CredentialItem credential) {
    final theme = _credentialTheme(credential.typeName);
    final qualification = credential.qualification;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: WalletCard(
        headerLabel: credential.typeName,
        icon: theme.icon,
        qrData: 'UBUNTUID:CRED:${credential.credentialId}',
        primaryLine: qualification?.qualificationName ?? credential.typeName,
        secondaryLines: [
          identity.fullName,
          credential.issuingDepartment,
          if (qualification?.institutionName != null) qualification!.institutionName!,
          if (qualification?.result != null) 'Result: ${qualification!.result}',
          'Issued ${AppFormatters.date(credential.issuedDate)}',
          if (credential.expiryDate != null) 'Expires ${AppFormatters.date(credential.expiryDate!)}',
        ],
        status: credential.status,
        gradientColors: theme.gradient,
        footerNote: 'Verified by ${credential.issuingDepartment}.',
      ),
    );
  }
}

class _CredentialTheme {
  const _CredentialTheme(this.icon, this.gradient);
  final IconData icon;
  final List<Color> gradient;
}

/// One distinct colour identity per credential type -- like the way real
/// ID documents (green ID book, maroon passport, blue licence) each read
/// differently at a glance, rather than every card in the wallet looking
/// the same.
_CredentialTheme _credentialTheme(String typeName) {
  return switch (typeName) {
    'South African Passport' => const _CredentialTheme(Icons.menu_book_outlined, [Color(0xFF7A1F2B), Color(0xFFB0464F)]),
    "Driver's Licence" => const _CredentialTheme(Icons.directions_car_outlined, [Color(0xFF1B4B8A), Color(0xFF3E7CB1)]),
    'Tax Compliance Status' => const _CredentialTheme(Icons.receipt_long_outlined, [Color(0xFF1F5C4C), Color(0xFF3E8E75)]),
    'Police Clearance Certificate' => const _CredentialTheme(Icons.gavel_outlined, [Color(0xFF2B2B2B), Color(0xFF555555)]),
    'National Senior Certificate' => const _CredentialTheme(Icons.school_outlined, [Color(0xFF6A3FA0), Color(0xFF9A6FCB)]),
    'Tertiary Qualification' => const _CredentialTheme(Icons.workspace_premium_outlined, [Color(0xFF8A5A00), Color(0xFFC98A1F)]),
    'UIF / Employment Status' => const _CredentialTheme(Icons.work_outline, [Color(0xFF2A5D6B), Color(0xFF4E8F9E)]),
    'SASSA Grant Status' => const _CredentialTheme(Icons.volunteer_activism_outlined, [Color(0xFF7A4B1E), Color(0xFFAF7A3E)]),
    _ => const _CredentialTheme(Icons.badge_outlined, [AppColors.green, AppColors.gold]),
  };
}
