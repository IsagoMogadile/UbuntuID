import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  static String _routeFor(dynamic service) {
    if (!(service.available as bool)) {
      return '${AppRoutes.comingSoon}?feature=${Uri.encodeComponent(service.name as String)}';
    }
    return switch (service.name as String) {
      'SASSA Grants' => AppRoutes.citizenSassa,
      'Human Settlements' => AppRoutes.citizenHumanSettlements,
      'Identity Verification' => AppRoutes.citizenVerification,
      // Both already live on the Digital Identity screen's credential list
      // (every credential type, including Tax Compliance and Driver's
      // Licence/NSC/Tertiary Qualification) -- no separate screen needed.
      'Tax & SARS' => AppRoutes.citizenDigitalIdentity,
      'Licences & Qualifications' => AppRoutes.citizenDigitalIdentity,
      _ => '${AppRoutes.comingSoon}?feature=${Uri.encodeComponent(service.name as String)}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Government Services')),
      body: servicesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load services.',
          onRetry: () => ref.invalidate(servicesProvider),
        ),
        data: (services) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 150,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return AppCard(
              onTap: () => context.push(_routeFor(service)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(service.icon, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(height: 10),
                  Text(service.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      service.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
