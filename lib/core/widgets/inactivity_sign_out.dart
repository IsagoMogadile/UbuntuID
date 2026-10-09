import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs the user out after [timeout] without a tap, click, scroll or key
/// press. A minute before, a banner warns them and offers to stay signed in
/// (people who read or type slowly must get the chance). The router then
/// sends them to the login screen, where [messengerKey] tells them why.
class InactivitySignOut extends StatefulWidget {
  const InactivitySignOut({
    super.key,
    required this.messengerKey,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Duration timeout;
  final Widget child;

  @override
  State<InactivitySignOut> createState() => _InactivitySignOutState();
}

class _InactivitySignOutState extends State<InactivitySignOut> {
  static const _warning = Duration(minutes: 1);

  DateTime _lastActivity = DateTime.now();
  bool _warningShown = false;
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  bool get _signedIn => Supabase.instance.client.auth.currentSession != null;

  @override
  void initState() {
    super.initState();
    // Browsers slow timers down in background tabs, so also check as soon
    // as the tab is shown again.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check, onShow: _check);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  void _activity() {
    // Activity after the limit passed (e.g. returning to a sleeping tab)
    // must not count: sign out first.
    if (_check()) return;
    _lastActivity = DateTime.now();
    _hideWarning();
  }

  void _hideWarning() {
    if (!_warningShown) return;
    _warningShown = false;
    widget.messengerKey.currentState?.hideCurrentMaterialBanner();
  }

  void _showWarning() {
    if (_warningShown) return;
    _warningShown = true;
    final signOutAt = _lastActivity.add(widget.timeout);
    widget.messengerKey.currentState?.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.timer_outlined),
        content: _Countdown(until: signOutAt),
        actions: [
          TextButton(
            onPressed: () {
              _lastActivity = DateTime.now();
              _hideWarning();
            },
            child: const Text('Stay signed in'),
          ),
        ],
      ),
    );
  }

  /// Signs out if the limit has passed; returns whether it did.
  bool _check() {
    if (!_signedIn) {
      _lastActivity = DateTime.now();
      _hideWarning();
      return false;
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (idle < widget.timeout) {
      if (idle >= widget.timeout - _warning) _showWarning();
      return false;
    }
    _lastActivity = DateTime.now();
    _hideWarning();
    unawaited(_signOut());
    return true;
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Offline: the local session is cleared regardless.
    }
    widget.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('You were signed out after ${widget.timeout.inMinutes} minutes of inactivity.'),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      onPointerHover: (_) => _activity(),
      child: widget.child,
    );
  }
}

/// "You'll be signed out in 0:42". Screen readers announce it once, not
/// every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.until});

  final DateTime until;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final seconds = left.isNegative ? 0 : left.inSeconds;
    return Semantics(
      liveRegion: true,
      label: "You haven't done anything for a while. You will be signed out in one minute.",
      excludeSemantics: true,
      child: Text(
        "You haven't done anything for a while. For your security you'll be signed out in "
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.',
      ),
    );
  }
}
