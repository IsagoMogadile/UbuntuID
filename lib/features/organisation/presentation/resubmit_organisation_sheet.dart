import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/organisation_repository.dart';
import 'credential_scope_picker.dart';
import '../../../core/utils/friendly_error.dart';

const _organisationTypes = ['private', 'government', 'ngo', 'education', 'financial', 'other'];

/// Lets a declined organisation's head user edit details and re-pick the
/// credential-type scope, then resubmit for another admin review via
/// `resubmit_organisation`. No auth/password fields here -- the head
/// account already exists.
class ResubmitOrganisationSheet extends ConsumerStatefulWidget {
  const ResubmitOrganisationSheet({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<ResubmitOrganisationSheet> createState() => _ResubmitOrganisationSheetState();
}

class _ResubmitOrganisationSheetState extends ConsumerState<ResubmitOrganisationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _organisationType = _organisationTypes.first;
  final _scope = CredentialScopeSelection();

  bool _loaded = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _legalNameController.dispose();
    _registrationNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _prefill(Map<String, dynamic> detail) {
    if (_loaded) return;
    _loaded = true;
    _legalNameController.text = detail['legal_name'] as String? ?? '';
    _registrationNumberController.text = detail['registration_number'] as String? ?? '';
    _emailController.text = detail['contact_email'] as String? ?? '';
    _phoneController.text = detail['contact_phone'] as String? ?? '';
    _organisationType = detail['organisation_type'] as String? ?? _organisationTypes.first;
    _scope.purpose.text = detail['access_purpose'] as String? ?? '';
    final reasons = (detail['scope_reasons'] as Map<String, String>?) ?? const {};
    for (final code in (detail['selected_type_codes'] as List<dynamic>? ?? []).cast<String>()) {
      _scope.selected.add(code);
      _scope.reasonFor(code).text = reasons[code] ?? '';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final problem = _scope.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(organisationRepositoryProvider).resubmitOrganisation(
            organisationId: widget.organisationId,
            legalName: _legalNameController.text.trim(),
            registrationNumber: _registrationNumberController.text.trim(),
            organisationType: _organisationType,
            contactEmail: _emailController.text.trim(),
            contactPhone: _phoneController.text.trim(),
            credentialTypeCodes: _scope.selected.toList(),
            accessPurpose: _scope.purpose.text.trim(),
            credentialReasons: _scope.reasons,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Could not resubmit. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_resubmitDetailProvider(widget.organisationId));
    final typesAsync = ref.watch(allCredentialTypesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: detailAsync.when(
        loading: () => const SizedBox(height: 200, child: LoadingIndicator()),
        error: (e, _) => const SizedBox(height: 120, child: Center(child: Text('Could not load application.'))),
        data: (detail) {
          _prefill(detail);
          return SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Resubmit application', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Legal name',
                    controller: _legalNameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Registration number',
                    controller: _registrationNumberController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _organisationType,
                    decoration: const InputDecoration(labelText: 'Organisation type'),
                    items: [for (final t in _organisationTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _organisationType = v ?? _organisationType),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Contact email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Contact phone', controller: _phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  Text('Access requested', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  typesAsync.when(
                    loading: () => const LoadingIndicator(),
                    error: (e, _) => const Text('Could not load credential types.'),
                    data: (types) => CredentialScopePicker(
                      selection: _scope,
                      types: types,
                      showDepartment: false,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  AppButton(label: 'Resubmit', onPressed: _submit, loading: _submitting, expand: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

final _resubmitDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, organisationId) {
  return ref.watch(organisationRepositoryProvider).getOrganisationForResubmit(organisationId);
});
