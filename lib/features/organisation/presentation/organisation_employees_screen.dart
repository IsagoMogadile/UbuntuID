import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/organisation_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';

/// Everyone this organisation has employed through UbuntuID. Any staff
/// member can end an active employment (with a reason); the citizen is
/// notified and the Labour record the offer opened is closed.
class OrganisationEmployeesScreen extends ConsumerStatefulWidget {
  const OrganisationEmployeesScreen({super.key});

  @override
  ConsumerState<OrganisationEmployeesScreen> createState() => _OrganisationEmployeesScreenState();
}

class _OrganisationEmployeesScreenState extends ConsumerState<OrganisationEmployeesScreen> {
  bool _showEnded = false;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(organisationEmployeesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: employeesAsync.when(
        loading: () => const ShimmerListPlaceholder(),
        error: (e, _) => ErrorView(
          message: 'Could not load employees.',
          onRetry: () => ref.invalidate(organisationEmployeesProvider),
        ),
        data: (employees) {
          final active = employees.where((e) => e.isActive).length;
          final shown = _showEnded ? employees : employees.where((e) => e.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(organisationEmployeesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('$active active of ${employees.length}')),
                    FilterChip(
                      label: const Text('Show ended'),
                      selected: _showEnded,
                      onSelected: (v) => setState(() => _showEnded = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No employees yet',
                    message: 'Offer employment from a reviewed applicant to add someone here.',
                  ),
                for (final e in shown) ...[
                  ListItemCard(
                    leadingIcon: Icons.person_outline,
                    title: e.citizenFullName,
                    subtitle: '${e.jobTitle} · ${e.employmentType}\n'
                        'From ${AppFormatters.date(e.startDate)}'
                        '${e.endDate == null ? '' : ' to ${AppFormatters.date(e.endDate!)}'}',
                    trailing: StatusBadge.fromStatus(e.employmentStatus),
                    onTap: () => _openEmployee(e),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEmployee(OrganisationEmployeeItem employee) async {
    final ended = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmployeeSheet(employee: employee),
    );
    if (ended == true) ref.invalidate(organisationEmployeesProvider);
  }
}

class _EmployeeSheet extends ConsumerStatefulWidget {
  const _EmployeeSheet({required this.employee});

  final OrganisationEmployeeItem employee;

  @override
  ConsumerState<_EmployeeSheet> createState() => _EmployeeSheetState();
}

class _EmployeeSheetState extends ConsumerState<_EmployeeSheet> {
  final _reason = TextEditingController();
  late DateTime _endDate;
  bool _ending = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _endDate = today.isBefore(widget.employee.startDate) ? widget.employee.startDate : today;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _end() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for ending this employment.');
      return;
    }
    setState(() {
      _ending = true;
      _error = null;
    });
    try {
      await ref.read(organisationRepositoryProvider).endEmployment(
            employeeId: widget.employee.employeeId,
            endDate: _endDate,
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      AppToast.success(context, 'Employment ended. ${widget.employee.citizenFullName} has been notified.');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Could not end this employment. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final muted = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.citizenFullName, style: Theme.of(context).textTheme.titleMedium)),
                StatusBadge.fromStatus(e.employmentStatus),
              ],
            ),
            Text('ID ${e.citizenIdNumber}', style: muted),
            const SizedBox(height: 12),
            Text('${e.jobTitle}${e.departmentOrPosition == null ? '' : ' · ${e.departmentOrPosition}'}'),
            Text(e.employmentType, style: muted),
            if (e.salary != null) Text('${AppFormatters.currencyZar(e.salary!)} ${e.salaryFrequency.toLowerCase()}', style: muted),
            Text(
              'From ${AppFormatters.date(e.startDate)}${e.endDate == null ? '' : ' to ${AppFormatters.date(e.endDate!)}'}',
              style: muted,
            ),
            if (e.terminationReason != null) ...[
              const SizedBox(height: 8),
              Text('Ended: ${e.terminationReason}'),
            ],
            if (e.isActive) ...[
              const SizedBox(height: 20),
              if (!_confirming)
                AppButton(
                  label: 'End employment',
                  icon: Icons.work_off_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => setState(() => _confirming = true),
                )
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Last working day'),
                  subtitle: Text(AppFormatters.date(_endDate)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: e.startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
                TextField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Reason (shared with the employee)'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                AppButton(
                  label: 'Confirm end of employment',
                  icon: Icons.check,
                  expand: true,
                  loading: _ending,
                  onPressed: _ending ? null : _end,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
