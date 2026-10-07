import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../application/role_resolution.dart';

/// The app's starting route (`/`): a short branded intro -- coat of arms,
/// "UbuntuID", tagline, fading in one after another -- while the signed-in
/// user's destination is resolved in parallel. It moves on once both the
/// intro has played and the destination is known, so it adds at most about
/// a second and a half on a fast connection, and never hides a slow one
/// (a slim progress bar appears if resolving takes longer than that).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  static const _coatOfArmsAsset = 'assets/branding/coat_of_arms.svg';

  /// Intro (coat of arms -> name -> tagline) and the short fade-out before
  /// navigating away.
  static const _introDuration = Duration(milliseconds: 1100);
  static const _minimumDisplay = Duration(milliseconds: 1400);
  static const _exitDuration = Duration(milliseconds: 250);
  static const _slowAfter = Duration(milliseconds: 2200);

  late final AnimationController _intro = AnimationController(vsync: this, duration: _introDuration);
  late final AnimationController _exit = AnimationController(vsync: this, duration: _exitDuration);

  late final Animation<double> _armsOpacity = _interval(0.0, 0.45);
  late final Animation<double> _armsScale = Tween(begin: 0.96, end: 1.0).animate(
    CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _titleOpacity = _interval(0.35, 0.75);
  late final Animation<double> _taglineOpacity = _interval(0.6, 1.0);

  String? _error;
  bool _slow = false;
  Timer? _slowTimer;

  Animation<double> _interval(double begin, double end) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Parse the SVG before the first fade starts, so the coat of arms fades
    // in whole rather than popping in part-way through.
    try {
      const loader = SvgAssetLoader(_coatOfArmsAsset);
      await svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
    } catch (_) {
      // Still fine -- SvgPicture.asset loads it itself.
    }
    if (!mounted) return;
    if (reduceMotion) {
      _intro.value = 1;
    } else {
      unawaited(_intro.forward());
    }
    await _resolve(minimumDisplay: reduceMotion ? Duration.zero : _minimumDisplay);
  }

  Future<void> _resolve({Duration minimumDisplay = Duration.zero}) async {
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });

    try {
      final (destination, _) = await (resolveDestinationRoute(ref), Future<void>.delayed(minimumDisplay)).wait;
      _slowTimer?.cancel();
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) await _exit.forward();
      if (!mounted) return;
      context.go(destination);
    } catch (_) {
      _slowTimer?.cancel();
      if (!mounted) return;
      _intro.value = 1;
      setState(() {
        _error = 'Unable to reach UbuntuID services. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    // Scale from the shorter side so the crest is never too large on a
    // phone held sideways or too small on a desktop window.
    final armsHeight = (size.shortestSide * 0.30).clamp(120.0, 220.0);
    final titleSize = (armsHeight * 0.17).clamp(26.0, 36.0);

    if (_error != null) {
      return Scaffold(body: Center(child: ErrorView(message: _error!, onRetry: _resolve)));
    }

    return Scaffold(
      body: FadeTransition(
        opacity: ReverseAnimation(_exit),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _armsOpacity,
                    child: ScaleTransition(
                      scale: _armsScale,
                      // Height only, BoxFit.contain: the crest keeps its own
                      // proportions at every size.
                      child: SvgPicture.asset(
                        _coatOfArmsAsset,
                        height: armsHeight,
                        fit: BoxFit.contain,
                        semanticsLabel: 'Coat of arms of South Africa',
                      ),
                    ),
                  ),
                  SizedBox(height: armsHeight * 0.16),
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: Text(
                      'UbuntuID',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Trusted Identity. Connected Services.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.brightness == Brightness.dark ? Colors.white70 : AppColors.charcoalMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Only on a slow connection -- a quiet progress bar, never a spinner.
                  SizedBox(
                    height: 6,
                    child: AnimatedOpacity(
                      opacity: _slow ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const AppLoadingBar(width: 120),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
