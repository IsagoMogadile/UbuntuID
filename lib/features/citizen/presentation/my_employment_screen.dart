import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';
import '../domain/employment_item.dart';

/// Employers who have offered this citizen employment via UbuntuID
/// ("Offer Employment" on an organisation's verification result) --
/// separate from the government's own Employment & UIF credential.
class MyEmploymentScreen extends ConsumerWidget {
  const MyEmploymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employmentAsync = ref.watch(myEmploymentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Employment')),
      body: employmentAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load your employment records.',
          onRetry: () => ref.invalidate(myEmploymentProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.business_center_outlined,
              title: 'No employment offers yet',
              message: 'When an organisation offers you employment through UbuntuID, it will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _EmploymentCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _EmploymentCard extends StatelessWidget {
  const _EmploymentCard({required this.item});

  final EmploymentItem item;

  @override
  Widget build(BuildContext context) {
    return ListItemCard(
      leadingIcon: Icons.business_center_outlined,
      title: '${item.jobTitle} at ${item.organisationName}',
      subtitle: [
        if (item.departmentOrPosition != null && item.departmentOrPosition!.isNotEmpty) item.departmentOrPosition!,
        'Since ${AppFormatters.date(item.startDate)}',
        if (item.salary != null) 'R${item.salary} / ${item.salaryFrequency.toLowerCase()}',
      ].join(' • '),
      trailing: StatusBadge.fromStatus(item.employmentStatus),
    );
  }
}
