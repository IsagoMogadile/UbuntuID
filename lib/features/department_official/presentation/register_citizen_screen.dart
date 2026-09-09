import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/department_repository.dart';

/// Home Affairs officials' "Register Citizen" workflow (see
/// docs/PROJECT_SCOPE.md). Only fields already confirmed to exist on
/// `citizens` in docs/SCREEN_DATABASE_MAP.md are captured -- no field is
/// invented. Gated by the live `citizens_insert` RLS policy (Home Affairs
/// officials or admins only), confirmed working.
class RegisterCitizenScreen extends ConsumerStatefulWidget {
  const RegisterCitizenScreen({super.key});

  @override
  ConsumerState<RegisterCitizenScreen> createState() => _RegisterCitizenScreenState();
}

class _RegisterCitizenScreenState extends ConsumerState<RegisterCitizenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _idNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      setState(() => _error = 'Select a date of birth.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(departmentRepositoryProvider).registerCitizen(
            idNumber: _idNumberController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Citizen registered.')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Could not register this citizen: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Citizen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter the citizen\'s ID number' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'First name',
                  controller: _firstNameController,
                  prefixIcon: Icons.person_outline,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a first name' : null,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Last name',
                  controller: _lastNameController,
                  prefixIcon: Icons.person_outline,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a last name' : null,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(
                      _dateOfBirth == null ? 'Select a date' : AppFormatters.date(_dateOfBirth!),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone number (optional)',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email (optional)',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Register citizen',
                  icon: Icons.person_add_alt_outlined,
                  loading: _submitting,
                  expand: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
