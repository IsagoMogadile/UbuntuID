import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/service_providers.dart';
import '../domain/public_document.dart';
import '../domain/public_verification_result.dart';

/// Looks up what a scanned QR code refers to, for anyone -- signed in or
/// not. Goes through the `verify_document_public` security-definer RPC
/// (docs/database/public_qr_verification.sql), which returns only the
/// document type, issuer, status and dates: never personal details.
class PublicVerificationRepository {
  PublicVerificationRepository(this._client);

  final SupabaseClient _client;

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  /// Null when no document matches [ref] (including a malformed one).
  Future<PublicVerificationResult?> verify(String ref) async {
    if (!_uuid.hasMatch(ref)) return null;
    final row = await _client.rpc('verify_document_public', params: {'p_ref': ref}) ??
        // An NSC Statement of Results (docs/database/nsc_statement_of_results.sql).
        await _client.rpc('verify_nsc_statement_public', params: {'p_ref': ref});
    if (row == null) return null;
    return PublicVerificationResult.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// The document itself, via the `public_document` RPC. Null when no
  /// document matches [ref].
  Future<PublicDocument?> document(String ref) async {
    if (!_uuid.hasMatch(ref)) return null;
    final row = await _client.rpc('public_document', params: {'p_ref': ref});
    if (row == null) return null;
    return PublicDocument.fromJson(Map<String, dynamic>.from(row as Map));
  }
}

final publicVerificationRepositoryProvider = Provider<PublicVerificationRepository>((ref) {
  return PublicVerificationRepository(ref.watch(supabaseClientProvider));
});

final publicVerificationProvider = FutureProvider.autoDispose.family<PublicVerificationResult?, String>((ref, docRef) {
  return ref.watch(publicVerificationRepositoryProvider).verify(docRef);
});

final publicDocumentProvider = FutureProvider.autoDispose.family<PublicDocument?, String>((ref, docRef) {
  return ref.watch(publicVerificationRepositoryProvider).document(docRef);
});
