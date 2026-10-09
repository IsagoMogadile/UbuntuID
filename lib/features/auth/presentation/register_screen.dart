import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../routing/app_routes.dart';
import '../../../services/service_providers.dart';
import '../application/role_resolution.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _awaitingEmailConfirmation = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await ref.read(authServiceProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (response.session == null) {
        setState(() => _awaitingEmailConfirmation = true);
        return;
      }

      // Session created immediately (email confirmation disabled). A brand
      // new auth account has no citizens/department_officials/
      // organisation_users/ubuntuid_administrators row yet, so this will
      // correctly land on Account not configured until an administrator
      // links the account.
      final destination = await resolveDestinationRoute(ref);
      if (!mounted) return;
      context.go(destination);
    } on AuthException catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _awaitingEmailConfirmation ? _buildCheckEmail(context) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppLogo(size: 48)),
          const SizedBox(height: 24),
          Text(
            'Register for a UbuntuID account. If Home Affairs already '
            'registered you as a citizen, sign up with the exact same '
            'email address they used for you -- your account is linked '
            'to your citizen record automatically. Otherwise, access to '
            'department, organisation or administrator features is '
            'granted separately once your account is linked to a record.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter your email';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (value) {
              if (value == null || value.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            controller: _confirmController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('By creating an account you accept the ', style: TextStyle(fontSize: 13)),
              InkWell(
                onTap: () => context.push(AppRoutes.privacyPolicy),
                child: const Text(
                  'privacy policy',
                  style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                ),
              ),
              const Text('.', style: TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Create account',
            onPressed: _submit,
            loading: _submitting,
            expand: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Back to login'),
            ),
          ),
        ],
      ),
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
          "We've sent a confirmation link to your email address. "
          'Confirm it, then log in.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Back to login',
          onPressed: () => context.go(AppRoutes.login),
          expand: true,
        ),
      ],
    );
  }
}
