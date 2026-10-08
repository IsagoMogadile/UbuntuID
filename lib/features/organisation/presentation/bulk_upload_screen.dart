import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/report_export.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../../verification/data/verification_repository.dart';
import '../data/organisation_repository.dart';
import '../domain/bulk_applicants.dart';

/// Organisation bulk upload: download a template, upload an Excel/CSV list
/// of applicants, review a "Name - Status" preview (sortable by status),
/// then submit every ready applicant. Each one becomes a normal
/// application, checked automatically against department records, and a
/// newer application for the same person replaces the earlier one.
class BulkUploadScreen extends ConsumerStatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  ConsumerState<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

enum _Sort { readyFirst, problemsFirst, name }

enum _Filter { all, ready, attention }

class _BulkUploadScreenState extends ConsumerState<BulkUploadScreen> {
  static const _maxRows = 1000;

  String? _fileName;
  BulkParseResult? _parsed;
  bool _reading = false;
  _Sort _sort = _Sort.readyFirst;
  _Filter _filter = _Filter.all;

  bool _submitting = false;
  int _done = 0;
  int _total = 0;
  Map<BulkRow, String>? _outcomes; // row -> final overall status or error

  List<BulkCredential> _credentials(List<CredentialTypeOption> scope) => [
        for (final c in scope)
          if (BulkCredential(credentialTypeId: c.credentialTypeId, typeCode: c.typeCode, displayName: c.displayName)
              .fields
              .isNotEmpty)
            BulkCredential(credentialTypeId: c.credentialTypeId, typeCode: c.typeCode, displayName: c.displayName),
      ];

  Future<void> _downloadTemplate(List<BulkCredential> credentials) async {
    final bytes = buildTemplate(credentials);
    const name = 'ubuntuid_applicants_template.xlsx';
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes,
            name: name, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ],
      fileNameOverrides: [name],
    ));
  }

  Future<void> _pickFile(List<BulkCredential> credentials) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _reading = true;
      _fileName = file.name;
      _parsed = null;
      _outcomes = null;
    });
    try {
      final table = readTable(Uint8List.fromList(file.bytes!), file.name);
      if (table.length - 1 > _maxRows) {
        throw FormatException('This file has ${table.length - 1} rows. Upload at most $_maxRows applicants at a time.');
      }
      final parsed = parseApplicants(table, credentials);

      final repo = ref.read(organisationRepositoryProvider);
      final ids = {
        for (final r in parsed.rows)
          if (r.status != BulkRowStatus.invalidId) r.idNumber,
      }.toList();
      final citizens = await repo.findCitizensByIdNumbers(ids);
      final open = await repo.citizensWithOpenApplications([for (final c in citizens.values) c.citizenId]);
      applyLookups(parsed.rows, citizens, open);

      if (mounted) setState(() => _parsed = parsed);
    } on FormatException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Could not read this file: $e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }

  Future<void> _submit() async {
    final rows = _parsed!.rows.where((r) => r.willSubmit).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit applications'),
        content: Text(
          'Submit ${rows.length} application(s)? Each applicant is checked automatically against department '
          'records. Anyone who already has an application with you will have it replaced by this new one.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;

    final orgRepo = ref.read(organisationRepositoryProvider);
    final verificationRepo = ref.read(verificationRepositoryProvider);
    final outcomes = <BulkRow, String>{};
    setState(() {
      _submitting = true;
      _done = 0;
      _total = rows.length;
    });

    Future<void> submitOne(BulkRow row) async {
      try {
        final requestId = await orgRepo.requestVerification(
          citizenId: row.citizenId!,
          credentialTypeIds: row.claims.keys.toList(),
          claimsByCredentialTypeId: row.claims,
        );
        await verificationRepo.startVerification(requestId);
        outcomes[row] = await verificationRepo.completeVerification(requestId);
      } catch (e) {
        outcomes[row] = 'error: $e';
      }
      if (mounted) setState(() => _done++);
    }

    // A few at a time: fast for hundreds of rows without flooding the API.
    var next = 0;
    Future<void> worker() async {
      while (next < rows.length) {
        await submitOne(rows[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    ref.invalidate(verificationRequestsProvider);
    if (mounted) {
      setState(() {
        _submitting = false;
        _outcomes = outcomes;
      });
    }
  }

  static String _outcomeLabel(String status) => switch (status) {
        'completed' => 'Verified',
        'partially_verified' => 'Partly verified',
        'failed' => 'Not verified',
        _ when status.startsWith('error') => 'Could not submit',
        _ => status,
      };

  Future<void> _exportResults() async {
    final outcomes = _outcomes!;
    await ReportExport.exportCsv(
      filename: 'ubuntuid_bulk_results.csv',
      headers: const ['Row', 'Name', 'ID number', 'Result'],
      rows: [
        for (final e in outcomes.entries)
          ['${e.key.rowNumber}', e.key.displayName, e.key.idNumber, _outcomeLabel(e.value)],
        for (final r in _parsed!.rows)
          if (!outcomes.containsKey(r)) ['${r.rowNumber}', r.displayName, r.idNumber, 'Not submitted: ${r.status.label}'],
      ],
    );
  }

  List<BulkRow> _visibleRows() {
    final rows = _parsed!.rows.where((r) => !r.removed).where((r) => switch (_filter) {
          _Filter.all => true,
          _Filter.ready => r.willSubmit,
          _Filter.attention => !r.willSubmit,
        }).toList();
    int rank(BulkRow r) => r.willSubmit ? 0 : 1;
    switch (_sort) {
      case _Sort.readyFirst:
        rows.sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.rowNumber - b.rowNumber);
      case _Sort.problemsFirst:
        rows.sort((a, b) => rank(a) != rank(b) ? rank(b) - rank(a) : a.rowNumber - b.rowNumber);
      case _Sort.name:
        rows.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    }
    return rows;
  }

  void _showRow(BulkRow row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(row.displayName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(row.status.label),
              const SizedBox(height: 12),
              DetailRow(label: 'Spreadsheet row', value: '${row.rowNumber}'),
              DetailRow(label: 'ID number', value: row.idNumber),
              DetailRow(label: 'Name in file', value: '${row.firstName} ${row.lastName}'.trim()),
              if (row.registeredName != null) DetailRow(label: 'Registered name', value: row.registeredName!),
              for (final issue in row.issues)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(issue)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (row.status == BulkRowStatus.nameMismatch)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include anyway'),
                  subtitle: const Text('Submit using the registered person for this ID number'),
                  value: row.includeAnyway,
                  onChanged: (v) {
                    setSheetState(() => row.includeAnyway = v);
                    setState(() {});
                  },
                ),
              AppButton(
                label: 'Remove from this upload',
                icon: Icons.delete_outline,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  setState(() => row.removed = true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeAsync = ref.watch(myCredentialScopeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload applicants')),
      body: scopeAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          message: 'Could not load your approved credentials.',
          onRetry: () => ref.invalidate(myCredentialScopeProvider),
        ),
        data: (scope) {
          final credentials = _credentials(scope);
          if (credentials.isEmpty) {
            return const ErrorView(message: 'Your organisation is not approved to verify any credentials yet.');
          }
          return _buildBody(credentials);
        },
      ),
    );
  }

  Widget _buildBody(List<BulkCredential> credentials) {
    final parsed = _parsed;
    final outcomes = _outcomes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Approved credentials', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(credentials.map((c) => c.displayName).join(' • ')),
              const SizedBox(height: 8),
              Text(
                'Every applicant is checked for these. Leave a credential\'s columns blank to skip it for that '
                'person. Excel (.xlsx) and CSV files are accepted, up to $_maxRows applicants.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _downloadTemplate(credentials),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download template'),
                  ),
                  FilledButton.icon(
                    onPressed: _reading || _submitting ? null : () => _pickFile(credentials),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_fileName == null ? 'Choose file' : 'Choose another file'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_reading) const Padding(padding: EdgeInsets.all(24), child: LoadingIndicator()),
        if (parsed != null && !_reading) ...[
          const SizedBox(height: 16),
          if (_submitting)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submitting $_done of $_total…'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                ],
              ),
            )
          else if (outcomes != null)
            _ResultsCard(
              outcomes: outcomes,
              label: _outcomeLabel,
              onExport: _exportResults,
              onViewApplicants: () => context.go(AppRoutes.organisationVerification),
            )
          else
            _summaryCard(parsed),
          const SizedBox(height: 12),
          if (outcomes == null) _controls(),
          const SizedBox(height: 8),
          for (final row in _visibleRows())
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${row.displayName} - ${outcomes?[row] != null ? _outcomeLabel(outcomes![row]!) : row.status.label}'),
                subtitle: Text('Row ${row.rowNumber} • ${row.idNumber}'),
                trailing: outcomes?[row] != null
                    ? StatusBadge.fromStatus(outcomes![row]!.startsWith('error') ? 'failed' : outcomes[row]!)
                    : Icon(
                        row.willSubmit ? Icons.check_circle : Icons.error_outline,
                        color: row.willSubmit ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
                      ),
                onTap: outcomes == null && !_submitting ? () => _showRow(row) : null,
              ),
            ),
        ],
      ],
    );
  }

  Widget _summaryCard(BulkParseResult parsed) {
    final active = parsed.rows.where((r) => !r.removed).toList();
    final ready = active.where((r) => r.willSubmit).length;
    final attention = active.length - ready;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_fileName ?? '', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('$ready ready • $attention need attention'),
          if (parsed.ignoredColumns.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ignored columns: ${parsed.ignoredColumns.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Submit $ready ready application${ready == 1 ? '' : 's'}',
            icon: Icons.send_outlined,
            expand: true,
            onPressed: ready == 0 ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in _Filter.values)
          ChoiceChip(
            label: Text(switch (f) {
              _Filter.all => 'All',
              _Filter.ready => 'Ready',
              _Filter.attention => 'Needs attention',
            }),
            selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f),
          ),
        DropdownButton<_Sort>(
          value: _sort,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: _Sort.readyFirst, child: Text('Ready first')),
            DropdownMenuItem(value: _Sort.problemsFirst, child: Text('Problems first')),
            DropdownMenuItem(value: _Sort.name, child: Text('Name A-Z')),
          ],
          onChanged: (v) => setState(() => _sort = v ?? _Sort.readyFirst),
        ),
      ],
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.outcomes,
    required this.label,
    required this.onExport,
    required this.onViewApplicants,
  });

  final Map<BulkRow, String> outcomes;
  final String Function(String) label;
  final VoidCallback onExport;
  final VoidCallback onViewApplicants;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final status in outcomes.values) {
      counts.update(label(status), (n) => n + 1, ifAbsent: () => 1);
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${outcomes.length} application(s) submitted', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(counts.entries.map((e) => '${e.value} ${e.key.toLowerCase()}').join(' • ')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download results'),
              ),
              FilledButton.icon(
                onPressed: onViewApplicants,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review applicants'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
