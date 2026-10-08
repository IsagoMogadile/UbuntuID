import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'routing/app_router.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compiled in via --dart-define-from-file; a fresh clone has no
  // dart_defines.json (it's gitignored), so say so plainly instead of
  // failing deep inside Supabase with an empty URL.
  if (EnvConfig.supabaseUrl.isEmpty || EnvConfig.supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: UbuntuIdApp()));
}

class UbuntuIdApp extends ConsumerWidget {
  const UbuntuIdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'UbuntuID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // SelectionArea sits above the router's Navigator, so it needs its own
      // Overlay for the selection handles and context menu.
      builder: (context, child) => Overlay.wrap(child: SelectionArea(child: child!)),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SelectableText(
              'Supabase is not configured.\n\n'
              'Copy dart_defines.example.json to dart_defines.json, fill in '
              'SUPABASE_URL and SUPABASE_ANON_KEY, then run:\n\n'
              'flutter run -d chrome --dart-define-from-file=dart_defines.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
