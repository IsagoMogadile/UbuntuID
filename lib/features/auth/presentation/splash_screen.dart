import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/error_view.dart';
import '../application/role_resolution.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    setState(() => _error = null);
    try {
      final destination = await resolveDestinationRoute(ref);
      if (!mounted) return;
      context.go(destination);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to reach UbuntuID services. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLogo(size: 72, showWordmark: false),
                  SizedBox(height: 16),
                  Text('UbuntuID', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                    'Digital Identity & Verification Platform',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 28),
                  SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ],
              )
            : ErrorView(message: _error!, onRetry: _resolve),
      ),
    );
  }
}
