import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../routing/app_routes.dart';
import '../data/organisation_repository.dart';

/// The organisation's core feature (spec §11/§12): search a citizen by ID
/// number, review what identity/credential information UbuntuID exposes to
/// this organisation, then raise a verification request. The organisation
/// never creates the citizen's account, never sees data it isn't
/// authorised to, and never applies for anything on the citizen's behalf --
/// the actual application (job, grant, etc.) happens in the organisation's
/// own external system before this screen is ever used.
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
  final Set<String> _selectedCredentialTypeIds = {};
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
    setState(() {
      _searchQuery = (
        idNumber: _idNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      _selectedCredentialTypeIds.clear();
    });
  }

  Future<void> _requestVerification(String citizenId) async {
    if (_selectedCredentialTypeIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select at least one credential to verify.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request verification'),
        content: Text(
          'Request verification of ${_selectedCredentialTypeIds.length} credential(s) for this citizen? '
          'A department official will review this request.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final requestId = await ref.read(organisationRepositoryProvider).requestVerification(
            citizenId: citizenId,
            credentialTypeIds: _selectedCredentialTypeIds.toList(),
          );
      if (mounted) {
        context.push('${AppRoutes.organisationVerification}/$requestId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not raise this request: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = _searchQuery == null ? null : ref.watch(citizenSearchResultProvider(_searchQuery!));

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Citizen')),
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
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      label: 'Last name',
                      controller: _lastNameController,
                      prefixIcon: Icons.person_outline,
                      onFieldSubmitted: (_) => _search(),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                  title: 'Search for a citizen',
                  message: 'Enter the ID number, first name and last name exactly as on record -- all three '
                      'must match to look up a citizen and request verification.',
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
                    return _CitizenResult(
                      citizenId: result.citizenId,
                      fullName: result.fullName,
                      idNumber: result.idNumber,
                      currentStatus: result.currentStatus,
                      selectedCredentialTypeIds: _selectedCredentialTypeIds,
                      onToggle: (id, selected) => setState(() {
                        if (selected) {
                          _selectedCredentialTypeIds.add(id);
                        } else {
                          _selectedCredentialTypeIds.remove(id);
                        }
                      }),
                      submitting: _submitting,
                      onRequestVerification: () => _requestVerification(result.citizenId),
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
    required this.onToggle,
    required this.submitting,
    required this.onRequestVerification,
  });

  final String citizenId;
  final String fullName;
  final String idNumber;
  final String currentStatus;
  final Set<String> selectedCredentialTypeIds;
  final void Function(String credentialTypeId, bool selected) onToggle;
  final bool submitting;
  final VoidCallback onRequestVerification;

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
        Text('Select credentials to verify', style: Theme.of(context).textTheme.titleSmall),
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
                      onChanged: (checked) => onToggle(credentials[i].credentialTypeId, checked ?? false),
                      title: Text(credentials[i].typeName),
                      subtitle: Text(_credentialSubtitle(credentials[i])),
                      isThreeLine: credentials[i].qualification != null,
                      secondary: StatusBadge.fromStatus(credentials[i].status),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Request verification',
          icon: Icons.fact_check_outlined,
          expand: true,
          loading: submitting,
          onPressed: submitting ? null : onRequestVerification,
        ),
      ],
    );
  }
}
