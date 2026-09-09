import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The same gradient-card-with-QR presentation `DigitalIdCardScreen`
/// pioneered for the citizen's identity, generalised so every credential
/// (passport, driver's licence, tax compliance, police clearance, matric,
/// tertiary qualification, labour status, SASSA status) can be shown the
/// same realistic, physical-card-like way instead of just a list row --
/// this is what the citizen's Document Wallet is built from.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.headerLabel,
    required this.icon,
    required this.qrData,
    required this.primaryLine,
    required this.secondaryLines,
    required this.status,
    required this.gradientColors,
    this.footerNote,
  });

  /// e.g. "UBUNTUID DIGITAL IDENTITY", "SOUTH AFRICAN PASSPORT".
  final String headerLabel;
  final IconData icon;
  final String qrData;

  /// The large, prominent line -- full name for identity, credential type
  /// name for everything else.
  final String primaryLine;

  /// Smaller detail lines under [primaryLine] -- ID number/DOB for
  /// identity; issuing department, dates, qualification detail for others.
  final List<String> secondaryLines;
  final String status;
  final List<Color> gradientColors;
  final String? footerNote;

  bool get _isPositiveStatus => const {'active', 'valid', 'approved', 'compliant', 'clear'}.contains(status.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerLabel.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _isPositiveStatus ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: QrImageView(data: qrData, version: QrVersions.auto, size: 160, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            primaryLine,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          for (final line in secondaryLines) ...[
            const SizedBox(height: 4),
            Text(line, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (footerNote != null) ...[
            const SizedBox(height: 16),
            Text(footerNote!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
