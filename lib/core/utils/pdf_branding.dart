import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// The coat of arms for generated PDFs (credential documents, reports).
/// pdf widgets build synchronously, so the SVG is loaded once up front with
/// [load] and reused by [coatOfArms] in every header after that.
class PdfBranding {
  PdfBranding._();

  static const _coatOfArmsAsset = 'assets/branding/coat_of_arms.svg';
  static String? _coatOfArmsSvg;

  static Future<void> load() async {
    _coatOfArmsSvg ??= await rootBundle.loadString(_coatOfArmsAsset);
  }

  /// A [size] x [size] box with the coat of arms fitted inside it. Call
  /// [load] before building the document.
  static pw.Widget coatOfArms({required double size}) {
    final svg = _coatOfArmsSvg;
    assert(svg != null, 'PdfBranding.load() must be awaited before building a PDF');
    return pw.SizedBox(
      width: size,
      height: size,
      child: svg == null ? null : pw.SvgImage(svg: svg, fit: pw.BoxFit.contain),
    );
  }
}
