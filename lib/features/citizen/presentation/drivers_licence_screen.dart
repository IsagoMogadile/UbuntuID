import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/citizen_repository.dart';

/// Full details behind the Driver's Licence service: every
/// `dot_driver_licences` row for this citizen plus the vehicles registered
/// to them in `dot_vehicles`. View-only -- licences and vehicles are
/// issued/registered by the Department of Transport.
class DriversLicenceScreen extends ConsumerWidget {
  const DriversLicenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licencesAsync = ref.watch(driversLicencesProvider);
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Driver's Licence")),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driversLicencesProvider);
          ref.invalidate(myVehiclesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Licence details'),
            licencesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => const ErrorView(message: 'Could not load your licence details.'),
              data: (licences) {
                if (licences.isEmpty) {
                  return const EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'No licence on record',
                    message: 'The Department of Transport has no driver\'s licence on file for you.',
                  );
                }
                return Column(
                  children: [
                    for (final licence in licences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LicenceCard(licence: licence),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Registered vehicles'),
            vehiclesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) => const ErrorView(message: 'Could not load your vehicles.'),
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return const EmptyState(
                    icon: Icons.no_crash_outlined,
                    title: 'No vehicles registered',
                    message: 'No vehicles are registered in your name.',
                  );
                }
                return Column(
                  children: [
                    for (final vehicle in vehicles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VehicleCard(vehicle: vehicle),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain-English vehicle category for each licence code.
const _licenceCodes = {
  'A1': 'Motorcycle up to 125 cm³',
  'A': 'Motorcycle over 125 cm³',
  'B': 'Light motor vehicle up to 3 500 kg',
  'EB': 'Light motor vehicle with heavy trailer',
  'C1': 'Heavy motor vehicle 3 500 - 16 000 kg',
  'C': 'Heavy motor vehicle over 16 000 kg',
  'EC1': 'Heavy vehicle (C1) with trailer',
  'EC': 'Heavy vehicle (C) with trailer',
};

String _text(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim();
  return value == null || value.isEmpty ? 'Not on record' : value;
}

String _date(Map<String, dynamic> row, String key) {
  final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
  return parsed == null ? 'Not on record' : AppFormatters.date(parsed);
}

class _LicenceCard extends StatelessWidget {
  const _LicenceCard({required this.licence});

  final Map<String, dynamic> licence;

  @override
  Widget build(BuildContext context) {
    final code = _text(licence, 'licence_code');
    final category = _licenceCodes[code.replaceFirst(RegExp(r'^Code\s*', caseSensitive: false), '')];
    final status = licence['status']?.toString();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              if (status != null && status.isNotEmpty) StatusBadge.fromStatus(status),
            ],
          ),
          const SizedBox(height: 12),
          DetailRow(label: 'Licence number', value: _text(licence, 'licence_number')),
          DetailRow(label: 'Vehicle category', value: category ?? 'Not on record'),
          DetailRow(label: 'Issue date', value: _date(licence, 'issue_date')),
          DetailRow(label: 'Expiry date', value: _date(licence, 'expiry_date')),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final name = [vehicle['make'], vehicle['model']]
        .where((v) => v != null && v.toString().trim().isNotEmpty)
        .join(' ');
    final year = vehicle['year']?.toString();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Vehicle' : (year == null ? name : '$name ($year)'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DetailRow(label: 'Registration number', value: _text(vehicle, 'registration_number')),
          DetailRow(label: 'VIN', value: _text(vehicle, 'vin_number')),
          DetailRow(label: 'Licence disc expiry', value: _date(vehicle, 'disc_expiry_date')),
        ],
      ),
    );
  }
}
