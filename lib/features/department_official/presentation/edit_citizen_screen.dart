import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/department_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/utils/friendly_error.dart';

/// Home Affairs only -- "make changes to citizen details, edit names, and
/// everything". Gated by the live `citizens_update` RLS policy (see
/// `DepartmentRepository.updateCitizenDetails`).
class EditCitizenScreen extends ConsumerStatefulWidget {
  const EditCitizenScreen({super.key, required this.citizenId});

  final String citizenId;

  @override
  ConsumerState<EditCitizenScreen> createState() => _EditCitizenScreenState();
}

class _EditCitizenScreenState extends ConsumerState<EditCitizenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = 'female';
  String _citizenshipStatus = 'citizen';
  bool _loaded = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _prefill(Map<String, dynamic> row) {
    _firstNameController.text = row['first_name'] as String? ?? '';
    _lastNameController.text = row['last_name'] as String? ?? '';
    _phoneController.text = row['phone_number'] as String? ?? '';
    _emailController.text = row['email'] as String? ?? '';
    final dob = row['date_of_birth'] as String?;
    _dateOfBirth = dob == null ? null : DateTime.tryParse(dob);
    _gender = row['gender'] as String? ?? 'female';
    _citizenshipStatus = row['citizenship_status'] as String? ?? 'citizen';
    _loaded = true;
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(DateTime.now().year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
      await ref.read(departmentRepositoryProvider).updateCitizenDetails(
            citizenId: widget.citizenId,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            gender: _gender,
            citizenshipStatus: _citizenshipStatus,
          );
      if (mounted) {
        AppToast.success(context, 'Citizen details updated.');
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Could not save these changes. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(departmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Citizen')),
      body: SafeArea(
        child: _loaded
            ? _buildForm(context)
            : FutureBuilder<Map<String, dynamic>>(
                future: repo.getCitizenForEdit(widget.citizenId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) return const LoadingIndicator();
                  if (snapshot.hasError || !snapshot.hasData) {
                    return ErrorView(
                      message: snapshot.error == null
                          ? 'Could not load this citizen.'
                          : 'Could not load this citizen. ${friendlyError(snapshot.error!)}',
                      onRetry: () => setState(() {}),
                    );
                  }
                  _prefill(snapshot.data!);
                  return _buildForm(context);
                },
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'First name',
              controller: _firstNameController,
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a first name' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Last name',
              controller: _lastNameController,
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a last name' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of birth', prefixIcon: Icon(Icons.cake_outlined)),
                child: Text(_dateOfBirth == null ? 'Select a date' : AppFormatters.date(_dateOfBirth!)),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _citizenshipStatus,
              decoration: const InputDecoration(labelText: 'Citizenship status', prefixIcon: Icon(Icons.flag_outlined)),
              items: const [
                DropdownMenuItem(value: 'citizen', child: Text('Citizen')),
                DropdownMenuItem(value: 'permanent_resident', child: Text('Permanent Resident')),
                DropdownMenuItem(value: 'refugee', child: Text('Refugee')),
                DropdownMenuItem(value: 'visitor', child: Text('Visitor')),
              ],
              onChanged: (v) => setState(() => _citizenshipStatus = v ?? _citizenshipStatus),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone number',
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
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Save changes',
              icon: Icons.save_outlined,
              loading: _submitting,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
