import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_item_card.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/organisation_repository.dart';
import '../domain/verification_claim_config.dart';
import '../../../core/widgets/app_toast.dart';

/// The organisation's core feature (spec §11/§12): the applicant's actual
/// application happens entirely outside UbuntuID (Spar's own hiring
/// process, say) -- this screen is where an organisation worker finds that
/// applicant, types in what their application claims, and submits it for
/// an automated check. The organisation never creates the citizen's
/// account and never sees data it isn't authorised to.
class CitizenSearchScreen extends ConsumerStatefulWidget {
  const CitizenSearchScreen({super.key});

  @override
  ConsumerState<CitizenSearchScreen> createState() => _CitizenSearchScreenState();
}

class _CitizenSearchScreenState extends ConsumerState<CitizenSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  CitizenSearchQuery? _searchQuery;
  String? _selectedCitizenId;
  final Set<String> _selectedCredentialTypeIds = {};
  // credentialTypeId -> typeCode, tracked alongside the selection so
  // _submitApplication can look up claim fields without re-reading the
  // credentials provider.
  final Map<String, String> _selectedCredentialTypeCodes = {};
  // credentialTypeId -> (fieldKey -> claimed value), what the organisation
  // worker typed in for each selected credential -- see
  // verification_claim_config.dart.
  final Map<String, Map<String, dynamic>> _claims = {};
  bool _submitting = false;

  @override
  void dispose() {
    _idNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _search() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty && lastName.isEmpty) {
      AppToast.warning(context, 'Enter at least a first name or last name to confirm the ID number.');
      return;
    }
    setState(() {
      _searchQuery = (
        idNumber: AppFormatters.compactIdNumber(_idNumberController.text),
        firstName: firstName.isEmpty ? null : firstName,
        lastName: lastName.isEmpty ? null : lastName,
      );
      _selectedCitizenId = null;
      _selectedCredentialTypeIds.clear();
    });
  }

  Future<void> _submitApplication(String citizenId) async {
    if (_selectedCredentialTypeIds.isEmpty) {
      AppToast.warning(context, 'Select at least one credential to check.');
      return;
    }
    for (final credentialTypeId in _selectedCredentialTypeIds) {
      final typeCode = _selectedCredentialTypeCodes[credentialTypeId];
      final fields = claimFieldsForType(typeCode ?? '');
      final claim = _claims[credentialTypeId] ?? const {};
      for (final field in fields) {
        final value = claim[field.key]?.toString().trim();
        if (value == null || value.isEmpty) {
          AppToast.warning(context, 'Fill in "${field.label}" before submitting this application.');
          return;
        }
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Submit application'),
        content: Text(
          'Start an automated check of ${_selectedCredentialTypeIds.length} credential(s) against what you\'ve '
          'entered for this applicant? UbuntuID compares this against the real department records – no official '
          'reviews it manually.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit application')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final requestId = await ref.read(organisationRepositoryProvider).requestVerification(
            citizenId: citizenId,
            credentialTypeIds: _selectedCredentialTypeIds.toList(),
            claimsByCredentialTypeId: _claims,
          );
      if (mounted) {
        context.push('${AppRoutes.organisationVerification}/$requestId');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not submit this application.', error: e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = _searchQuery == null ? null : ref.watch(citizenSearchResultProvider(_searchQuery!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Applicant'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.organisationBulkUpload),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload list'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'ID number',
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'First name',
                      controller: _firstNameController,
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Last name',
                      controller: _lastNameController,
                      prefixIcon: Icons.person_outline,
                      onFieldSubmitted: (_) => _search(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppButton(label: 'Search', icon: Icons.search, onPressed: _search, expand: true),
              const SizedBox(height: 20),
            if (resultAsync == null)
              const Expanded(
                child: EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'Find an applicant',
                  message: 'Enter the ID number plus at least a first or last name to look up the applicant and '
                      'submit their application.',
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
                  data: (results) {
                    if (results.isEmpty) {
                      return const EmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'No citizen found',
                        message: 'No citizen matches this ID number and name.',
                      );
                    }
                    final matches = results.where((r) => r.citizenId == _selectedCitizenId);
                    final selected = results.length == 1 ? results.first : (matches.isEmpty ? null : matches.first);
                    if (selected == null) {
                      return ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = results[i];
                          return ListItemCard(
                            leadingIcon: Icons.person_outline,
                            title: r.fullName.isEmpty ? 'Unknown' : r.fullName,
                            subtitle: r.idNumber,
                            trailing: StatusBadge.fromStatus(r.currentStatus),
                            onTap: () => setState(() => _selectedCitizenId = r.citizenId),
                          );
                        },
                      );
                    }
                    return _CitizenResult(
                      citizenId: selected.citizenId,
                      fullName: selected.fullName,
                      idNumber: selected.idNumber,
                      currentStatus: selected.currentStatus,
                      selectedCredentialTypeIds: _selectedCredentialTypeIds,
                      claims: _claims,
                      onToggle: (id, typeCode, checked) => setState(() {
                        if (checked) {
                          _selectedCredentialTypeIds.add(id);
                          _selectedCredentialTypeCodes[id] = typeCode;
                          _claims.putIfAbsent(id, () => {});
                        } else {
                          _selectedCredentialTypeIds.remove(id);
                          _selectedCredentialTypeCodes.remove(id);
                          _claims.remove(id);
                        }
                      }),
                      onClaimFieldChanged: (credentialTypeId, fieldKey, value) => setState(() {
                        _claims.putIfAbsent(credentialTypeId, () => {})[fieldKey] = value;
                      }),
                      submitting: _submitting,
                      onSubmitApplication: () => _submitApplication(selected.citizenId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _credentialSubtitle(VerifiableCredential credential) {
  final qualification = credential.qualification;
  if (qualification != null) {
    final parts = [
      qualification.qualificationName,
      if (qualification.institutionName != null) qualification.institutionName!,
      if (qualification.result != null) qualification.result!,
    ];
    return parts.join(' • ');
  }
  return credential.issuingDepartment;
}

class _CitizenResult extends ConsumerWidget {
  const _CitizenResult({
    required this.citizenId,
    required this.fullName,
    required this.idNumber,
    required this.currentStatus,
    required this.selectedCredentialTypeIds,
    required this.claims,
    required this.onToggle,
    required this.onClaimFieldChanged,
    required this.submitting,
    required this.onSubmitApplication,
  });

  final String citizenId;
  final String fullName;
  final String idNumber;
  final String currentStatus;
  final Set<String> selectedCredentialTypeIds;
  final Map<String, Map<String, dynamic>> claims;
  final void Function(String credentialTypeId, String typeCode, bool selected) onToggle;
  final void Function(String credentialTypeId, String fieldKey, dynamic value) onClaimFieldChanged;
  final bool submitting;
  final VoidCallback onSubmitApplication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(citizenVerifiableCredentialsProvider(citizenId));

    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailRow(label: 'Name', value: fullName.isEmpty ? 'Unknown' : fullName),
              DetailRow(label: 'ID number', value: idNumber),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 130, child: Text('Identity status')),
                    StatusBadge.fromStatus(currentStatus),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('What does the application need checked?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        credentialsAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => const Text('Could not load this citizen\'s credentials.'),
          data: (credentials) {
            if (credentials.isEmpty) {
              return const EmptyState(
                icon: Icons.badge_outlined,
                title: 'No credentials or records available',
                message: 'This citizen has no verifiable credentials on file.',
              );
            }
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < credentials.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    CheckboxListTile(
                      value: selectedCredentialTypeIds.contains(credentials[i].credentialTypeId),
                      onChanged: (checked) =>
                          onToggle(credentials[i].credentialTypeId, credentials[i].typeCode, checked ?? false),
                      title: Text(credentials[i].typeName),
                      subtitle: Text(_credentialSubtitle(credentials[i])),
                      isThreeLine: credentials[i].qualification != null,
                      secondary: StatusBadge.fromStatus(credentials[i].status),
                    ),
                    if (selectedCredentialTypeIds.contains(credentials[i].credentialTypeId))
                      _ClaimFieldsForm(
                        credentialTypeId: credentials[i].credentialTypeId,
                        typeCode: credentials[i].typeCode,
                        values: claims[credentials[i].credentialTypeId] ?? const {},
                        onChanged: onClaimFieldChanged,
                      ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Submit application',
          icon: Icons.fact_check_outlined,
          expand: true,
          loading: submitting,
          onPressed: submitting ? null : onSubmitApplication,
        ),
      ],
    );
  }
}

/// What the organisation worker types in for one selected credential --
/// "if I work at Spar, the applicant's Spar application says..." -- shown
/// inline under that credential's checkbox once it's ticked. See
/// verification_claim_config.dart for why these fields mirror the real
/// department record's own columns rather than a single free-text box.
class _ClaimFieldsForm extends StatelessWidget {
  const _ClaimFieldsForm({
    required this.credentialTypeId,
    required this.typeCode,
    required this.values,
    required this.onChanged,
  });

  final String credentialTypeId;
  final String typeCode;
  final Map<String, dynamic> values;
  final void Function(String credentialTypeId, String fieldKey, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    final fields = claimFieldsForType(typeCode);
    if (fields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What does the applicant claim?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final field in fields) ...[
            if (field.type == ClaimFieldType.dropdown)
              DropdownButtonFormField<String>(
                initialValue: values[field.key] as String?,
                decoration: InputDecoration(labelText: field.label, isDense: true),
                items: [for (final o in field.options ?? []) DropdownMenuItem(value: o, child: Text(o))],
                onChanged: (v) => onChanged(credentialTypeId, field.key, v),
              )
            else
              TextFormField(
                initialValue: values[field.key]?.toString(),
                decoration: InputDecoration(labelText: field.label, isDense: true),
                keyboardType: field.type == ClaimFieldType.number
                    ? const TextInputType.numberWithOptions(decimal: false)
                    : TextInputType.text,
                onChanged: (v) => onChanged(credentialTypeId, field.key, v),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
