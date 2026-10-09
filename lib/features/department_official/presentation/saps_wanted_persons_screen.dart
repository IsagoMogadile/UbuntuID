import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/department_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_form_dialog.dart';

/// SAPS-only, department-wide (not per-citizen) "have a list of wanted
/// people, if found indicate" -- backed by `saps_wanted_persons`
/// (docs/database/saps_wanted_persons.sql).
class SapsWantedPersonsScreen extends ConsumerWidget {
  const SapsWantedPersonsScreen({super.key});

  Future<void> _addToList(BuildContext context, WidgetRef ref) async {
    final idController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AppFormDialog(title: 'Add to wanted list', submitLabel: 'Add to wanted list', onSubmit: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(context, true);
            }, child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Citizen's SA ID number"),
                validator: (v) => (v == null || v.trim().length != 13) ? 'Enter a 13-digit SA ID number' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason wanted'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),),
    );
    if (result != true) return;

    try {
      await ref.read(departmentRepositoryProvider).addWantedPerson(
            idNumber: idController.text.trim(),
            reason: reasonController.text.trim(),
          );
      ref.invalidate(wantedPersonsProvider);
      if (context.mounted) {
        AppToast.success(context, 'Added to wanted list.');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Could not add.', error: e);
      }
    }
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String wantedId, String status) async {
    try {
      await ref.read(departmentRepositoryProvider).setWantedStatus(wantedId: wantedId, status: status);
      ref.invalidate(wantedPersonsProvider);
      if (context.mounted) {
        AppToast.success(context, 'Marked as $status.');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Could not update.', error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wantedAsync = ref.watch(wantedPersonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wanted List')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addToList(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add wanted person'),
      ),
      body: wantedAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: 'Could not load the wanted list. ${friendlyError(e)}', onRetry: () => ref.invalidate(wantedPersonsProvider)),
        data: (people) => people.isEmpty
            ? const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No one on the wanted list',
                message: 'Use "Add" to list a citizen as wanted.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: people.length,
                itemBuilder: (context, i) {
                  final p = people[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.fullName.isEmpty ? p.idNumber : p.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              StatusBadge.fromStatus(p.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p.idNumber, style: const TextStyle(color: AppColors.charcoalMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(p.reason),
                          const SizedBox(height: 4),
                          Text('Listed ${AppFormatters.date(p.dateListed)}',
                              style: const TextStyle(color: AppColors.charcoalMuted, fontSize: 12)),
                          if (p.status == 'Wanted') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'Found / Apprehended',
                                    icon: Icons.check_circle_outline,
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () => _updateStatus(context, ref, p.wantedId, 'Apprehended'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton(
                                    label: 'Clear',
                                    variant: AppButtonVariant.text,
                                    onPressed: () => _updateStatus(context, ref, p.wantedId, 'Cleared'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
