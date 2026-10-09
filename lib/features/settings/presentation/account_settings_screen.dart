import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/service_providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).updatePassword(_passwordController.text);
      _passwordController.clear();
      if (!mounted) return;
      AppToast.success(context, 'Password updated.');
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
    final email = ref.watch(authServiceProvider).currentUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Sign-in email'),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.mail_outline, color: AppColors.charcoalMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(email)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Change password'),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'New password',
                    helperText: 'At least 8 characters.',
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.length < 8) return 'Use at least 8 characters.';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Update password',
                    onPressed: _changePassword,
                    loading: _submitting,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
