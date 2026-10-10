import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/sa_id_generator.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/detail_row.dart';
import '../data/department_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';

enum _Stage { lookup, found, notInRegister }

/// Home Affairs officials' "Onboard Citizen" workflow. Home Affairs already
/// holds everyone in the population register, and other departments
/// already hold records against their ID number, so onboarding is:
///
///   1. look the ID number up (`dha_find_citizen`);
///   2. someone in the register without a digital ID -> check their details,
///      add their email, Issue digital ID (`dha_onboard_citizen`), which
///      links every existing record so their documents appear at once;
///   3. someone not in the register at all (e.g. a new citizen) -> the
///      original "register a new citizen" form, gated by the live
///      `citizens_insert` RLS policy.
class RegisterCitizenScreen extends ConsumerStatefulWidget {
  const RegisterCitizenScreen({super.key});

  @override
  ConsumerState<RegisterCitizenScreen> createState() => _RegisterCitizenScreenState();
}

class _RegisterCitizenScreenState extends ConsumerState<RegisterCitizenScreen> {
  final _lookupFormKey = GlobalKey<FormState>();
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  _Stage _stage = _Stage.lookup;
  Map<String, dynamic>? _person;
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
  // the official to also type it by hand.
  void _deriveDateOfBirthFromIdNumber() {
    final dob = saIdDateOfBirth(_idNumberController.text.trim());
    if (dob != null) {
      setState(() {
        _dateOfBirth = dob;
        _dobFromIdNumber = true;
      });
    } else if (_dobFromIdNumber) {
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

  Future<void> _lookup() async {
    if (!(_lookupFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final idNumber = AppFormatters.compactIdNumber(_idNumberController.text);
      final person = await ref.read(departmentRepositoryProvider).findCitizenInRegister(idNumber);
      if (!mounted) return;
      setState(() {
        _person = person;
        _stage = person['found'] == true ? _Stage.found : _Stage.notInRegister;
      });
    } catch (e) {
      setState(() => _error = 'Could not search the population register. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startOver() {
    setState(() {
      _stage = _Stage.lookup;
      _person = null;
      _error = null;
      _emailController.clear();
      _phoneController.clear();
    });
  }

  Future<void> _onboard() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim().toLowerCase();
      final linked = await ref.read(departmentRepositoryProvider).onboardCitizen(
            citizenId: _person!['citizen_id'] as String,
            email: email,
            phoneNumber: _phoneController.text.trim(),
          );
      if (!mounted) return;
      await _showNextSteps(email, title: 'Digital ID issued', linkedRecords: linked);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not issue the digital ID. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _registerNew() async {
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
            idNumber: AppFormatters.compactIdNumber(_idNumberController.text),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            phoneNumber: _phoneController.text.trim(),
            email: email,
          );
      if (!mounted) return;
      await _showNextSteps(email, title: 'Citizen registered');
      if (mounted) context.pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not register this citizen. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Tells the official exactly what to hand the citizen, so they know which
  // email to sign up with -- the only way their login reaches this record.
  Future<void> _showNextSteps(String email, {required String title, int? linkedRecords}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.check_circle_outline, color: AppColors.green),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (linkedRecords != null) ...[
              Text(linkedRecords == 1
                  ? '1 existing government record is now in their documents.'
                  : '$linkedRecords existing government records are now in their documents.'),
              const SizedBox(height: 12),
            ],
            const Text('Tell the citizen to go to UbuntuID, tap "Create account" and sign up with this email:'),
            const SizedBox(height: 12),
            SelectableText(email, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Their account links to this record automatically the first time they sign in.'),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy email'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email));
              AppToast.success(context, 'Email copied.');
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
      appBar: AppBar(title: const Text('Onboard Citizen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: switch (_stage) {
                _Stage.lookup => _buildLookup(context),
                _Stage.found => _buildFound(context),
                _Stage.notInRegister => _buildNewCitizenForm(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        );

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter the citizen\'s own email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  Widget _buildLookup(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.charcoalMuted);
    return Form(
      key: _lookupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Find the citizen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Enter the ID number from the citizen's ID book or smart card. Home Affairs already holds their "
            "identity, and other departments already hold their records.",
            style: muted,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'ID number',
            controller: _idNumberController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.badge_outlined,
            validator: (value) => AppFormatters.compactIdNumber(value ?? '').length != 13
                ? 'Enter the 13-digit ID number'
                : null,
          ),
          _errorText(),
          const SizedBox(height: 20),
          AppButton(label: 'Search register', icon: Icons.search, loading: _submitting, expand: true, onPressed: _lookup),
        ],
      ),
    );
  }

  Widget _buildFound(BuildContext context) {
    final p = _person!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.charcoalMuted);
    final hasDigitalId = p['has_digital_id'] == true;
    final records = (p['records'] as List? ?? const []).cast<Map>();
    final dob = DateTime.tryParse(p['date_of_birth'] as String? ?? '');
    final status = p['current_status'] as String? ?? 'active';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${p['first_name']} ${p['last_name']}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Found in the population register', style: muted),
                const SizedBox(height: 12),
                DetailRow(label: 'ID number', value: p['id_number'] as String? ?? ''),
                if (dob != null) DetailRow(label: 'Date of birth', value: AppFormatters.date(dob)),
                DetailRow(label: 'Gender', value: (p['gender'] as String? ?? '').isEmpty ? 'Not recorded' : p['gender'] as String),
                DetailRow(label: 'Status', value: status[0].toUpperCase() + status.substring(1)),
                DetailRow(label: 'Digital ID', value: hasDigitalId ? 'Already issued (${p['email'] ?? 'on file'})' : 'Not issued yet'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Records other departments already hold', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AppCard(
            child: records.isEmpty
                ? Text('No department records yet.', style: muted)
                : Column(
                    children: [
                      for (final r in records)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${r['record']}')),
                              Text('${r['department']}', style: muted),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          if (hasDigitalId) ...[
            Text(
              'This citizen already has a digital ID. They sign in with the email above, or use "Forgot password" '
              'if they cannot.',
              style: muted,
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Search another ID number', variant: AppButtonVariant.secondary, expand: true, onPressed: _startOver),
          ] else if (status != 'active') ...[
            Text("A digital ID can't be issued while this person's status is \"$status\".", style: muted),
            const SizedBox(height: 16),
            AppButton(label: 'Search another ID number', variant: AppButtonVariant.secondary, expand: true, onPressed: _startOver),
          ] else ...[
            Text('Issue the digital ID', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              validator: _emailValidator,
            ),
            const SizedBox(height: 6),
            Text(
              'The citizen signs up with this exact email, so use an address they can receive mail at.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone number (optional)',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            _errorText(),
            const SizedBox(height: 20),
            AppButton(
              label: 'Issue digital ID',
              icon: Icons.verified_user_outlined,
              loading: _submitting,
              expand: true,
              onPressed: _onboard,
            ),
            const SizedBox(height: 8),
            AppButton(label: 'Back', icon: Icons.arrow_back, variant: AppButtonVariant.text, expand: true, onPressed: _submitting ? null : _startOver),
          ],
        ],
      ),
    );
  }

  Widget _buildNewCitizenForm(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.charcoalMuted);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Not in the population register', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'No one with ID number ${_person?['id_number'] ?? ''} is on record. If this is a new citizen, '
            'register them below. Otherwise check the ID number and search again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.charcoalMuted),
          ),
          const SizedBox(height: 16),
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
              child: Text(_dateOfBirth == null ? 'Select a date' : AppFormatters.date(_dateOfBirth!)),
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
            validator: _emailValidator,
          ),
          const SizedBox(height: 6),
          Text(
            'The citizen signs up for UbuntuID with this exact email to reach their record, '
            'so use an address they can actually receive mail at.',
            style: muted,
          ),
          _errorText(),
          const SizedBox(height: 20),
          AppButton(
            label: 'Register new citizen',
            icon: Icons.person_add_alt_outlined,
            loading: _submitting,
            expand: true,
            onPressed: _registerNew,
          ),
          const SizedBox(height: 8),
          AppButton(label: 'Search again', icon: Icons.arrow_back, variant: AppButtonVariant.text, expand: true, onPressed: _submitting ? null : _startOver),
        ],
      ),
    );
  }
}
