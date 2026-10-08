import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_logo.dart';

/// One labelled value on a [WalletCard], e.g. "Surname" / "MOGADILE".
class WalletCardField {
  const WalletCardField(this.label, this.value, {this.flex = 1, this.large = false});

  final String label;
  final String value;

  /// Share of the row's width when several fields sit side by side.
  final int flex;

  /// Bigger, wider-spaced value -- for the one number a reader looks for
  /// first (e.g. the identity number).
  final bool large;
}

/// A document in the citizen's wallet drawn as a physical card: the coat of
/// arms and the document's name in a coloured header band, a portrait
/// silhouette with the document's details beside it, and its verification
/// QR code on the right-hand side.
///
/// Every card keeps a real ID card's proportions (ID-1, 85.6 x 54 mm) at
/// every width: drawn on a fixed [_cardWidth] x [_cardHeight] canvas and
/// scaled to fit, never wider than [maxWidth]. The identity card
/// (`IdentityCard`) and each credential card in the Document Wallet are
/// built from it, so they all read as the same family of cards.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.title,
    required this.status,
    required this.headerColors,
    required this.qrData,
    required this.rows,
    this.bodyColors,
    this.footerNote,
    this.footerBrand = 'UBUNTUID DOCUMENT WALLET',
    this.maxWidth = 460,
    this.alignment = Alignment.center,
  });

  /// The document's own name, e.g. "IDENTITY CARD", "DRIVER'S LICENCE".
  final String title;
  final String status;

  /// The header band's gradient -- each document type has its own colours.
  final List<Color> headerColors;

  /// The card body's gradient; defaults to a pale tint of [headerColors].
  final List<Color>? bodyColors;
  final String qrData;

  /// Detail rows beside the portrait, top to bottom. Six rows fill the card.
  final List<List<WalletCardField>> rows;

  /// e.g. "Tap to open your Document Wallet." -- shown along the bottom.
  final String? footerNote;
  final String footerBrand;
  final double maxWidth;
  final AlignmentGeometry alignment;

  static const _cardWidth = 480.0;
  static const _cardHeight = _cardWidth * 54 / 85.6;

  static const _ink = Color(0xFF1E2A22);
  static const _label = Color(0xFF5B6B60);

  bool get _isPositiveStatus =>
      const {'active', 'valid', 'approved', 'compliant', 'clear'}.contains(status.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final accent = headerColors.first;
    final body = bodyColors ??
        [
          Color.lerp(Colors.white, headerColors.first, 0.12)!,
          const Color(0xFFF7F6F0),
          Color.lerp(Colors.white, headerColors.last, 0.18)!,
        ];

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
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: body),
                  border: Border.all(color: Color.lerp(Colors.white, accent, 0.25)!),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _GuillochePainter(accent),
                    child: Column(
                      children: [
                        _header(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _portrait(accent),
                                const SizedBox(width: 14),
                                Expanded(child: _details()),
                                const SizedBox(width: 10),
                                _qr(accent),
                              ],
                            ),
                          ),
                        ),
                        _footer(accent),
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

  Widget _header() {
    final positive = _isPositiveStatus;
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
      decoration: BoxDecoration(gradient: LinearGradient(colors: headerColors)),
      child: Row(
        children: [
          // On a white disc so the arms' colours read against the band.
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const AppLogo(size: 30, showWordmark: false),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // White when positive so it reads on every header colour.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: positive ? Colors.white : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: positive ? headerColors.first : Colors.white,
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
  Widget _portrait(Color accent) {
    return Container(
      width: 100,
      height: 126,
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFFDCE5E0), accent, 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB7C7BC)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: Icon(Icons.person, size: 104, color: Color(0xFF7D8F84)),
        ),
      ),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          if (row.length == 1)
            _field(row.single)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in row) Expanded(flex: field.flex, child: _field(field)),
              ],
            ),
      ],
    );
  }

  Widget _field(WalletCardField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _label, fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
          ),
          // Long names (institutions, qualifications, departments) wrap to a
          // second line in a slightly smaller size instead of being cut off.
          Text(
            field.value.isEmpty ? '-' : field.value,
            maxLines: field.large ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: field.large ? 14 : (field.value.length > 22 ? 10.5 : 12),
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: field.large ? 1.2 : 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qr(Color accent) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color.lerp(Colors.white, accent, 0.25)!),
          ),
          child: QrImageView(
            data: qrData,
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

  Widget _footer(Color accent) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: accent.withValues(alpha: 0.08),
      child: Row(
        children: [
          Expanded(
            child: Text(
              footerNote ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _label, fontSize: 9.5),
            ),
          ),
          Text(
            footerBrand,
            style: const TextStyle(color: _label, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

/// Faint wavy line-work across the card, the way printed cards carry a fine
/// background pattern -- purely decorative.
class _GuillochePainter extends CustomPainter {
  _GuillochePainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = colour.withValues(alpha: 0.08);
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
  bool shouldRepaint(covariant _GuillochePainter oldDelegate) => oldDelegate.colour != colour;
}
