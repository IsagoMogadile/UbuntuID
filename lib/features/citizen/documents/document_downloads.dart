import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/citizen_repository.dart';
import '../domain/credential_item.dart';
import '../domain/digital_identity.dart';
import 'credential_documents.dart';

/// Builds and shares a citizen's prototype PDFs -- the Documents screen's
/// and Document Wallet's download actions. Everything comes from the
/// citizen's own records.
class DocumentDownloads {
  DocumentDownloads._();

  /// The holder for a downloaded document -- the citizen's own identity
  /// plus their current address (only used on the ID document's reverse).
  static Future<DocumentHolder> _holder(WidgetRef ref, DigitalIdentity identity) async {
    String? address;
    try {
      final addresses = await ref.read(citizenRepositoryProvider).getAddresses();
      if (addresses.isNotEmpty) address = addresses.first.formatted;
    } catch (_) {
      // Address is optional on the document; leave it out if unavailable.
    }
    return DocumentHolder.fromIdentity(identity, address: address);
  }

  static Future<void> _withFeedback(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing your document...'), duration: Duration(seconds: 2)));
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not create the document. Please try again.')));
    }
  }

  /// Prototype identity document -- page 1 front, page 2 back.
  static Future<void> identityDocument(BuildContext context, WidgetRef ref, DigitalIdentity identity) {
    return _withFeedback(context, () async {
      final bytes = await CredentialDocuments.identityDocument(await _holder(ref, identity));
      await CredentialDocuments.share(bytes, CredentialDocuments.identityFileName);
    });
  }

  static Future<void> credential(
    BuildContext context,
    WidgetRef ref,
    DigitalIdentity identity,
    CredentialItem credential,
  ) {
    return _withFeedback(context, () async {
      final (holder, record) = await (
        _holder(ref, identity),
        ref.read(citizenRepositoryProvider).getCredentialRecord(credential.typeCode),
      ).wait;
      final bytes = await CredentialDocuments.credentialDocument(holder, credential, record);
      await CredentialDocuments.share(bytes, CredentialDocuments.credentialFileName(credential.typeName));
    });
  }
}
