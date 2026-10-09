// Whether the device is online, for the offline notice (see
// `core/widgets/offline_notice.dart`). The web uses the browser's own
// online/offline events; elsewhere the stub always reports online.
export 'connection_status_stub.dart' if (dart.library.js_interop) 'connection_status_web.dart';
