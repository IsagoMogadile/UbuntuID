import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/citizen_repository.dart';

class PersonalInformationScreen extends ConsumerWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(digitalIdentityProvider);
    final addressesAsync = ref.watch(citizenAddressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Information')),
      body: identityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(message: 'Could not load your personal information.', onRetry: () => ref.invalidate(digitalIdentityProvider)),
        data: (identity) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(label: 'First name', value: identity.firstName),
                  DetailRow(label: 'Last name', value: identity.lastName),
                  DetailRow(label: 'ID number', value: identity.idNumber),
                  DetailRow(label: 'Date of birth', value: AppFormatters.date(identity.dateOfBirth)),
                  DetailRow(label: 'Phone', value: identity.phoneNumber ?? 'Not on file'),
                  DetailRow(label: 'Email', value: identity.email ?? 'Not on file'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Address', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            addressesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => const Text('Could not load your address.'),
              data: (addresses) {
                if (addresses.isEmpty) {
                  return const Text('No address on file.', style: TextStyle(fontSize: 13));
                }
                return Column(
                  children: [
                    for (final address in addresses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address.addressType[0].toUpperCase() + address.addressType.substring(1),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (address.isCurrent)
                                    const Text('Current', style: TextStyle(fontSize: 12, color: Colors.green)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(address.formatted),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'This information is sourced from Home Affairs records and cannot '
              'currently be edited in UbuntuID.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
