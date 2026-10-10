import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/citizen_repository.dart';
import '../domain/service_item.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  static String _routeFor(ServiceItem service) {
    if (!service.available) {
      return '${AppRoutes.comingSoon}?feature=${Uri.encodeComponent(service.name)}';
    }
    return service.route;
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                          ),
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
