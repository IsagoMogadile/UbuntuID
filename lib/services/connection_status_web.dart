import 'dart:async';

import 'package:web/web.dart' as web;

bool get isOnline => web.window.navigator.onLine;

Stream<bool> get onlineChanges {
  late final StreamController<bool> controller;
  StreamSubscription<web.Event>? online;
  StreamSubscription<web.Event>? offline;
  controller = StreamController<bool>(
    onListen: () {
      online = web.EventStreamProviders.onlineEvent.forTarget(web.window).listen((_) => controller.add(true));
      offline = web.EventStreamProviders.offlineEvent.forTarget(web.window).listen((_) => controller.add(false));
    },
    onCancel: () {
      online?.cancel();
      offline?.cancel();
    },
  );
  return controller.stream;
}
