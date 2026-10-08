import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/wallet_card.dart';
import '../documents/credential_documents.dart';
import '../domain/digital_identity.dart';

/// The citizen's identity as an ID card -- a [WalletCard] laid out like a
/// South African smart ID card front (portrait on the left, Surname /
/// Names / Sex / Nationality / Identity Number / Date of Birth / Status
/// beside it), with the UbuntuID verification QR code on the right-hand
/// side. It carries the coat of arms, like the downloadable documents, and
/// is titled simply "Identity Card" -- never "Republic of South Africa".
class IdentityCard extends StatelessWidget {
  const IdentityCard({
    super.key,
    required this.identity,
    this.footerNote,
    this.maxWidth = 460,
    this.alignment = Alignment.centerLeft,
  });

  final DigitalIdentity identity;

  /// e.g. "Tap to open your Document Wallet." -- shown along the bottom.
  final String? footerNote;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final holder = DocumentHolder.fromIdentity(identity);
    return WalletCard(
      title: 'Identity Card',
      status: identity.currentStatus,
      headerColors: const [AppColors.green, Color(0xFF2F7D4A)],
      bodyColors: const [Color(0xFFE4F1E3), Color(0xFFF3F1DC), Color(0xFFF7E7C2)],
      qrData: 'UBUNTUID:${identity.idNumber}',
      rows: [
        [WalletCardField('Surname', holder.surname.toUpperCase())],
        [WalletCardField('Names', holder.firstNames.toUpperCase())],
        [
          WalletCardField('Sex', holder.sexLabel, flex: 2),
          const WalletCardField('Nationality', 'RSA', flex: 5),
        ],
        [WalletCardField('Identity Number', holder.groupedIdNumber, large: true)],
        [
          WalletCardField('Date of Birth', AppFormatters.date(holder.dateOfBirth).toUpperCase()),
          WalletCardField(
            'Status',
            holder.citizenshipLabel == 'South African citizen' ? 'CITIZEN' : 'PERMANENT RESIDENT',
          ),
        ],
        [WalletCardField('Registered', AppFormatters.date(holder.registeredAt).toUpperCase())],
      ],
      footerNote: footerNote ?? 'Present the QR code to verify your identity.',
      footerBrand: 'UBUNTUID DIGITAL ID',
      maxWidth: maxWidth,
      alignment: alignment,
    );
  }
}
