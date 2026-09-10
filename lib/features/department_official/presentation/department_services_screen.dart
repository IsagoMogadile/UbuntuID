import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../data/department_repository.dart';

class DepartmentServicesScreen extends ConsumerWidget {
  const DepartmentServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(departmentServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Department Services')),
      body: servicesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load services.',
          onRetry: () => ref.invalidate(departmentServicesProvider),
        ),
        data: (services) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final service = services[index];
            return ListItemCard(
              title: service.name,
              subtitle: service.description,
              leadingIcon: service.icon,
              onTap: () => context.push(service.route ?? AppRoutes.departmentCitizenRecords),
            );
          },
        ),
      ),
    );
  }
}
