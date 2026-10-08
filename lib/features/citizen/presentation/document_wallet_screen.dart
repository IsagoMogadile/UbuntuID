import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/wallet_card.dart';
import '../data/citizen_repository.dart';
import '../documents/document_downloads.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';
import 'identity_card.dart';

/// A swipeable wallet of every real document this citizen holds, each drawn
/// as a card-sized [WalletCard] like the identity card -- extended to every
/// credential (passport, driver's licence, tax
/// compliance, police clearance, matric, tertiary qualification, labour
/// status, SASSA status). One card per document, like a physical wallet;
/// swipe or use the dots to move between them. The download button saves
/// the card currently in view as its prototype PDF.
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
            final downloads = <VoidCallback>[
              () => DocumentDownloads.identityDocument(context, ref, identity),
              for (final c in credentials) () => DocumentDownloads.credential(context, ref, identity, c),
            ];
            final page = _page.clamp(0, cards.length - 1);
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
                          width: i == page ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: i == page ? 0.9 : 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${page + 1} of ${cards.length} • swipe to browse',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: OutlinedButton.icon(
                    onPressed: downloads[page],
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
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
    return IdentityCard(identity: identity, maxWidth: 380);
  }

  Widget _credentialCard(DigitalIdentity identity, CredentialItem credential) {
    final qualification = credential.qualification;
    final expiry = credential.expiryDate;
    return WalletCard(
      title: credential.typeName,
      status: credential.status,
      headerColors: _credentialColours(credential.typeName),
      qrData: 'UBUNTUID:CRED:${credential.credentialId}',
      rows: [
        [WalletCardField('Holder', identity.fullName.toUpperCase())],
        if (qualification != null) [WalletCardField('Qualification', qualification.qualificationName.toUpperCase())],
        if (qualification?.institutionName != null)
          [WalletCardField('Institution', qualification!.institutionName!.toUpperCase())],
        if (qualification?.result != null) [WalletCardField('Result', qualification!.result!.toUpperCase())],
        // A qualification's issuer is already in the footer's "Verified by";
        // leaving it out here keeps room for the qualification itself.
        if (qualification == null) [WalletCardField('Issued by', credential.issuingDepartment.toUpperCase())],
        [
          WalletCardField('Date of Issue', AppFormatters.date(credential.issuedDate).toUpperCase()),
          WalletCardField('Valid Until', expiry == null ? 'NO EXPIRY' : AppFormatters.date(expiry).toUpperCase()),
        ],
      ],
      footerNote: 'Verified by ${credential.issuingDepartment}.',
      showPortrait: const {'DRIVERS_LICENCE', 'PASSPORT'}.contains(credential.typeCode),
      maxWidth: 380,
    );
  }
}

/// One distinct colour identity per credential type -- like the way real
/// ID documents (green ID book, maroon passport, blue licence) each read
/// differently at a glance, rather than every card in the wallet looking
/// the same.
List<Color> _credentialColours(String typeName) {
  return switch (typeName) {
    'South African Passport' => const [Color(0xFF7A1F2B), Color(0xFFB0464F)],
    "Driver's Licence" => const [Color(0xFF1B4B8A), Color(0xFF3E7CB1)],
    'Tax Compliance Status' => const [Color(0xFF1F5C4C), Color(0xFF3E8E75)],
    'Police Clearance Certificate' => const [Color(0xFF2B2B2B), Color(0xFF555555)],
    'National Senior Certificate' => const [Color(0xFF6A3FA0), Color(0xFF9A6FCB)],
    'Tertiary Qualification' => const [Color(0xFF8A5A00), Color(0xFFC98A1F)],
    'UIF / Employment Status' => const [Color(0xFF2A5D6B), Color(0xFF4E8F9E)],
    'SASSA Grant Status' => const [Color(0xFF7A4B1E), Color(0xFFAF7A3E)],
    _ => const [AppColors.green, AppColors.gold],
  };
}
