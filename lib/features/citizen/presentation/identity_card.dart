import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../documents/credential_documents.dart';
import '../domain/digital_identity.dart';

/// The citizen's identity as an ID card -- laid out like a South African
/// smart ID card front (portrait on the left, Surname / Names / Sex /
/// Nationality / Identity Number / Date of Birth / Status beside it), with
/// the UbuntuID verification QR code on the right-hand side.
///
/// It keeps a real ID card's proportions (ID-1, 85.6 x 54 mm) at every
/// width: drawn on a fixed [_cardWidth] x [_cardHeight] canvas and scaled
/// to fit, never wider than [maxWidth]. Like the downloadable documents it
/// is UbuntuID-branded only -- no coat of arms or "Republic of South
/// Africa" -- so it can't be mistaken for a real government ID.
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

  static const _cardWidth = 480.0;
  static const _cardHeight = _cardWidth * 54 / 85.6;

  static const _ink = Color(0xFF1E2A22);
  static const _label = Color(0xFF5B6B60);

  @override
  Widget build(BuildContext context) {
    final holder = DocumentHolder.fromIdentity(identity);
    final active = identity.currentStatus.toLowerCase() == 'active';

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: _cardWidth / _cardHeight,
          child: FittedBox(
            child: SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE4F1E3), Color(0xFFF3F1DC), Color(0xFFF7E7C2)],
                  ),
                  border: Border.all(color: const Color(0xFFC9D8C6)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _GuillochePainter(),
                    child: Column(
                      children: [
                        _header(active),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _portrait(),
                                const SizedBox(width: 14),
                                Expanded(child: _details(holder)),
                                const SizedBox(width: 10),
                                _qr(),
                              ],
                            ),
                          ),
                        ),
                        _footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool active) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.green, Color(0xFF2F7D4A)]),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'UBUNTUID',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 14),
          ),
          const SizedBox(width: 10),
          Text(
            'IDENTITY CARD',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              identity.currentStatus.toUpperCase(),
              style: TextStyle(
                color: active ? _ink : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A neutral illustrated silhouette, not a photo -- UbuntuID holds no
  /// real photographs, same as the downloadable documents.
  Widget _portrait() {
    return Container(
      width: 100,
      height: 126,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE5E0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB7C7BC)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Icon(
            Icons.person,
            size: 104,
            color: const Color(0xFF7D8F84),
          ),
        ),
      ),
    );
  }

  Widget _details(DocumentHolder holder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Surname', holder.surname.toUpperCase()),
        _field('Names', holder.firstNames.toUpperCase()),
        Row(
          children: [
            Expanded(flex: 2, child: _field('Sex', holder.sexLabel)),
            Expanded(flex: 5, child: _field('Nationality', 'RSA')),
          ],
        ),
        _field('Identity Number', holder.groupedIdNumber, valueSize: 14, spacing: 1.2),
        Row(
          children: [
            Expanded(child: _field('Date of Birth', AppFormatters.date(holder.dateOfBirth).toUpperCase())),
            Expanded(child: _field('Status', holder.citizenshipLabel == 'South African citizen' ? 'CITIZEN' : 'PERMANENT RESIDENT')),
          ],
        ),
        _field('Registered', AppFormatters.date(holder.registeredAt).toUpperCase()),
      ],
    );
  }

  Widget _field(String label, String value, {double valueSize = 12, double spacing = 0.3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _label, fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
          ),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              letterSpacing: spacing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qr() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC9D8C6)),
          ),
          child: QrImageView(
            data: 'UBUNTUID:${identity.idNumber}',
            version: QrVersions.auto,
            size: 104,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Scan to verify',
          style: TextStyle(color: _label, fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.green.withValues(alpha: 0.08),
      child: Row(
        children: [
          Expanded(
            child: Text(
              footerNote ?? 'Present the QR code to an official or approved organisation to verify your identity.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _label, fontSize: 9.5),
            ),
          ),
          const Text(
            'UBUNTUID DIGITAL ID',
            style: TextStyle(color: _label, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

/// Faint wavy line-work across the card, the way printed ID cards carry a
/// fine background pattern -- purely decorative.
class _GuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppColors.green.withValues(alpha: 0.08);
    for (var i = 0; i < 14; i++) {
      final path = Path();
      final y0 = size.height * (i / 13);
      path.moveTo(0, y0);
      for (double x = 0; x <= size.width; x += 24) {
        path.quadraticBezierTo(x + 6, y0 + (i.isEven ? 8 : -8), x + 12, y0);
        path.quadraticBezierTo(x + 18, y0 + (i.isEven ? -8 : 8), x + 24, y0);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
