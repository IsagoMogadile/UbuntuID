import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/sa_id_generator.dart';
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
  bool _dobFromIdNumber = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idNumberController.addListener(_deriveDateOfBirthFromIdNumber);
  }

  @override
  void dispose() {
    _idNumberController.removeListener(_deriveDateOfBirthFromIdNumber);
    _idNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // The first 6 digits of a South African ID number encode the holder's
  // date of birth (YYMMDD) -- derive it automatically instead of asking
  // the official to also type it by hand, which is redundant and a source
  // of typos/mismatches against the ID.
  void _deriveDateOfBirthFromIdNumber() {
    final dob = saIdDateOfBirth(_idNumberController.text.trim());
    if (dob != null) {
      setState(() {
        _dateOfBirth = dob;
        _dobFromIdNumber = true;
      });
    } else if (_dobFromIdNumber) {
      // ID number no longer parses (e.g. still being typed/cleared) --
      // drop the derived value rather than leave a stale one behind.
      setState(() {
        _dateOfBirth = null;
        _dobFromIdNumber = false;
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dobFromIdNumber = false;
      });
    }
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
      final email = _emailController.text.trim().toLowerCase();
      await ref.read(departmentRepositoryProvider).registerCitizen(
            idNumber: _idNumberController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            phoneNumber: _phoneController.text.trim(),
            email: email,
          );
      if (!mounted) return;
      await _showNextSteps(email);
      if (mounted) context.pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not register this citizen: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Tells the official exactly what to hand the citizen, so they know which
  // email to sign up with -- the only way their login reaches this record.
  Future<void> _showNextSteps(String email) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: AppColors.green),
        title: const Text('Citizen registered'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tell the citizen to go to UbuntuID, tap "Create account" and sign up with this email:'),
            const SizedBox(height: 12),
            SelectableText(email, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Their account links to this record automatically the first time they log in.'),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy email'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied.')));
            },
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
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
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      helperText: _dobFromIdNumber
                          ? 'Derived from ID number -- tap to override'
                          : 'Tap to select (auto-fills once a valid ID number is entered)',
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
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter the citizen\'s own email address';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'The citizen signs up for UbuntuID with this exact email to reach their record, '
                  'so use an address they can actually receive mail at.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted),
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
