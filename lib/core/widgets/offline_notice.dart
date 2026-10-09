import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/connection_status.dart' as connection;
import '../theme/app_colors.dart';

/// A strip across the top of every screen while the device is offline, so
/// failed loads and saves have an obvious cause. It disappears by itself
/// when the connection returns.
class OfflineNotice extends StatefulWidget {
  const OfflineNotice({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineNotice> createState() => _OfflineNoticeState();
}

class _OfflineNoticeState extends State<OfflineNotice> {
  bool _online = connection.isOnline;
  StreamSubscription<bool>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = connection.onlineChanges.listen((online) => setState(() => _online = online));
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_online)
          Material(
            color: AppColors.charcoal,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're offline. Anything you save will fail until your connection is back.",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          // The page below no longer needs to pad for the status bar.
          child: MediaQuery.removePadding(context: context, removeTop: !_online, child: widget.child),
        ),
      ],
    );
  }
}
