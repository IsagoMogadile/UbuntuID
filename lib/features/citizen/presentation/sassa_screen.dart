import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';

/// SASSA is simulated: this screen only reads this project's own `sassa_grants`
/// table -- no real SASSA API is called. View-only: UbuntuID is not the SASSA
/// application system, so there is deliberately no "Apply for a grant" action
/// here -- grant applications are made through SASSA's own process. See
/// docs/PROJECT_SCOPE.md.
class SassaScreen extends ConsumerWidget {
  const SassaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grantsAsync = ref.watch(sassaGrantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SASSA Grants')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(sassaGrantsProvider),
        child: grantsAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorView(
            message: 'Could not load your grant records.',
            onRetry: () => ref.invalidate(sassaGrantsProvider),
          ),
          data: (grants) {
            if (grants.isEmpty) {
              return const EmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'No SASSA grant records',
                message: 'No grant records are associated with your identity yet.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeader(title: 'My grants'),
                for (final grant in grants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  grant['grant_type'] as String? ?? 'SASSA Grant',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              StatusBadge.fromStatus((grant['status'] as String? ?? 'pending').toLowerCase()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Paid via ${grant['payout_method'] ?? 'Not set'}'),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
