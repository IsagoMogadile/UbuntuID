import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A neutral, clearly illustrated portrait for a citizen's prototype
/// documents -- UbuntuID has no real photographs and must never use one.
/// It's a flat vector silhouette (head, shoulders, hair shape), not a face,
/// so it can't be mistaken for a biometric photo.
///
/// Every colour is picked deterministically from the citizen's ID number,
/// so the same person gets the same avatar on every document they download.
class DocumentAvatar {
  DocumentAvatar({required this.seed, required this.feminine});

  final String seed;
  final bool feminine;

  static const _backgrounds = ['#E8EEF0', '#EEF0E6', '#F1ECE6', '#E9ECF3'];
  static const _skinTones = ['#8D5A3B', '#A86B45', '#6F4430', '#C08A63', '#5A3826'];
  static const _hairColours = ['#1F1A17', '#2E2420', '#3B2C24', '#151313'];
  static const _clothing = ['#3E5A6B', '#4F5D4A', '#5B4B5E', '#455066', '#5E5A4A'];

  int get _hash {
    var h = 17;
    for (final unit in seed.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  PdfColor _pick(List<String> palette, int salt) => PdfColor.fromHex(palette[(_hash ~/ (salt + 1)) % palette.length]);

  pw.Widget build({double width = 90, double height = 112, bool caption = true}) {
    final bg = _pick(_backgrounds, 0);
    final skin = _pick(_skinTones, 3);
    final hair = _pick(_hairColours, 7);
    final cloth = _pick(_clothing, 11);

    final portrait = pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (canvas, size) {
        final w = size.x;
        final h = size.y;
        canvas
          ..saveContext()
          ..drawRect(0, 0, w, h)
          ..clipPath()
          ..setFillColor(bg)
          ..drawRect(0, 0, w, h)
          ..fillPath();

        // Longer hair falls behind the head and onto the shoulders.
        if (feminine) {
          canvas
            ..setFillColor(hair)
            ..drawEllipse(w / 2, h * 0.56, w * 0.27, h * 0.27)
            ..drawRect(w / 2 - w * 0.27, h * 0.26, w * 0.54, h * 0.30)
            ..fillPath();
        }

        canvas
          // Shoulders.
          ..setFillColor(cloth)
          ..drawEllipse(w / 2, h * 0.02, w * 0.44, h * 0.30)
          ..fillPath()
          // Neck.
          ..setFillColor(skin)
          ..drawRect(w / 2 - w * 0.075, h * 0.22, w * 0.15, h * 0.16)
          ..fillPath()
          // Head.
          ..drawEllipse(w / 2, h * 0.58, w * 0.18, h * 0.20)
          ..fillPath()
          // Hair on top of the head.
          ..setFillColor(hair)
          ..drawEllipse(
            w / 2,
            h * (feminine ? 0.725 : 0.735),
            w * (feminine ? 0.205 : 0.19),
            h * (feminine ? 0.095 : 0.075),
          )
          ..fillPath()
          ..restoreContext();
      },
    );

    final framed = pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.6)),
      child: portrait,
    );

    if (!caption) return framed;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        framed,
        pw.SizedBox(height: 2),
        pw.Text('Illustration - not a photo', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
      ],
    );
  }
}
