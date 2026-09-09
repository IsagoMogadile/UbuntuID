import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';
import '../domain/consent_grant_item.dart';

/// Which organisations currently hold consent to verify which of this
/// citizen's credential types -- and lets them revoke it. `consent_grants`
/// existed and was already citizen-readable, but nothing surfaced it
/// anywhere until now.
class ConsentManagementScreen extends ConsumerStatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  ConsumerState<ConsentManagementScreen> createState() => _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends ConsumerState<ConsentManagementScreen> {
  String? _revokingId;

  Future<void> _revoke(ConsentGrantItem consent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke consent'),
        content: Text(
          'Revoke ${consent.organisationName}\'s consent to verify '
          '${consent.credentialTypeNames.join(', ')}? They will no longer be able to '
          'raise new verification requests against these credentials.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revokingId = consent.consentId);
    try {
      await ref.read(citizenRepositoryProvider).revokeConsent(consent.consentId);
      ref.invalidate(consentGrantsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not revoke consent: $e')));
      }
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consentsAsync = ref.watch(consentGrantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Consent')),
      body: consentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your consent history.',
          onRetry: () => ref.invalidate(consentGrantsProvider),
        ),
        data: (consents) {
          if (consents.isEmpty) {
            return const EmptyState(
              icon: Icons.privacy_tip_outlined,
              title: 'No consent on record',
              message: 'No organisation has requested verification consent from you yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: consents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final consent = consents[index];
              final status = consent.revokedAt != null
                  ? 'revoked'
                  : consent.isActive
                      ? 'active'
                      : 'expired';
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(consent.organisationName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge.fromStatus(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(consent.credentialTypeNames.isEmpty
                        ? 'No specific credentials on file'
                        : consent.credentialTypeNames.join(', ')),
                    const SizedBox(height: 6),
                    Text(
                      'Granted ${AppFormatters.date(consent.grantedAt)}'
                      '${consent.expiresAt != null ? ' • expires ${AppFormatters.date(consent.expiresAt!)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (consent.isActive) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Revoke',
                        icon: Icons.block_outlined,
                        variant: AppButtonVariant.secondary,
                        loading: _revokingId == consent.consentId,
                        onPressed: _revokingId != null ? null : () => _revoke(consent),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
