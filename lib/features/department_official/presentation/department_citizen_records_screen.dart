import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../../shared/domain/citizen_lookup_result.dart';
import '../../shared/presentation/citizen_lookup_screen.dart';
import '../data/department_repository.dart';
import '../domain/department_record_config.dart';

const _iconByName = recordTypeIconByName;

/// Search a citizen, then create/view this official's department-specific
/// records for them (register a marriage, issue a licence, record a tax
/// return, etc.) -- the "do my job" screen for every department, reached
/// from the dashboard and from Department Services.
class DepartmentCitizenRecordsScreen extends ConsumerStatefulWidget {
  const DepartmentCitizenRecordsScreen({super.key});

  @override
  ConsumerState<DepartmentCitizenRecordsScreen> createState() => _DepartmentCitizenRecordsScreenState();
}

class _DepartmentCitizenRecordsScreenState extends ConsumerState<DepartmentCitizenRecordsScreen> {
  CitizenLookupResult? _citizen;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(departmentProfileProvider);
    final citizen = _citizen;

    return Scaffold(
      appBar: AppBar(title: const Text('Department Records')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: citizen == null
            ? CitizenSearchPanel(
                onSearch: ref.read(departmentRepositoryProvider).searchCitizens,
                onSelect: (selected) => setState(() => _citizen = selected),
              )
            : profileAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load your department',
                  message: '',
                ),
                data: (profile) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _citizen = null),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Change citizen'),
                      ),
                    ),
                    Expanded(child: _RecordSections(citizen: citizen, departmentCode: profile.departmentCode)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RecordSections extends ConsumerWidget {
  const _RecordSections({required this.citizen, required this.departmentCode});

  final CitizenLookupResult citizen;
  final String departmentCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = recordTypesForDepartment(departmentCode);
    if (types.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No record types configured',
        message: 'Your department has no dedicated record type set up yet.',
      );
    }

    return ListView(
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Text('${citizen.fullName} • ${citizen.idNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (departmentCode == 'HOME_AFFAIRS')
                TextButton.icon(
                  onPressed: () => context.push('${AppRoutes.departmentEditCitizen}/${citizen.citizenId}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final type in types) _RecordTypeSection(citizen: citizen, config: type),
      ],
    );
  }
}

class _RecordTypeSection extends ConsumerStatefulWidget {
  const _RecordTypeSection({required this.citizen, required this.config});

  final CitizenLookupResult citizen;
  final RecordTypeConfig config;

  @override
  ConsumerState<_RecordTypeSection> createState() => _RecordTypeSectionState();
}

class _RecordTypeSectionState extends ConsumerState<_RecordTypeSection> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = ref.read(departmentRepositoryProvider);
    _future = widget.config.fetchExisting(repo, widget.citizen);
  }

  Future<void> _addRecord() async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RecordFormDialog(config: widget.config, citizen: widget.citizen),
    );
    if (values == null) return;
    try {
      await widget.config.buildInsertData(ref.read(departmentRepositoryProvider), widget.citizen, values);
      if (mounted) {
        setState(_load);
        final message = widget.config.label == 'Death'
            ? 'Death recorded. A UbuntuID administrator has been notified to deactivate this citizen\'s account.'
            : '${widget.config.label} record added.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add this record: $e')));
      }
    }
  }

  Future<void> _editRecord(Map<String, dynamic> existingRow) async {
    final updater = widget.config.buildUpdateData;
    if (updater == null) return;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RecordFormDialog(config: widget.config, citizen: widget.citizen, existingValues: existingRow),
    );
    if (values == null) return;
    try {
      await updater(ref.read(departmentRepositoryProvider), widget.citizen, existingRow, values);
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.config.label} record updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update this record: $e')));
      }
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> existingRow) async {
    final deleter = widget.config.buildDelete;
    if (deleter == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this ${widget.config.label.toLowerCase()}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await deleter(ref.read(departmentRepositoryProvider), widget.citizen, existingRow);
      if (mounted) {
        setState(_load);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.config.label} record removed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove this record: $e')));
      }
    }
  }

  Future<void> _lodgeAppeal(Map<String, dynamic> existingRow) async {
    final table = widget.config.table;
    final idColumn = widget.config.idColumn;
    if (table == null || idColumn == null) return;
    final relatedId = existingRow[idColumn]?.toString();
    if (relatedId == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Lodge appeal -- ${widget.config.rowTitle(existingRow)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The citizen is disputing this record. An administrator will review this appeal.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Appeal reason (required)'),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Lodge appeal'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;

    try {
      await ref.read(departmentRepositoryProvider).lodgeAppeal(
            citizenId: widget.citizen.citizenId,
            relatedTable: table,
            relatedId: relatedId,
            appealReason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appeal lodged.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not lodge this appeal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconByName[widget.config.icon] ?? Icons.folder_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.config.label, style: Theme.of(context).textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: _addRecord,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LoadingIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Could not load: ${snapshot.error}', style: const TextStyle(color: AppColors.error)),
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No records yet.', style: TextStyle(color: AppColors.charcoalMuted)),
                );
              }
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(widget.config.rowTitle(rows[i])),
                        subtitle: Text(widget.config.rowSubtitle(rows[i])),
                        onTap: widget.config.buildUpdateData == null ? null : () => _editRecord(rows[i]),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.config.table != null && widget.config.idColumn != null)
                              IconButton(
                                icon: const Icon(Icons.gavel_outlined, size: 18),
                                tooltip: 'Lodge appeal',
                                onPressed: () => _lodgeAppeal(rows[i]),
                              ),
                            if (widget.config.buildUpdateData != null && widget.config.buildDelete == null)
                              const Icon(Icons.edit_outlined, size: 18),
                            if (widget.config.buildDelete != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: 'Remove',
                                onPressed: () => _deleteRecord(rows[i]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecordFormDialog extends StatefulWidget {
  const _RecordFormDialog({required this.config, required this.citizen, this.existingValues});

  final RecordTypeConfig config;
  final CitizenLookupResult citizen;

  /// When set, the dialog opens pre-filled for editing this row instead of
  /// a blank "Add" form.
  final Map<String, dynamic>? existingValues;

  @override
  State<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<_RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdownValues = {};
  String? _validationError;

  bool get _isEditing => widget.existingValues != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingValues;
    for (final field in widget.config.fields) {
      final existingValue = existing?[field.key];
      if (field.type == RecordFieldType.dropdown) {
        _dropdownValues[field.key] =
            existingValue?.toString() ?? field.options?.first;
      } else {
        _controllers[field.key] = TextEditingController(text: existingValue?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final values = <String, dynamic>{};
    for (final field in widget.config.fields) {
      values[field.key] = field.type == RecordFieldType.dropdown
          ? _dropdownValues[field.key]
          : _controllers[field.key]!.text.trim();
    }
    final reason = widget.config.validate?.call(widget.citizen, values);
    if (reason != null) {
      setState(() => _validationError = reason);
      return;
    }
    Navigator.pop(context, values);
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String().split('T').first;
      setState(() => _validationError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit ${widget.config.label}' : 'Add ${widget.config.label}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.config.fields) ...[
                if (field.type == RecordFieldType.dropdown)
                  DropdownButtonFormField<String>(
                    initialValue: _dropdownValues[field.key],
                    decoration: InputDecoration(labelText: field.label),
                    items: [for (final o in field.options ?? []) DropdownMenuItem(value: o, child: Text(o))],
                    onChanged: (v) => setState(() {
                      _dropdownValues[field.key] = v;
                      _validationError = null;
                    }),
                  )
                else if (field.type == RecordFieldType.date)
                  TextFormField(
                    controller: _controllers[field.key],
                    readOnly: true,
                    decoration: InputDecoration(labelText: field.label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
                    onTap: () => _pickDate(_controllers[field.key]!),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  )
                else
                  TextFormField(
                    controller: _controllers[field.key],
                    keyboardType: field.type == RecordFieldType.number
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: field.label),
                    validator:
                        field.optional ? null : (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onChanged: (_) {
                      if (_validationError != null) setState(() => _validationError = null);
                    },
                  ),
                const SizedBox(height: 12),
              ],
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: Text(_isEditing ? 'Save' : 'Add')),
      ],
    );
  }
}
