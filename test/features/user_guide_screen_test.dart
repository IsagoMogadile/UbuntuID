import 'package:digital_id/features/citizen/guide/guide_topics.dart';
import 'package:digital_id/features/citizen/guide/user_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists every topic and opens each one with its picture', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: UserGuideScreen()));

    expect(find.text('Download the guide (PDF)'), findsOneWidget);
    for (final (i, topic) in citizenGuideTopics.indexed) {
      final title = find.text('${i + 1}. ${topic.title}');
      await tester.ensureVisible(title);
      if (i > 0) await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text(topic.steps.first), findsOneWidget, reason: topic.title);
    }
    expect(tester.takeException(), isNull);
  });
}
