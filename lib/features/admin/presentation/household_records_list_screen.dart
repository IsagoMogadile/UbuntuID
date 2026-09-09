import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/admin_repository.dart';

/// No department owns household/occupancy data (`docs/PROJECT_SCOPE.md`
/// §5), so this is an administrator-only oversight screen.
class HouseholdRecordsListScreen extends ConsumerWidget {
  const HouseholdRecordsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(adminHouseholdRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Household Records')),
      body: recordsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'Could not load household records.',
          onRetry: () => ref.invalidate(adminHouseholdRecordsProvider),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const EmptyState(icon: Icons.home_outlined, title: 'No household records');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = records[index];
              final details = record.recordData.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
              return ListItemCard(
                title: record.citizenName.isEmpty ? 'Unknown citizen' : record.citizenName,
                subtitle: '${record.propertyReference} • $details\n${AppFormatters.date(record.recordedAt)}',
                leadingIcon: Icons.home_outlined,
                trailing: Text(record.recordType, style: Theme.of(context).textTheme.bodySmall),
              );
            },
          );
        },
      ),
    );
  }
}
