import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/department_repository.dart';

/// SAPS officials' citizen-search screen (spec: "Citizen searches,
/// clearance-related records, verification requests, verification status").
/// UbuntuID simulates clearance data in its own Supabase schema -- no real
/// SAPS system is called. See docs/PROJECT_SCOPE.md.
class SapsClearanceSearchScreen extends ConsumerStatefulWidget {
  const SapsClearanceSearchScreen({super.key});

  @override
  ConsumerState<SapsClearanceSearchScreen> createState() => _SapsClearanceSearchScreenState();
}

class _SapsClearanceSearchScreenState extends ConsumerState<SapsClearanceSearchScreen> {
  final _idNumberController = TextEditingController();
  String? _searchedIdNumber;

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _search() {
    final value = AppFormatters.compactIdNumber(_idNumberController.text);
    if (value.isEmpty) return;
    setState(() => _searchedIdNumber = value);
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync =
        _searchedIdNumber == null ? null : ref.watch(clearanceSearchProvider(_searchedIdNumber!));

    return Scaffold(
      appBar: AppBar(title: const Text('Clearance Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'ID number',
                    controller: _idNumberController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.badge_outlined,
                    onFieldSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(label: 'Search', icon: Icons.search, onPressed: _search),
              ],
            ),
            const SizedBox(height: 20),
            if (resultAsync == null)
              const Expanded(
                child: EmptyState(
                  icon: Icons.fingerprint_outlined,
                  title: 'Search by ID number',
                  message: 'Enter a citizen\'s ID number to view clearance-related records.',
                ),
              )
            else
              Expanded(
                child: resultAsync.when(
                  loading: () => const LoadingIndicator(),
                  error: (error, _) => const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Search failed',
                    message: 'Could not complete this search.',
                  ),
                  data: (result) {
                    if (result == null) {
                      return const EmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'No citizen found',
                        message: 'No citizen matches this ID number.',
                      );
                    }
                    return ListView(
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DetailRow(label: 'Name', value: result.fullName.isEmpty ? 'Unknown' : result.fullName),
                              DetailRow(label: 'ID number', value: result.idNumber),
                              DetailRow(label: 'Identity status', value: result.currentStatus),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'Clearance record'),
                        if (!result.hasClearanceRecord)
                          const AppCard(
                            child: Text('No clearance record available for this citizen.'),
                          )
                        else
                          AppCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Clearance status'),
                                StatusBadge.fromStatus(result.clearanceStatus ?? 'on_file'),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
