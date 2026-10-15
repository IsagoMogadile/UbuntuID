import 'dart:io';

import 'package:digital_id/features/citizen/guide/guide_mockups.dart';
import 'package:digital_id/features/citizen/guide/guide_pdf.dart';
import 'package:digital_id/features/citizen/guide/guide_topics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the citizen guide PDF. Set UBUNTUID_PDF_OUT to a folder to also
/// write it (and each screen picture as SVG) there for visual review.
void main() {
  // The PDF loads the coat of arms from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['UBUNTUID_PDF_OUT'];

  test('every topic picture rings each part it names', () {
    // A numbered badge: a gold circle with a white outline.
    final badge = RegExp('<circle [^>]*fill="#C9962C" stroke="#FFFFFF"');
    for (final topic in citizenGuideTopics) {
      final svg = topic.mockup.toSvg();
      expect(badge.allMatches(svg).length, topic.mockup.highlights.length, reason: '${topic.title}: a highlight names a missing part');
      expect(topic.steps.length, greaterThanOrEqualTo(topic.mockup.highlights.length), reason: topic.title);
      if (outDir != null) {
        File('$outDir/guide_${citizenGuideTopics.indexOf(topic) + 1}.svg').writeAsStringSync(svg);
      }
    }
  });

  test('every screen draws', () {
    for (final screen in GuideScreen.values) {
      expect(GuideMockup(screen).toSvg(), allOf(startsWith('<svg'), endsWith('</svg>')), reason: screen.name);
    }
  });

  test('builds the guide PDF', () async {
    final bytes = await GuidePdf.build(generatedAt: DateTime(2026, 10, 15));
    expect(bytes.length, greaterThan(10000));
    if (outDir != null) File('$outDir/${GuidePdf.fileName}').writeAsBytesSync(bytes);
  });
}
