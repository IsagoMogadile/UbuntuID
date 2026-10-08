import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// Links that are meant to be opened outside the app -- currently the
/// public verification page behind every QR code.
class PublicLinks {
  PublicLinks._();

  /// The app's own address: [EnvConfig.publicAppUrl] if set, otherwise the
  /// address the web app is currently served from. Null off the web with no
  /// configured address, since there's then nowhere a scanner could open.
  static String? get _baseUrl {
    final configured = EnvConfig.publicAppUrl.trim();
    if (configured.isNotEmpty) return configured.replaceAll(RegExp(r'/+$'), '');
    if (!kIsWeb) return null;
    final base = Uri.base;
    final path = base.path.replaceAll(RegExp(r'(index\.html)?/*$'), '');
    return Uri(scheme: base.scheme, host: base.host, port: base.port, path: path).toString();
  }

  /// What a credential's or identity card's QR code encodes. [ref] is the
  /// credential_id or citizen_id (random UUIDs -- never the ID number). The
  /// app uses Flutter web's default hash URLs, hence the `#`.
  static String verify(String ref) {
    final base = _baseUrl;
    return base == null ? 'UBUNTUID:VERIFY:$ref' : '$base/#/verify/$ref';
  }
}
