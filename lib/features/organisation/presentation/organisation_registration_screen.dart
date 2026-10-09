import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../data/organisation_repository.dart';
import 'credential_scope_picker.dart';
import '../../../core/utils/friendly_error.dart';

const _organisationTypes = ['private', 'government', 'ngo', 'education', 'financial', 'other'];

/// Public self-service organisation registration, reached from the login
/// screen. Creates the auth account (normal signUp), then in one atomic
/// server-side call (`register_organisation`) creates the organisation
/// (pending), its head user, and the credential-type scope the organisation
/// selected -- an administrator must approve it before the account can do
/// anything (see `current_org_user_organisation_id`).
class OrganisationRegistrationScreen extends ConsumerStatefulWidget {
  const OrganisationRegistrationScreen({super.key});

  @override
  ConsumerState<OrganisationRegistrationScreen> createState() => _OrganisationRegistrationScreenState();
}

class _OrganisationRegistrationScreenState extends ConsumerState<OrganisationRegistrationScreen> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _headFirstNameController = TextEditingController();
  final _headLastNameController = TextEditingController();
  final _headIdNumberController = TextEditingController();

  String _organisationType = _organisationTypes.first;
  String _headGender = 'female';
  final _scope = CredentialScopeSelection();

  /// 0 = organisation/head details, 1 = credential-type selection (its own
  /// screen so the choice isn't buried at the bottom of one long form).
  int _step = 0;
  bool _submitting = false;
  bool _submitted = false;
  bool _awaitingEmailConfirmation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    if (currentEmail != null) _emailController.text = currentEmail;
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _registrationNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _headFirstNameController.dispose();
    _headLastNameController.dispose();
    _headIdNumberController.dispose();
    _scope.dispose();
    super.dispose();
  }

  bool get _hasSession => Supabase.instance.client.auth.currentSession != null;

  /// Validates the organisation/head details step, then advances to the
  /// credential-type selection step -- a separate screen rather than one
  /// long form.
  void _continueToCredentialTypes() {
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _submit() async {
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
      final email = _emailController.text.trim();

      // Already signed in (came here from "Account not configured" after
      // confirming their email) -- skip signUp and go straight to
      // registering the organisation under the existing session.
      if (!_hasSession) {
        final signUpResponse = await ref.read(authServiceProvider).signUp(
              email: email,
              password: _passwordController.text,
            );
        if (signUpResponse.session == null) {
          setState(() {
            _awaitingEmailConfirmation = true;
          });
          return;
        }
      }

      await ref.read(organisationRepositoryProvider).registerOrganisation(
            legalName: _legalNameController.text.trim(),
            registrationNumber: _registrationNumberController.text.trim(),
            organisationType: _organisationType,
            contactEmail: email,
            contactPhone: _phoneController.text.trim(),
            credentialTypeCodes: _scope.selected.toList(),
            accessPurpose: _scope.purpose.text.trim(),
            credentialReasons: _scope.reasons,
            headFirstName: _headFirstNameController.text.trim(),
            headLastName: _headLastNameController.text.trim(),
            headGender: _headGender,
            headIdNumber: _headIdNumberController.text.trim(),
          );

      setState(() => _submitted = true);
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthMessage(e.message));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register your organisation')),
      body: SafeArea(
        // The scroll view spans the full width (so its scrollbar sits at the
        // window's right edge) and centres the form inside it, rather than
        // being centred itself and shrinking to the form's width.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _submitted
                      ? _buildSubmitted(context)
                      : _awaitingEmailConfirmation
                          ? _buildCheckEmail(context)
                          : _step == 0
                              ? _buildDetailsStep(context)
                              : _buildCredentialTypesStep(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitted(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top_outlined, size: 48, color: AppColors.green),
        const SizedBox(height: 16),
        Text('Application submitted', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'A UbuntuID administrator will review your organisation\'s application. '
          'You can sign in at any time to check its status.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(label: 'Back to sign in', onPressed: () => context.go(AppRoutes.login), expand: true),
      ],
    );
  }

  Widget _buildCheckEmail(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.green),
        const SizedBox(height: 16),
        Text('Check your email', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          "We've sent a confirmation link to your email address. Confirm it, "
          'then sign in and come back to "Finish registering your organisation" '
          'to submit your application.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Back to sign in',
          onPressed: () => context.go(AppRoutes.login),
          expand: true,
        ),
      ],
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppLogo(size: 48)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('Step 1 of 2 · Organisation details', style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Legal name',
            controller: _legalNameController,
            prefixIcon: Icons.apartment_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the organisation\'s legal name' : null,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Registration number',
            controller: _registrationNumberController,
            prefixIcon: Icons.numbers_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a registration number' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _organisationType,
            decoration: const InputDecoration(labelText: 'Organisation type', prefixIcon: Icon(Icons.category_outlined)),
            items: [for (final t in _organisationTypes) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _organisationType = v ?? _organisationType),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: _hasSession ? 'Organisation / sign-in email (confirmed)' : 'Organisation / sign-in email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            enabled: !_hasSession,
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Contact phone',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.call_outlined,
          ),
          if (!_hasSession) ...[
          const SizedBox(height: 14),
          AppTextField(
            label: 'Password',
            helperText: 'At least 8 characters.',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters.' : null,
          ),
          ],
          const SizedBox(height: 24),
          Text('Organisation head (you)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'First name',
                  controller: _headFirstNameController,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Last name',
                  controller: _headLastNameController,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _headGender,
            decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
            ],
            onChanged: (v) => setState(() => _headGender = v ?? _headGender),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'SA ID number',
            controller: _headIdNumberController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().length != 13) ? 'Enter a 13-digit SA ID number' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Next: choose credentials',
            icon: Icons.arrow_forward,
            onPressed: _continueToCredentialTypes,
            expand: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton(onPressed: () => context.pop(), child: const Text('Back to sign in')),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTypesStep(BuildContext context) {
    final credentialTypesAsync = ref.watch(allCredentialTypesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogo(size: 48)),
        const SizedBox(height: 20),
        Text('Step 2 of 2 · Credential types', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Which credential types does ${_legalNameController.text.trim().isEmpty ? "your organisation" : _legalNameController.text.trim()} '
          'need to verify, and why? Staff who sign in under this organisation will only ever see the '
          'credential types you select here. An administrator reads your reasons before approving.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted),
        ),
        const SizedBox(height: 12),
        credentialTypesAsync.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => const Text('Could not load credential types.'),
          data: (types) => CredentialScopePicker(
            selection: _scope,
            types: types,
            onChanged: () => setState(() {}),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        AppButton(label: 'Submit application', onPressed: _submit, loading: _submitting, expand: true),
        const SizedBox(height: 8),
        AppButton(
          label: 'Back',
          icon: Icons.arrow_back,
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _submitting ? null : () => setState(() => _step = 0),
        ),
      ],
    );
  }
}
