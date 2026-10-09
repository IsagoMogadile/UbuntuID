import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

LocalStorage? tabSessionStorage(String key) => _TabSessionStorage(key);

class _TabSessionStorage extends LocalStorage {
  _TabSessionStorage(this._key);

  final String _key;

  @override
  Future<void> initialize() async {
    // Sessions used to be kept in localStorage, shared by every tab; drop
    // any left over so an old one can't sign a new tab in.
    web.window.localStorage.removeItem(_key);
  }

  @override
  Future<bool> hasAccessToken() async => web.window.sessionStorage.getItem(_key) != null;

  @override
  Future<String?> accessToken() async => web.window.sessionStorage.getItem(_key);

  @override
  Future<void> removePersistedSession() async => web.window.sessionStorage.removeItem(_key);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      web.window.sessionStorage.setItem(_key, persistSessionString);
}
