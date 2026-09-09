import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:digital_id/main.dart';
import 'package:digital_id/services/service_providers.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    // supabase_flutter's SupabaseClient constructor fire-and-forgets a real
    // background Isolate spawn (for JSON parsing). Under flutter_test's
    // default fake-async zone that spawn's handshake message never gets
    // processed, hanging the test until it times out. tester.runAsync runs
    // this whole block on the real event loop instead, so the handshake --
    // and the client's disposal below -- actually complete.
    await tester.runAsync(() async {
      final testClient = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [supabaseClientProvider.overrideWithValue(testClient)],
          child: const UbuntuIdApp(),
        ),
      );

      expect(find.text('UbuntuID'), findsWidgets);

      await testClient.dispose();
    });
  });
}
